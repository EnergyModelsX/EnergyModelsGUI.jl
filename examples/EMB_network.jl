using HiGHS
using JuMP
using PrettyTables

# Generate the case and model data and run the model
case, model = generate_example_network()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
ng_ccs_pp, coal_pp, = get_nodes(case)[[4, 5]]
@info "Capacity usage of the coal power plant"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_use][coal_pp, :];
        header = [:t, :Value],
    ),
)
@info "Capacity usage of the natural gas + CCS power plant"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_use][ng_ccs_pp, :];
        header = [:t, :Value],
    ),
)

## Code above identical to the example EnergyModelsBase.jl/examples/network.jl
############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set a special icon only for last node and the other icons based on type
id_to_icon_map = Dict(
    EMB.Source => "Source",
    EMB.NetworkNode => "Network",
    EMB.Sink => "Sink",
    7 => "factory_emissions",
)

# Update id_to_icon_map with full paths for the icons
id_to_icon_map = set_icons(id_to_icon_map)

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "design", "EMB", "network")

# Run the GUI
gui = GUI(case; design_path, id_to_icon_map, model = m)
