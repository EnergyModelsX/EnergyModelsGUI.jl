# Import the required packages
using EnergyModelsGUI
using EnergyModelsBase
using JuMP
using HiGHS
using PrettyTables
using TimeStruct

"""
    generate_example_test(; use_rp::Bool=true, use_sc::Bool=true)

Generate the data based on the EMB_sink_source.jl example with posibilities for different
time structures.
"""
function generate_example_test(; use_rp::Bool = true, use_sc::Bool = true)
    @info "Generate case data - Sink-source example with non-tensorial time structure"

    # Define the different resources and their emission intensity in tCO2/MWh
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("Carbondioxide", 1.0) # Use "Carbondioxide" to test GUI functionality
    products = [Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 1  # Each operational period has a duration of one hour
    op_number = 24   # There are in total 24 operational periods (one for each hour in a day)

    operational_periods = SimpleTimes(op_number, op_duration)
    no_days_in_year = 365
    segments = [[365], [100, 265], [100, 265]]
    no_hours_in_year = 24 * no_days_in_year

    # Creation of the time structure
    prob = [[[0.6, 0.4]], [[1.0], [0.5, 0.3, 0.2]], [[0.4, 0.3, 0.2, 0.1], [0.1, 0.9]]]
    scale_scenario = [
        [[0.9, 0.3]], [[0.2], [0.5, 0.4, 0.2]], [[1, 0.5, 0.26, 0.2], [0.4, 1.2]],
    ]

    demand_prof = [3, 2, 1, 1, 2, 4, 6, 7, 8, 7, 5, 4, 4, 4, 5, 5, 6, 8, 8, 8, 8, 6, 5, 4]
    demand = [demand_prof .+ 1, demand_prof]

    # duration of each strategic period
    dur = [8, 10, 10]
    no_dur = length(dur)
    if use_rp
        if use_sc
            periods = [
                RepresentativePeriods(
                    length(segments[sp]),
                    no_hours_in_year,
                    segments[sp] / no_days_in_year,
                    [
                        OperationalScenarios(
                            fill(operational_periods, length(prob[sp][rp])),
                            prob[sp][rp],
                        ) for rp ∈ 1:length(segments[sp])
                    ],
                ) for sp ∈ 1:no_dur
            ]
            profile = [
                RepresentativeProfile([
                    ScenarioProfile([
                        OperationalProfile(
                            demand[rp] * scale_scenario[sp][rp][sc] * rp * sp,
                        ) for sc ∈ 1:length(prob[sp][rp])
                    ]) for rp ∈ 1:length(segments[sp])
                ]) for sp ∈ 1:no_dur
            ]
            deficit = StrategicProfile([
                RepresentativeProfile([
                    ScenarioProfile([
                        FixedProfile(1e6 * sc * rp) for sc ∈ 1:length(prob[sp][rp])
                    ]) for rp ∈ 1:length(segments[sp])
                ]) for sp ∈ 1:no_dur
            ])
            T = TwoLevel(no_dur, dur, periods, 8760.0)
        else
            periods = RepresentativePeriods(
                length(segments[2]),
                no_hours_in_year,
                segments[2] / no_days_in_year,
                fill(operational_periods, length(segments[2])),
            )
            profile = [
                RepresentativeProfile([
                    OperationalProfile(demand[rp] * rp * sp) for rp ∈ [1, 2]
                ]) for sp ∈ 1:no_dur
            ]
            deficit = RepresentativeProfile([FixedProfile(1e6 * rp) for rp ∈ [1, 2]])
            T = TwoLevel(dur, periods; op_per_strat = 8760)
        end
    else
        if use_sc
            periods = OperationalScenarios(
                fill(operational_periods, length(prob[end][1])), prob[end][1],
            )
            profile = [
                ScenarioProfile([
                    OperationalProfile(demand[1] * scale_scenario[end][1][sc] * sp) for
                    sc ∈ 1:4
                ]) for sp ∈ 1:no_dur
            ]
            deficit = ScenarioProfile([
                FixedProfile(1e6 * scale_scenario[end][1][sc]) for sc ∈ 1:4
            ])
        else
            periods = operational_periods
            profile = [OperationalProfile(demand[1] * sp) for sp ∈ 1:no_dur]
            deficit = FixedProfile(1e6)
        end
        T = TwoLevel(dur, periods; op_per_strat = 8760)
    end

    model = OperationalModel(
        Dict(CO2 => FixedProfile(1e10)),  # Emission cap for CO₂ in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        CO2,                            # CO₂ instance
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    nodes = [
        RefSource(
            "electricity source",       # Node id
            FixedProfile(1e12),         # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/8h
            Dict(Power => 1),           # Output from the Node, in this gase, Power
            [EmissionsProcess(Dict(CO2 => 0.131))],
        ),
        RefSink(
            "electricity demand",       # Node id
            StrategicProfile(profile),  # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => deficit),
            Dict(Power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [Direct("source-demand", nodes[1], nodes[2], Linear())]

    # WIP data structure
    case = Dict(:nodes => nodes, :links => links, :products => products, :T => T)
    return case, model
end

"""
    run_test_case(; use_rp::Bool=true, use_sc::Bool=true)

Generate the case and model data, run the model and show results in GUI
"""
function run_test_case(; use_rp::Bool = true, use_sc::Bool = true)
    case, model = generate_example_test(; use_rp, use_sc)
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    m = run_model(case, model, optimizer)
    gui = GUI(
        case;
        model = m,
        periods_labels = ["2022 - 2030", "2030 - 2040", "2040 - 2050"],
        representative_periods_labels = ["Winter", "Remaining"],
        scenarios_labels = ["Scen 1", "Scen 2", "Scen 3", "Scen 4"],
    )
    return case, model, m, gui
end
