# Import the required packages
using EnergyModelsBase
using EnergyModelsRenewableProducers
using HiGHS
using JuMP
using PrettyTables
using TimeStruct

const EMB = EnergyModelsBase

"""
    generate_example_data()

Generate the data for an example consisting of a simple electricity network with a
non-dispatchable power source, a regulated hydro power plant, as well as a demand.
It illustrates how the hydro power plant can balance the intermittent renewable power
generation.
"""
function generate_example_data()
    @info "Generate case data - Simple `HydroStor` example"

    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 1.0)
    products = [CO2, Power]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = op_duration * op_number

    # Create the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )
    # Create the Availability/bus node for the system
    av = GenAvailability(1, products)

    # Create a non-dispatchable renewable energy source
    wind = NonDisRES(
        "wind",             # Node ID
        FixedProfile(2),    # Capacity in MW
        OperationalProfile([0.9, 0.4, 0.1, 0.8]), # Profile
        FixedProfile(5),    # Variable OPEX in EUR/MW
        FixedProfile(10),   # Fixed OPEX in EUR/8h
        Dict(Power => 1),   # Output from the Node, in this gase, Power
    )

    # Create a regulated hydro power plant without storage capacity
    hydro = HydroStor{CyclicStrategic}(
        "hydropower",       # Node ID
        StorCapOpexFixed(FixedProfile(90), FixedProfile(3)),
        # Line above for the storage level:
        #   Argument 1: Storage capacity in MWh
        #   Argument 2: Fixed OPEX in EUR/8h
        StorCapOpexVar(FixedProfile(2.0), FixedProfile(8)),
        # Line above for the discharge rate:
        #   Argument 1: Rate capacity in MW
        #   Argument 2: Variable OPEX in EUR/MWh
        FixedProfile(10),   # Initial storage level in MWh
        FixedProfile(1),    # Inflow to the Node in MW
        FixedProfile(0.0),  # Minimum storage level as fraction
        Power,              # Stored resource
        Dict(Power => 0.9), # Input to the power plant, irrelevant in this case
        Dict(Power => 1),   # Output from the Node, in this gase, Power
    )

    # Create a power demand node
    sink = RefSink(
        "electricity demand",   # Node id
        FixedProfile(2),    # Demand in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(Power => 1),   # Energy demand and corresponding ratio
    )

    # Create the array of ndoes
    nodes = [av, wind, hydro, sink]

    # Connect all nodes with the availability node for the overall energy balance
    links = [
        Direct("wind-av", wind, av),
        Direct("hy-av", hydro, av),
        Direct("av-hy", av, hydro),
        Direct("av-demand", av, sink),
    ]

    # Create the case dictionary
    case = Case(T, products, [nodes, links])

    return case, model
end

# Generate the case and model data and run the model
case, model = generate_example_data()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMB.run_model(case, model, optimizer)

# Display some results
@info "Storage level of the hydro power plant"
pretty_table(
    JuMP.Containers.rowtable(value, m[:stor_level]; header = [:Node, :TimePeriod, :Level]),
)
@info "Power production of the two power sources"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:flow_out][get_nodes(case)[2:3], :, get_products(case)[2]];
        header = [:Node, :TimePeriod, :Production],
    ),
)

# Uncomment to show some of the results.
# inspect_results()

## Code above identical to the example EnergyModelsRenewableProducers.jl/examples/simple_hydro_power.jl
############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set folder where visualization info is saved and rBtrieved
design_path = joinpath(@__DIR__, "design", "EMR", "hydro_power")

# Run the GUIidToIconMap,
gui = GUI(case; design_path, model = m)
