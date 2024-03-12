using EnergyModelsBase
using EnergyModelsRenewableProducers
using HiGHS
using JuMP
using PrettyTables
using TimeStruct

const EMB = EnergyModelsBase

function generate_data()
    @info "Generate data"

    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 1.0)
    products = [CO2, Power]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods, which
    # can also be extracted using the function `duration` of a `SimpleTimes` structure.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = duration(operational_periods)

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
    hydro = HydroStor(
        "hydropower",       # Node ID
        FixedProfile(2.0),  # Rate capacity in MW
        FixedProfile(90),   # Storage capacity in MWh
        FixedProfile(10),   # Initial storage level in MWh
        FixedProfile(1),    # Inflow to the Node in MW
        FixedProfile(0.0),  # Minimum storage level as fraction
        FixedProfile(8),    # Variable OPEX in EUR/MWh
        FixedProfile(3),    # Fixed OPEX in EUR/8h
        Power,              # Stored resource
        Dict(Power => 0.9), # Input to the power plant, irrelevant in this case
        Dict(Power => 1),   # Output from the Node, in this gase, Power
        Data[],                 # Potential additional data
    )

    # Create a power demand node
    sink = RefSink(
        "sink",             # Node ID
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
        Direct("av-si", av, sink),
    ]

    # Create the case dictionary
    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

    return case, model
end

# Create the case and model data and run the model
case, model = generate_data()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMB.run_model(case, model, optimizer)

# Display some results
@info "Storage level of the hydro power plant"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:stor_level];
        header = [:Node, :TimePeriod, :Level],
    ),
)
@info "Power production of the two power sources"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:flow_out][case[:nodes][2:3], :, case[:products][2]];
        header = [:Node, :TimePeriod, :Production],
    ),
)

# Uncomment to show some of the results.
# inspect_results()

## Code above identical to the example EnergyModelsBase.jl/examples/network.jl
##########################################################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set folder where visualization info is saved and rBtrieved
design_path = joinpath(@__DIR__, "..", "design", "EMR", "hydro_power")

# Run the GUIidToIconMap, 
gui = GUI(case; design_path, model = m)

