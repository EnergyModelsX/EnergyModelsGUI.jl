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
non-dispatchable power source, a standard source, as well as a demand.
It illustrates how the non-dispatchable power source requires a balancing power source.
"""
function generate_example_data()
    @info "Generate case data - Simple `NonDisRES` example"

    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    products = [Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = op_duration * op_number

    # Creation of the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    source = RefSource(
        "source",           # Node ID
        FixedProfile(2),    # Capacity in MW
        FixedProfile(30),   # Variable OPEX in EUR/MW
        FixedProfile(10),   # Fixed OPEX in EUR/8h
        Dict(Power => 1),   # Output from the Node, in this gase, Power
    )
    sink = RefSink(
        "electricity demand",   # Node id
        FixedProfile(2),    # Demand in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(Power => 1),   # Energy demand and corresponding ratio
    )
    nodes = [source, sink]

    # Connect the two nodes with each other
    links = [Direct("source-demand", nodes[1], nodes[2], Linear())]

    # Create the case dictionary
    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)

    # Create the additonal non-dispatchable power source
    wind = NonDisRES(
        "wind",             # Node ID
        FixedProfile(4),    # Capacity in MW
        OperationalProfile([0.9, 0.4, 0.1, 0.8]), # Profile of the NonDisRES node
        FixedProfile(10),   # Variable OPEX in EUR/MW
        FixedProfile(10),   # Fixed OPEX in EUR/8h
        Dict(Power => 1),   # Output from the Node, in this gase, Power
    )

    # Update the case data with the non-dispatchable power source and link
    push!(case[:nodes], wind)
    link = Direct("wind-demand", case[:nodes][3], case[:nodes][2], Linear())
    push!(case[:links], link)

    return case, model
end

# Generate the case and model data and run the model
case, model = generate_example_data()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = EMB.run_model(case, model, optimizer)

# Display some results
@info "Curtailment of the wind power source"
pretty_table(
    JuMP.Containers.rowtable(
        value, m[:curtailment]; header = [:Node, :TimePeriod, :Curtailment],
    ),
)
@info "Capacity usage of the power source"
pretty_table(
    JuMP.Containers.rowtable(
        value, m[:cap_use][case[:nodes][1], :]; header = [:TimePeriod, :Usage],
    ),
)

## Code above identical to the example EnergyModelsRenewableProducers.jl/examples/simple_nondisres.jl
############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "design", "EMR", "simple_nondisres")

# Run the GUIidToIconMap,
gui = GUI(case; design_path, model = m)
