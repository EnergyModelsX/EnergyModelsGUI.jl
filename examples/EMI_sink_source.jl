# Import the required packages
using EnergyModelsBase
using EnergyModelsInvestments
using HiGHS
using JuMP
using PrettyTables
using TimeStruct

const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const TS = TimeStruct

"""
    generate_example_data()

Generate the data for an example consisting of an electricity source and sink.
The electricity source has initially no capacity. Hence, investments are required.

The example is partly based on the provided example `sink_source.jl` in `EnergyModelsBase`.
"""
function generate_example_data(lifemode=RollingLife; discount_rate=0.05)
    @info "Generate case data - Simple sink-source example"

    # Define the different resources and their emission intensity in tCO2/MWh
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    products = [Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The duration of operational periods per duration of 1 of a strategic period of 8760
    # implies that a duration of 1 of an operational period corresponds to an hour, while
    # a duration of 1 of a strategic period corresponds to a year
    op_per_strat = 8760

    sp_duration = 5 # The duration of a strategic period is given as 5 years

    # Creation of the time structure and global data
    T = TwoLevel(4, sp_duration, operational_periods; op_per_strat)

    # Create the global data
    em_limits = Dict(CO2 => FixedProfile(10))   # Emission cap for CO2 in t/8h
    em_cost = Dict(CO2 => FixedProfile(0))      # Emission price for CO2 in EUR/t
    model = InvestmentModel(em_limits, em_cost, CO2, discount_rate)

    # The lifetime of the technology is 15 years, requiring reinvestment in the
    # 5th strategic period
    lifetime = FixedProfile(15)

    # Create the investment data for the source node
    investment_data_source = SingleInvData(
        FixedProfile(300 * 1e3),  # capex [€/MW]
        FixedProfile(30),       # max installed capacity [MW]
        ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
        # Line above: Investment mode with the following arguments:
        # 1. argument: min added capactity per sp [MW]
        # 2. argument: max added capactity per sp [MW]
        lifemode(lifetime),     # Lifetime mode
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    source = RefSource(
        "electricity source",       # Node ID
        FixedProfile(0),            # Capacity in MW
        FixedProfile(10),           # Variable OPEX in EUR/MW
        FixedProfile(5),            # Fixed OPEX in EUR/year
        Dict(Power => 1),           # Output from the Node, in this gase, Power
        [investment_data_source],   # Additional data used for adding the investment data
    )
    sink = RefSink(
        "electricity demand",       # Node ID
        FixedProfile(20),           # Demand in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(Power => 1),           # Power demand and corresponding ratio
    )
    nodes = [source, sink]

    # Connect the two ndoes
    links = [Direct("source-demand", nodes[1], nodes[2], Linear())]

    # WIP data structure
    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)
    return case, model
end

# Create the case and model data and run the model
case, model = generate_example_data()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMB.run_model(case, model, optimizer)

# Display some results
source, sink = case[:nodes]
@info "Invested capacity for the source in the beginning of the individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value, m[:cap_add][source, :]; header=[:StrategicPeriod, :InvestCapacity]
    ),
)
@info "Retired capacity of the source at the end of the individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value, m[:cap_rem][source, :]; header=[:StrategicPeriod, :InvestCapacity]
    ),
)

## Code above identical to the example EnergyModelsInvestments.jl/examples/sink_source.jl
############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "design", "EMI", "sink_source")

# Run the GUI
gui = GUI(case; design_path, model=m)
