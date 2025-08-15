using HiGHS
using JuMP

# Generate case data
case, model = generate_example_data_geo()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = create_model(case, model)
set_optimizer(m, optimizer)
optimize!(m)

solution_summary(m)

# Uncomment to print all the constraints set in the model.
# print(m)

############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "design", "EMI", "geography")

# Run the GUI
gui = GUI(
    case;
    design_path,
    model = m,
    coarse_coast_lines = false,
    scale_tot_opex = true,
    scale_tot_capex = false,
)
