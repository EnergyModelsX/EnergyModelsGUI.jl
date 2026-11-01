# Helpers shared by the case builders

# Read a daily profile from the input files
read_profile(file) = parse.(Float64, readlines(joinpath(@__DIR__, "inputfiles", file)))

# Penalties for surplus and deficit of the sinks
penalty() = Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e5))

# Binary investment data with a lifetime of 30 years
binary_inv(capex, cap) = SingleInvData(
    FixedProfile(capex),            # Capex [NOK/MW]
    FixedProfile(cap),              # Max installed capacity [MW]
    BinaryInvestment(FixedProfile(cap)), # Investment mode
    RollingLife(FixedProfile(30)),  # Lifetime mode
)

# Continuous investment data without initial capacity
continuous_inv(capex, max_inst, min_add, max_add) = SingleInvData(
    FixedProfile(capex),            # Capex [€/kW]
    FixedProfile(max_inst),         # Max installed capacity [kW]
    ContinuousInvestment(FixedProfile(min_add), FixedProfile(max_add)), # Investment mode
)
