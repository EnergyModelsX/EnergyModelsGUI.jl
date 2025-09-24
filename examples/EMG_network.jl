# Generate the case and model data and run the model
case, model = generate_example_geo()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = create_model(case, model)
set_optimizer(m, optimizer)
optimize!(m)

solution_summary(m)

## Code above identical to the example EnergyModelsGeography.jl/examples/network.jl
############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Colors can be taylored as in the following example
products = get_products(case)
NG = products[1] # Extract NG object
Power = products[3] # Extract Power object
id_to_color_map = Dict(Power.id => :cyan, NG.id => "#FF9876")

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "design", "EMG", "network")

# Run the GUI
gui = GUI(case; design_path, id_to_color_map, model = m)
