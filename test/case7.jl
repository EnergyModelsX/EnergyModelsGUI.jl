# Read a daily profile from the input files
case7_profile(file) = parse.(Float64, readlines(joinpath(@__DIR__, "inputfiles", file)))

# Penalties for surplus and deficit of the sinks
case7_penalty() = Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e5))

# Binary investment data with a lifetime of 30 years
case7_binary_inv(capex, cap) = SingleInvData(
    FixedProfile(capex),            # Capex [NOK/MW]
    FixedProfile(cap),              # Max installed capacity [MW]
    BinaryInvestment(FixedProfile(cap)), # Investment mode
    RollingLife(FixedProfile(30)),  # Lifetime mode
)

function read_data()
    @info "Setting up case7"

    # Define the different resources and their emission intensity in tCO2/MWh
    Power = ResourceCarrier("Power", 0.0)
    Heat = ResourceCarrier("Heat", 0.0)
    WarmWater = ResourceCarrier("WarmWater", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [Power, Heat, WarmWater, CO2]

    # Creation of the time structure with 24 operational periods of one hour, two
    # representative periods, and three strategic periods 2022--2029, 2030--2039, 2040--2049
    operational_periods = SimpleTimes(24, 1)
    no_days_in_year = 365
    representative_periods = RepresentativePeriods(
        2,
        24 * no_days_in_year,
        [100, 265] / no_days_in_year,
        fill(operational_periods, 2),
    )
    dur = [8, 10, 10]
    T = TwoLevel(dur, representative_periods; op_per_strat = 8760)

    # Create operational model (global data)
    em_limits = Dict(CO2 => StrategicProfile(0.0 * ones(length(dur))))   # Emission cap for CO2 in t/year
    em_cost = Dict(CO2 => FixedProfile(0))  # Emission price for CO2 in NOK/t
    discount_rate = 0.05 # discount rate in the investment optimization
    model = InvestmentModel(em_limits, em_cost, CO2, discount_rate)

    # Alter the electricity change factor. This scales the demand for electricity by a factor
    # 2 for 2030--2039 and a factor 4 for 2040--2049
    El_change_factor = [1, 2, 4]

    # Create the individual areas with their nodes and links
    area_1, nodes_1, links_1 = case7_area1(products, El_change_factor)
    area_2, nodes_2, links_2 = case7_area2(products)
    area_3, nodes_3, links_3 = case7_area3(products, El_change_factor)
    area_4, nodes_4, links_4 = case7_area4(products)
    areas = [area_1, area_2, area_3, area_4]

    # Set parameters for the power line (cable TXSP 1x3x150 AL: 22 kV, 310 A, no losses)
    capacity = 22 * 310 # P = V ⋅ I
    trans_cap = StrategicProfile(capacity * [1, 1, 0]) # Decomission the powerline in 2040
    trans_cap2 = FixedProfile(capacity)
    trans_cap3 = StrategicProfile(capacity * [0, 0, 1]) # Try to resolve the decomissioning with a Solar+Battery system in Area 4
    loss = FixedProfile(0.0)
    opex_var = FixedProfile(0.0) # No variable cost in operating the power line
    opex_fix = FixedProfile(0.0) # No fixed cost in operating the power line
    direction = 2 # Power flow direction can go two ways

    # Create a power line between the busbars
    Power_line = RefStatic(
        "El power line_11126", Power, trans_cap, loss, opex_var, opex_fix, direction,
    )
    Power_line2 = RefStatic(
        "El power line_11139", Power, trans_cap2, loss, opex_var, opex_fix, direction,
    )
    Power_line3 = RefStatic(
        "El power line_11139", Power, trans_cap3, loss, opex_var, opex_fix, direction,
    )

    # Construct the transmissions vector
    transmissions = [
        Transmission(areas[2], areas[1], [Power_line])
        Transmission(areas[2], areas[3], [Power_line2])
        Transmission(areas[4], areas[1], [Power_line3])
    ]

    case = Case(
        T,
        products,
        [
            EMB.Node[nodes_1; nodes_2; nodes_3; nodes_4],
            Link[links_1; links_2; links_3; links_4],
            areas,
            transmissions,
        ],
        [[get_nodes, get_links], [get_areas, get_transmissions]],
    )
    return case, model
end

# Area 1: electricity, heat, and warm water demand
function case7_area1(products, El_change_factor)
    Power, Heat, WarmWater = products[1:3]

    # Electricity demand, scaled for the strategic periods
    El_1_demand_day = case7_profile("el load.dat") # In MWh/h
    El_1_demand =
        [OperationalProfile(El_1_demand_day * factor) for factor ∈ El_change_factor]

    # Create heat demand profiles
    Heat_load_coefficient = 10
    Heat_demand = [
        FixedProfile(0.2 * Heat_load_coefficient), # For the representative period winter
        FixedProfile(0.2),                       # For the representative period remaining (of the year)
    ]

    # Calculate conversion value for heat pump
    T_hot = 60 + 273                            # Condensation temperature (indoor) in K
    T_cold = 10 + 273                           # Evaporation temperature (outdoor) in K
    COP_Carnot = T_hot / (T_hot - T_cold)       # Find the coefficient of performance
    efficiency = 0.5                            # Efficiency compared with an ideal heat pump
    conversion = COP_Carnot * efficiency        # Conversion factor

    heatpump_output_capacity = 1                # Set the maximum amount of heat the heat pump can produce
    cap = heatpump_output_capacity / conversion # heat pump capacity usage cap

    # Construct nodes
    el_busbar_11125 = GeoAvailability("El busbar_11125", products[1:1])
    el_1 = RefSink(
        "El 1",                           # Node id
        StrategicProfile(El_1_demand),    # cap: the demand
        case7_penalty(),                  # penalty: penalties for surplus or deficits
        Dict(Power => 1),                 # input `Resource`s with conversion value `Real`
    )
    heat_generator = RefNetworkNode(
        "Heat generator",       # Node id
        FixedProfile(10),       # cap: Installed capacity
        FixedProfile(0.0),      # opex_var: variational operational vost per energy unit produced
        FixedProfile(0),        # opex_fixed: is the fixed operational costs
        Dict(Power => 1),       # input: input `Resource`s with conversion value `Real`
        Dict(Heat => 1),        # output: generated `Resource`s with conversion value `Real`
    )
    water_heater = RefNetworkNode(
        "Water heater",         # Node id
        FixedProfile(10),       # cap: Installed capacity
        FixedProfile(0.0),      # opex_var: variational operational vost per energy unit produced
        FixedProfile(0),        # opex_fixed: is the fixed operational costs
        Dict(Power => 1),       # input: input `Resource`s with conversion value `Real`
        Dict(WarmWater => 1),   # output: generated `Resource`s with conversion value `Real`
    )
    heating_1 = RefSink(
        "Heating 1",                        # Node id
        RepresentativeProfile(Heat_demand), # cap: the demand
        case7_penalty(),                    # penalty: penalties for surplus or deficits
        Dict(Heat => 1),                    # input `Resource`s with conversion value `Real`
    )
    hot_water_1 = PeriodDemandSink(
        "Hot water 1",                      # Node id
        FixedProfile(0.5),                  # cap: maximum demand satisfaction per operational period
        12,                                 # period_duration: 2 demand periods per representative period
        PartitionProfile([3, 1.8]),         # period_demand: the demand within each demand period
        case7_penalty(),                    # penalty: penalties for surplus or deficits
        Dict(WarmWater => 1),               # input `Resource`s with conversion value `Real`
    )
    heat_pump = RefNetworkNode(
        "Heat pump",                            # Node id
        FixedProfile(0),                        # cap: Installed capacity
        FixedProfile(0),                        # opex_var: variational operational vost per energy unit produced
        FixedProfile(0),                        # opex_fixed: is the fixed operational costs
        Dict(Power => 1, Heat => conversion - 1), # input: input `Resource`s with conversion value `Real`
        Dict(Heat => conversion),               # output: generated `Resource`s with conversion value `Real`
        [case7_binary_inv(1e7 / cap, cap)],
    )
    waste_heat_data_center = RefSource(
        "Waste heat data center",   # Node id
        FixedProfile(0),            # Cap, installed capacity
        FixedProfile(0),            # Variable operational cost per unit produced
        FixedProfile(0),            # Fixed operational cost per unit produced
        Dict(Heat => 1),            # The generated resources with conversion value 1
        [case7_binary_inv(0, 1)],
    )
    nodes = [
        el_busbar_11125,
        el_1,
        heat_generator,
        water_heater,
        heating_1,
        hot_water_1,
        heat_pump,
        waste_heat_data_center,
    ]

    # Create links between nodes
    links = [
        Direct("El busbar_11125 - El 1", el_busbar_11125, el_1, Linear()),
        Direct(
            "El busbar_11125 - Heat generator",
            el_busbar_11125,
            heat_generator,
            Linear(),
        ),
        Direct("El busbar_11125 - Water heater", el_busbar_11125, water_heater, Linear()),
        Direct("Heat generator - Heating 1", heat_generator, heating_1, Linear()),
        Direct("Water heater - Hot water 1", water_heater, hot_water_1, Linear()),
        Direct("El busbar_11125 - Heat pump", el_busbar_11125, heat_pump, Linear()),
        Direct("Heat pump - Heating 1", heat_pump, heating_1, Linear()),
        Direct(
            "Waste heat data center - Heat pump",
            waste_heat_data_center,
            heat_pump,
            Linear(),
        ),
    ]

    # Create the area
    area = RefArea("area1", "Area 1", -92, 40, el_busbar_11125)
    return area, nodes, links
end

# Area 2: power supply with a variable electricity cost
function case7_area2(products)
    Power = products[1]

    # Construct nodes
    El_cost = case7_profile("el cost.dat") # In NOK/MWh
    el_busbar_11124 = GeoAvailability("El busbar_11124", products[1:1])
    power_supply = RefSource(
        "Power supply",                     # Node id
        FixedProfile(10),                   # Cap, installed capacity
        OperationalProfile(El_cost),        # Variable operational cost per unit produced
        FixedProfile(0),                    # Fixed operational cost per unit produced
        Dict(Power => 1),                   # The generated resources with conversion value 1
    )
    nodes = [el_busbar_11124, power_supply]

    # Create links between nodes
    links = [Direct("Link from power supply", power_supply, el_busbar_11124, Linear())]

    # Create the area
    area = RefArea("area2", "Area 2", -93, 40, el_busbar_11124)
    return area, nodes, links
end

# Area 3: EV charger, introduced in 2030
function case7_area3(products, El_change_factor)
    Power = products[1]

    # Since the EV charger is introduced in 2030, the El_change_factor is shifted such that the
    # initial profile is not scaled (starting at the second strategic period)
    EV_charger_demand_day = case7_profile("charging.dat") # In MWh/h
    EV_charger_change_factors = [1, El_change_factor[3] / El_change_factor[2]]
    EV_charger_demand = [
        FixedProfile(0.0),
        [
            OperationalProfile(EV_charger_demand_day * f) for f ∈ EV_charger_change_factors
        ]...,
    ]

    # Construct nodes
    el_busbar_11137 = GeoAvailability("El busbar_11137", products[1:1])
    ev_charger = RefSink(
        "EV charger",                           # Node id
        StrategicProfile(EV_charger_demand),    # cap: the demand
        case7_penalty(),                        # penalty: penalties for surplus or deficits
        Dict(Power => 1),                       # input `Resource`s with conversion value `Real`
    )
    nodes = [el_busbar_11137, ev_charger]

    # Create links between nodes
    links = [Direct("Link to EV charger", el_busbar_11137, ev_charger, Linear())]

    # Create the area
    area = RefArea("area3", "Area 3", -92, 38, el_busbar_11137)
    return area, nodes, links
end

# Area 4: solar power and battery
function case7_area4(products)
    Power = products[1]

    # Solar profile relative to its maximum
    max_outtake_day = case7_profile("solar.dat") # In MW
    max_max_outtake = maximum(max_outtake_day)
    profile = max_outtake_day / max_max_outtake

    # Construct nodes
    el_busbar_11149 = GeoAvailability("El busbar_11149", products[1:1])
    solar_Power = NonDisRES(
        "Solar Power",                  # id: Node id
        FixedProfile(0),                # cap: the installed capacity in MW
        OperationalProfile(profile),    # profile: the power production in each operational period as a ratio of the installed capacity at that time
        FixedProfile(0),                # opex_var: Variable operational cost per unit produced
        FixedProfile(0),                # opex_fixed: Fixed operational cost per unit produced
        Dict(Power => 1),               # output: The generated resources with conversion value 1
        [case7_binary_inv(5e8 / max_max_outtake, max_max_outtake)],
    )
    battery = RefStorage{CyclicStrategic}(
        "Battery",               # Node id
        StorCapOpex(
            FixedProfile(100),   # Charge capacity in Wh/h
            FixedProfile(0),     # Storage variable OPEX for the charging in NOK/Wh
            FixedProfile(0)     # Storage fixed OPEX for the charging in NOK/Wh
        ),
        StorCap(FixedProfile(0)), # Storage capacity in Wh
        Power,                   # Stored resource
        Dict(Power => 1),        # Input resource with input ratio
        Dict(Power => 0.9),      # Output from the node with output ratio
        [
            StorageInvData(
                level = NoStartInvData(
                    FixedProfile(0),                # capex: capital costs [NOK/MW]
                    FixedProfile(100),              # max_inst: maximum installed capacity
                    BinaryInvestment(FixedProfile(100)), # inv_mode: chosen investment mode
                    RollingLife(FixedProfile(30)),  # life_mode: type of handling the lifetime
                ),
            ),
        ],
    )
    nodes = [el_busbar_11149, solar_Power, battery]

    # Create links between nodes
    links = [
        Direct("Link to solar power", solar_Power, el_busbar_11149, Linear()),
        Direct("Link to Battery", el_busbar_11149, battery, Linear()),
        Direct("Link from Battery", battery, el_busbar_11149, Linear()),
    ]

    # Create the area
    area = RefArea("area4", "Area 4", -93, 41, el_busbar_11149)
    return area, nodes, links
end

function run_case()
    # Get case and model data
    case, model = read_data()

    # Construct JuMP model for optimization
    m = create_model(case, model)

    # Set optimizer for JuMP
    set_optimizer(m, HiGHS.Optimizer)

    # Solve the optimization problem
    optimize!(m)

    # Check that the case is unchanged (relative MIP gap of HiGHS)
    @test isapprox(objective_value(m), -1.7918992874812832e8; rtol = 1e-4)

    # Run the GUI
    gui = GUI(
        case;
        design_path = joinpath(@__DIR__, "design", "case7"),
        model = m,
        periods_labels = ["2022 - 2030", "2030 - 2040", "2040 - 2050"],
        representative_periods_labels = ["Winter", "Remaining"],
        case_name = "case7",
        scale_tot_opex = false,
        scale_tot_capex = true,
        pre_plot_sub_components = false,
    )

    return case, model, m, gui
end
