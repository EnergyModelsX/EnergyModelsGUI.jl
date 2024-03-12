using EnergyModelsBase
using EnergyModelsInvestments
using HiGHS
using JuMP
using PrettyTables
using TimeStruct

const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments

"""
    generate_network_model()

Generate the data for the case study.
The example is partly based on the provided example `network.jl` in `EnergyModelsBase`.
"""
function generate_network_model()
    @info "Generate case data"

    # Define the different resources and their emission intensity in tCO2/MWh
    NG = ResourceCarrier("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [NG, Coal, Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 1 # Each operational period has a duration of 1
    op_number = 24  # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The duration of operational periods per duration of 1 of a strategic period of 8760
    # implies that a duration of 1 of an operational period corresponds to an hour, while
    # a duration of 1 of a strategic period corresponds to a year
    op_per_strat = 8760

    sp_duration = 5 # The duration of a strategic period is given as 5 years

    # Create the time structure It corresponds to simulating one day in a year over
    # 4 strategic periods
    T = TwoLevel(4, sp_duration, operational_periods; op_per_strat)

    # Create the global data
    em_limits = Dict(CO2 => StrategicProfile([450, 400, 350, 300]*365))   # Emission cap for CO2 in t/year
    em_cost = Dict(CO2 => FixedProfile(0))  # Emission price for CO2 in EUR/t
    discount_rate = 0.07                    # Discount rate in absolute value
    model = InvestmentModel(em_limits, em_cost, CO2, discount_rate)

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO2 storage.
    # Only the natural gas power plant and the CO2 storage nodes have ivnestment options
    op_profile = OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20])
    nodes = [
        GenAvailability(1, products),   # Routing Node
        RefSink(                        # Demand Node
            2,                          # Node id
            op_profile,                 # Used demand profile
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(Power => 1),           # Power demand and corresponding ratio
        ),
        RefSource(                      # Natural gas source
            3,                          # Node id
            FixedProfile(80),           # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MWh
            FixedProfile(100),          # Fixed OPEX in EUR/year
            Dict(NG => 1),              # Output from the Node, in this gase, NG
            [],                         # Potential additional data, no investment for the source
        ),
        RefSource(                      # Coal source
            4,                          # Node id
            FixedProfile(100),            # Capacity in MW
            FixedProfile(9),            # Variable OPEX in EUR/MWh
            FixedProfile(100),          # Fixed OPEX in EUR/year
            Dict(Coal => 1),            # Output from the Node, in this gase, coal
            [],                         # Potential additional data, no investment for the source
        ),
        RefNetworkNode(                 # Natural gas power plant with CCS
            5,                          # Node id
            FixedProfile(0),            # Capacity in MW, no initial capacity
            FixedProfile(5.5),          # Variable OPEX in EUR/MWh
            FixedProfile(1e5),          # Fixed OPEX in EUR/year
            Dict(NG => 2),              # Input to the node with input ratio
            Dict(Power => 1, CO2 => 0), # Output from the node with output ratio
            # Line above: CO2 is required as output for variable definition, but the
            # value does not matter
            [
                InvData(
                    capex_cap = FixedProfile(600*1e3),  # Capex in EUR/MW
                    cap_max_inst = FixedProfile(40),    # Max installed capacity [MW]
                    cap_max_add = FixedProfile(40),     # Max added capactity per sp [MW]
                    cap_min_add = FixedProfile(5),     # Min added capactity per sp [MW]
                    inv_mode = SemiContinuousInvestment(),  # Investment mode
                ),
                CaptureEnergyEmissions(0.9),            # CO2 capture included for the node
            ],
        ),
        RefNetworkNode(                 # Coal power plant
            6,                          # Node id
            FixedProfile(40),           # Capacity in MW
            FixedProfile(6),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/8h
            Dict(Coal => 2.5),          # Input to the node with input ratio
            Dict(Power => 1),           # Output from the node with output ratio
            [EmissionsEnergy()],        # Additonal data for emissions
        ),
        RefStorage(
            7,                          # Node id
            FixedProfile(0),            # Rate capacity in t/h
            FixedProfile(1e8),          # Storage capacity in t
            FixedProfile(9.1),          # Storage variable OPEX for the rate in EUR/t
            FixedProfile(15*1e3),       # Storage fixed OPEX for the rate in EUR/year
            CO2,                        # Stored resource
            Dict(CO2 => 1, Power => 0.02), # Input resource with input ratio
            # Line above: This implies that storing CO2 requires Power
            Dict(CO2 => 1),             # Output from the node with output ratio
            # In practice, for CO2 storage, this is never used.
            [InvDataStorage(
                    capex_rate = FixedProfile(200*1e3),
                    rate_max_inst = FixedProfile(60),
                    rate_max_add = FixedProfile(5),
                    rate_min_add = FixedProfile(0),
                    capex_stor = FixedProfile(0),
                    stor_max_inst = FixedProfile(1e9),
                    stor_max_add = FixedProfile(0),
                    stor_min_add = FixedProfile(0),
                    inv_mode = ContinuousInvestment(),
                ),
            ],
        )
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
        Direct(12, nodes[1], nodes[2], Linear())
        Direct(15, nodes[1], nodes[5], Linear())
        Direct(16, nodes[1], nodes[6], Linear())
        Direct(17, nodes[1], nodes[7], Linear())
        Direct(31, nodes[3], nodes[1], Linear())
        Direct(41, nodes[4], nodes[1], Linear())
        Direct(51, nodes[5], nodes[1], Linear())
        Direct(61, nodes[6], nodes[1], Linear())
        Direct(71, nodes[7], nodes[1], Linear())
    ]

    # WIP case structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )
    return case, model
end

# Generate case data.
case, model = generate_network_model()

# Run the optimization as an investment model.
m = EMB.create_model(case, model)
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
set_optimizer(m, optimizer)
optimize!(m)

# Display some results
@info "Invested capacity for the natural gas plant in the beginning of the individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_add][case[:nodes][5], :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)
@info "Invested capacity for the CO2 storage"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:stor_rate_add][case[:nodes][7], :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)

## Code above identical to the example EnergyModelsBase.jl/examples/network.jl
##########################################################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "..", "design", "EMI", "network")

# Run the GUI
gui = GUI(case; design_path, model = m)