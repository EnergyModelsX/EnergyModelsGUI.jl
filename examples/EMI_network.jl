# Generate the case and model data and run the model
case, model = generate_example_network_investment()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
ng_ccs_pp, CO2_stor, = get_nodes(case)[[4, 6]]
@info "Invested capacity for the natural gas plant in the beginning of the \
individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:cap_add][ng_ccs_pp, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)
@info "Invested capacity for the CO2 storage in the beginning of the
individual strategic periods"
pretty_table(
    JuMP.Containers.rowtable(
        value,
        m[:stor_charge_add][CO2_stor, :];
        header = [:StrategicPeriod, :InvestCapacity],
    ),
)

## Code above identical to the example EnergyModelsInvestments.jl/examples/network.jl
############################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "design", "EMI", "network")

# Run the GUI
gui = GUI(case; design_path, model = m)
