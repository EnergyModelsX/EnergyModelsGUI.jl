# Generate the case and model data and run the model
case, model = generate_example_ss()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
source, sink = get_nodes(case)
@info "Capacity usage of the power source"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_use][source, :];
        header = [:t, :Value],
    ),
)

## Code above identical to the example EnergyModelsBase.jl/examples/sink_source.jl
############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set custom icons
icon_names = Dict(
    "electricity source" => "hydro_power_plant",
    "electricity demand" => "factory_emissions",
)
id_to_icon_map = set_icons(icon_names)

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "design", "EMB", "sink_source")

# Run the GUI
gui = GUI(case; design_path, id_to_icon_map, model = m)
