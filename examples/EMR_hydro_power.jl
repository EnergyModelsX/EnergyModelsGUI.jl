using HiGHS
using JuMP
using PrettyTables

# Generate the case and model data and run the model
case, model = generate_example_hp()
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
