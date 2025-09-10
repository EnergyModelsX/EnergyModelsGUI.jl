# Generate the case and model data and run the model
case, model = generate_example_snd()
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
        value, m[:cap_use][get_nodes(case)[1], :]; header = [:TimePeriod, :Usage],
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
