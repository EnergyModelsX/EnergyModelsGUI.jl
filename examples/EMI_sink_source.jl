using HiGHS
using JuMP
using PrettyTables

# Generate the case and model data and run the model
case, model = generate_example_ss_investment()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
source, sink = get_nodes(case)
@info "Invested capacity for the source in the beginning of the individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_add][source, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)
@info "Retired capacity of the source at the end of the individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_rem][source, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)

## Code above identical to the example EnergyModelsInvestments.jl/examples/sink_source.jl
############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "design", "EMI", "sink_source")

# Run the GUI
gui = GUI(case; design_path, model = m)
