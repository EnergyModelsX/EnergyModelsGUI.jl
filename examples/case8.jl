using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsInvestments
using EnergyModelsRenewableProducers
using EnergyModelsGUI
using JuMP
using HiGHS
using TimeStruct

const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography
case_name = "case8"

function read_data()
    @info "Setting up $case_name"

    # Define the different resources and their emission intensity in tCO₂/MWh
    Power = ResourceCarrier("Power", 0.0)
    Heat = ResourceCarrier("Heat", 0.0)
    WarmWater = ResourceCarrier("WarmWater", 0.0)
    Waste = ResourceCarrier("Waste", 1.0)
    CO₂ = ResourceEmit("CO₂", 1.0)
    NOx = ResourceEmit("NOx", 1.0)
    CO = ResourceEmit("CO", 1.0)
    products = [Power, Heat, WarmWater, Waste, CO₂, NOx, CO]
    #products = [Power, Heat, WarmWater, Waste, CO₂]

    # Variables for the individual entries of the time structure
    op_duration = 1  # Each operational period has a duration of one hour
    op_number = 24   # There are in total 24 operational periods (one for each hour in a day)

    operational_periods = SimpleTimes(op_number, op_duration)
    no_days_in_year = 365
    no_segments = 2
    no_hours_in_year = 24 * no_days_in_year

    # Creation of the time structure
    with_scenarios = true

    prob = [0.4, 0.3, 0.2, 0.1]
    scenarios = OperationalScenarios(fill(operational_periods, length(prob)), prob)

    if with_scenarios
        representative_periods = RepresentativePeriods(
            no_segments,
            no_hours_in_year,
            [100, 265] / no_days_in_year,
            fill(scenarios, no_segments),
        )
    else
        representative_periods = RepresentativePeriods(
            no_segments,
            no_hours_in_year,
            [100, 265] / no_days_in_year,
            fill(operational_periods, no_segments),
        )
    end

    dur = [8, 10, 10]          # duration of the four strategic period 2022--2029, 2030--2039, 2040--2049

    T = TwoLevel(dur, representative_periods; op_per_strat=8760)

    noSP = length(dur)     # Number of strategic periods

    # Create operational model (global data)
    em_limits = Dict(
        CO₂ => StrategicProfile(1e10 * ones(noSP)),
        NOx => StrategicProfile(1e10 * ones(noSP)),
        CO => StrategicProfile(1e10 * ones(noSP)),
    )   # Emission cap for CO₂ in t/year
    em_cost = Dict(
        CO₂ => FixedProfile(0.0), NOx => FixedProfile(0.0), CO => FixedProfile(0.0)
    )  # Emission price for CO₂ in NOK/t
    discount_rate = 0.05 # discount rate in the investment optimization
    model = InvestmentModel(em_limits, em_cost, CO₂, discount_rate)

    # Create input data for the areas
    noAreas = 9 # number of areas
    area_ids = ["Area " * string(i) for i ∈ range(1, noAreas)]

    an = Vector(undef, noAreas) # Create a vector of all availability nodes connected to the areas
    nodes = []
    links = []
    for (i, a_id) ∈ enumerate(area_ids)
        n, l = get_sub_system_data(a_id, products, T, with_scenarios)
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[i] = n[1]
    end

    # Create the individual areas and transmission modes
    el_busbar_11125 = RefArea(
        1,        # name/identifier of the area
        "Area 1", # name of the area
        -92,      # longitudinal position of the area
        40,       # latitudinal position of the area
        an[1],    # the `Availability` node routing different resources within an area
    )
    el_busbar_11124 = RefArea(
        2,        # name/identifier of the area
        "Area 2", # name of the area
        -93,      # longitudinal position of the area
        40,       # latitudinal position of the area
        an[2],    # the `Availability` node routing different resources within an area
    )
    el_busbar_11137 = RefArea(
        3,        # name/identifier of the area
        "Area 3", # name of the area
        -92,      # longitudinal position of the area
        38,       # latitudinal position of the area
        an[3],    # the `Availability` node routing different resources within an area
    )
    el_busbar_11149 = RefArea(
        4,        # name/identifier of the area
        "Area 4", # name of the area
        -93,      # longitudinal position of the area
        41,       # latitudinal position of the area
        an[4],    # the `Availability` node routing different resources within an area
    )
    DH_junction_points_11165 = RefArea(
        5,        # name/identifier of the area
        "Area 5", # name of the area
        -90,      # longitudinal position of the area
        40,       # latitudinal position of the area
        an[5],    # the `Availability` node routing different resources within an area
    )
    DH_junction_points_11167 = RefArea(
        6,        # name/identifier of the area
        "Area 6", # name of the area
        -91,      # longitudinal position of the area
        40,       # latitudinal position of the area
        an[6],    # the `Availability` node routing different resources within an area
    )
    DH_junction_points_11169 = RefArea(
        7,        # name/identifier of the area
        "Area 7", # name of the area
        -89,      # longitudinal position of the area
        40,       # latitudinal position of the area
        an[7],     # the `Availability` node routing different resources within an area
    )
    DH_Load_points_11173 = RefArea(
        8,        # name/identifier of the area
        "Area 8", # name of the area
        -88,      # longitudinal position of the area
        40,       # latitudinal position of the area
        an[8],    # the `Availability` node routing different resources within an area
    )
    DH_Load_points_11177 = RefArea(
        9,        # name/identifier of the area
        "Area 9", # name of the area
        -87,      # longitudinal position of the area
        40,       # latitudinal position of the area
        an[9],     # the `Availability` node routing different resources within an area
    )

    areas = [
        el_busbar_11125,
        el_busbar_11124,
        el_busbar_11137,
        el_busbar_11149,
        DH_junction_points_11165,
        DH_junction_points_11167,
        DH_junction_points_11169,
        DH_Load_points_11173,
        DH_Load_points_11177,
    ]

    # Set parameters for the power line
    capacity, lossRatio = get_cable_data()
    trans_cap = StrategicProfile(capacity * [1, 1, 0]) # Decomission the powerline in 2040
    trans_cap2 = FixedProfile(capacity)
    trans_cap3 = StrategicProfile(capacity * [0, 0, 1]) # Try to resolve the decomissioning with a Solar+Battery system in Area 4
    loss = FixedProfile(lossRatio)
    opex_var = FixedProfile(0.0) # No variable cost in operating the power line
    opex_fix = FixedProfile(0.0) # No fixed cost in operating the power line
    direction = 2 # Power flow direction can go two ways

    DH_Pipe_Length = 1000
    pipe_capacity = 20
    users_heat_loss_factor = 10
    trans_cap_heat = FixedProfile(pipe_capacity)
    loss_heat = FixedProfile(0.0)
    opex_var_heat = FixedProfile(0.0) # No variable cost in operating the power line
    opex_fix_heat = FixedProfile(0.0) # No fixed cost in operating the power line

    # Create a power line between the busbars
    Power_line = RefStatic(
        "El power line_11126", Power, trans_cap, loss, opex_var, opex_fix, direction, []
    )
    Power_line2 = RefStatic(
        "El power line_11139", Power, trans_cap2, loss, opex_var, opex_fix, direction, []
    )
    Power_line3 = RefStatic(
        "El power line_11139", Power, trans_cap3, loss, opex_var, opex_fix, direction, []
    )
    DH_Pipe_lines_11166 = RefStatic(
        "DH_Pipe_lines_11166",
        Heat,
        trans_cap_heat,
        loss_heat,
        opex_var_heat,
        opex_fix_heat,
        1,
        [],
    )
    DH_Pipe_lines_11168 = RefStatic(
        "DH_Pipe_lines_11168",
        Heat,
        trans_cap_heat,
        loss_heat,
        opex_var_heat,
        opex_fix_heat,
        1,
        [],
    )
    DH_Pipe_lines_11170 = RefStatic(
        "DH_Pipe_lines_11170",
        Heat,
        trans_cap_heat,
        loss_heat,
        opex_var_heat,
        opex_fix_heat,
        1,
        [],
    )
    DH_Pipe_lines_11172 = RefStatic(
        "DH_Pipe_lines_11172",
        Heat,
        trans_cap_heat,
        loss_heat,
        opex_var_heat,
        opex_fix_heat,
        1,
        [],
    )
    DH_Pipe_lines_11174 = RefStatic(
        "DH_Pipe_lines_11174",
        Heat,
        trans_cap_heat,
        loss_heat,
        opex_var_heat,
        opex_fix_heat,
        1,
        [],
    )
    DH_Pipe_lines_11179 = RefStatic(
        "DH_Pipe_lines_11179",
        Heat,
        trans_cap_heat,
        loss_heat,
        opex_var_heat,
        opex_fix_heat,
        1,
        [],
    )

    # Construct the transmission object
    transmission = [
        Transmission(el_busbar_11124, el_busbar_11125, [Power_line])
        Transmission(el_busbar_11124, el_busbar_11137, [Power_line2])
        Transmission(el_busbar_11149, el_busbar_11125, [Power_line3])
        Transmission(el_busbar_11124, DH_junction_points_11165, [DH_Pipe_lines_11166])
        Transmission(
            DH_junction_points_11165, DH_junction_points_11167, [DH_Pipe_lines_11168]
        )
        Transmission(
            DH_junction_points_11167, DH_junction_points_11169, [DH_Pipe_lines_11170]
        )
        Transmission(DH_junction_points_11169, el_busbar_11125, [DH_Pipe_lines_11172])
        Transmission(DH_junction_points_11169, DH_Load_points_11173, [DH_Pipe_lines_11174])
        Transmission(DH_junction_points_11167, DH_Load_points_11177, [DH_Pipe_lines_11179])
    ]

    # WIP data structure
    case = Dict(
        :areas => Array{Area}(areas),
        :transmission => Array{Transmission}(transmission),
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{Link}(links),
        :products => products,
        :T => T,
    )
    return case, model
end

# Subsystem test data for geography package
function get_sub_system_data(a_id, products, T, with_scenarios)
    Power = products[1]
    Heat = products[2]
    WarmWater = products[3]
    Waste = products[4]
    CO₂ = products[5]
    NOx = products[6]
    CO = products[7]
    El_change_factor = [1, 2, 4] # Alter the electricity change factor. This scales the demand for electricity by a factor 2 for 2030--2039 and a factor 4 for 2040--2049
    El_cap_scenario = [1, 0.5, 0.26, 0.2]
    inputFolder = joinpath(@__DIR__, "Inputfiles")
    if a_id == "Area 1"
        # Load the demand profile from file
        El_1_demand_file = readlines(inputFolder * raw"/el load.dat")
        El_1_demand_day = [parse(Float64, line) for line ∈ El_1_demand_file] # In MWh/h
        El_1_demand = [
            OperationalProfile(El_1_demand_day * El_change_factor[i]) for i ∈ 1:(T.len)
        ]

        # Create heat demand profiles
        Heat_load_coefficient = 10
        Heat_demand = [
            FixedProfile(0.2 * Heat_load_coefficient), # For the representative period winter
            FixedProfile(0.2),                         # For the representative period remaining (of the year)
        ]

        # Calculate conversion value for heat pump
        CelsiusToKelvin = x -> x + 273              # Conversion function for temperature from Celsius to Kelvin
        T_hot = CelsiusToKelvin(60)                 # Condensation temperature (indoor)
        T_cold = CelsiusToKelvin(10)                # Evaporation temperature (outdoor)
        COP_Carnot = T_hot / (T_hot - T_cold)       # Find the coefficient of performance
        efficiency = 0.5                            # Efficiency compared with an ideal heat pump
        conversion = COP_Carnot * efficiency        # Conversion factor

        heatpump_output_capacity = 1                # Set the maximum amount of heat the heat pump can produce
        cap = heatpump_output_capacity / conversion # heat pump capacity usage cap

        # Construct nodes
        el_busbar_11125 = GeoAvailability(
            "El busbar_11125",                # Node id
            products[1:2],                     # Resources available at the busbar
        )
        el_1 = RefSink(
            "El 1",                           # Node id
            StrategicProfile(El_1_demand),    # cap: the demand
            Dict(                             # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),  # Penalty for surplus
                :deficit => FixedProfile(1e5), # Penalty for deficit
            ),
            Dict(Power => 1),                  # input `Resource`s with conversion value `Real`
        )
        heat_generator = RefNetworkNode(
            "Heat generator",       # Node id
            FixedProfile(10),       # cap: Installed capacity
            FixedProfile(0.0),      # opex_var: variational operational vost per energy unit produced
            FixedProfile(0),        # opex_fixed: is the fixed operational costs
            Dict(Power => 1),       # input: input `Resource`s with conversion value `Real`
            Dict(Heat => 1),        # output: generated `Resource`s with conversion value `Real`
            [],
        )
        water_heater = RefNetworkNode(
            "Water heater",         # Node id
            FixedProfile(10),       # cap: Installed capacity
            FixedProfile(0.0),      # opex_var: variational operational vost per energy unit produced
            FixedProfile(0),        # opex_fixed: is the fixed operational costs
            Dict(Power => 1),       # input: input `Resource`s with conversion value `Real`
            Dict(WarmWater => 1),   # output: generated `Resource`s with conversion value `Real`
            [],
        )
        heating_1 = RefSink(
            "Heating 1",                        # Node id
            RepresentativeProfile(Heat_demand), # cap: the demand
            Dict(                               # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),    # Penalty for surplus
                :deficit => FixedProfile(1e5),   # Penalty for deficit
            ),
            Dict(Heat => 1),                     # input `Resource`s with conversion value `Real`
        )
        hot_water_1 = RefSink(
            "Hot water 1",                      # Node id
            FixedProfile(0.2),                  # cap: the demand
            Dict(                               # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),    # Penalty for surplus
                :deficit => FixedProfile(1e5),   # Penalty for deficit
            ),
            Dict(WarmWater => 1),                # input `Resource`s with conversion value `Real`
        )
        heat_pump = RefNetworkNode(
            "Heat pump",                            # Node id
            FixedProfile(0),                        # cap: Installed capacity
            FixedProfile(0),                        # opex_var: variational operational vost per energy unit produced
            FixedProfile(0),                        # opex_fixed: is the fixed operational costs
            Dict(Power => 1, Heat => conversion - 1), # input: input `Resource`s with conversion value `Real`
            Dict(Heat => conversion),               # output: generated `Resource`s with conversion value `Real`
            [
                SingleInvData(
                    FixedProfile(1e7 / cap), # Capex [NOK/MW]
                    FixedProfile(cap),     # Max installed capacity [MW]
                    0,                     # initial capacity [MW]
                    BinaryInvestment(
                        FixedProfile(cap), # Investment mode
                    ),
                    RollingLife(
                        FixedProfile(30),  # life_mode: type of handling the lifetime
                    ),
                ),
            ],
        )
        waste_heat_data_center = RefSource( # Must use this instead of the version above to get investments as Operational profile is not implemented for Source when including InvData()
            "Waste heat data center",   # Node id
            FixedProfile(0),            # Cap, installed capacity
            FixedProfile(0),            # Variable operational cost per unit produced
            FixedProfile(0),            # Fixed operational cost per unit produced
            Dict(Heat => 1),            # The generated resources with conversion value 1
            [
                SingleInvData(
                    FixedProfile(0),      # Capex [NOK/MW]
                    FixedProfile(1),      # Max installed capacity [MW]
                    0,                    # initial capacity [MW]
                    BinaryInvestment(
                        FixedProfile(1),  # Investment mode
                    ),
                    RollingLife(
                        FixedProfile(30), # life_mode: type of handling the lifetime
                    ),
                ),
            ],
        )
        DH_Load_points_11171 = RefNetworkNode(
            "DH_Load_points_11171",                            # Node id
            FixedProfile(1e10),                      # cap: Installed capacity
            FixedProfile(0.0),                      # opex_var: variational operational vost per energy unit produced
            FixedProfile(0),                        # opex_fixed: is the fixed operational costs
            Dict(Heat => 1), # input: input `Resource`s with conversion value `Real`
            Dict(Heat => 1, WarmWater => 1),               # output: generated `Resource`s with conversion value `Real`
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
            DH_Load_points_11171,
        ]

        # Create links between nodes
        links = [
            Direct(1, el_busbar_11125, el_1, Linear()),
            Direct(2, el_busbar_11125, heat_generator, Linear()),
            Direct(3, el_busbar_11125, water_heater, Linear()),
            Direct(4, heat_generator, heating_1, Linear()),
            Direct(5, water_heater, hot_water_1, Linear()),
            Direct(6, el_busbar_11125, heat_pump, Linear()),
            Direct(7, heat_pump, heating_1, Linear()),
            Direct(8, waste_heat_data_center, heat_pump, Linear()),
            Direct(9, DH_Load_points_11171, heating_1, Linear()),
            Direct(10, DH_Load_points_11171, hot_water_1, Linear()),
            Direct(11, el_busbar_11125, DH_Load_points_11171, Linear()),
        ]
    elseif a_id == "Area 2"
        # Load the electricity cost from file
        El_cost_file = readlines(inputFolder * raw"/el cost.dat")
        El_cost = [parse(Float64, line) for line ∈ El_cost_file] # In NOK/MWh

        # Load the power supply capacity from file
        max_outtake_file = readlines(inputFolder * raw"/10.dat")
        max_outtake = [parse(Float64, line) for line ∈ max_outtake_file] # In MW
        max_outtake_sc = [
            ScenarioProfile([
                OperationalProfile(max_outtake * El_cap_sc) for El_cap_sc ∈ El_cap_scenario
            ]) for sp ∈ 1:(T.len)
        ]
        if with_scenarios
            cap = StrategicProfile(max_outtake_sc) # Cap, installed capacity
        else
            cap = OperationalProfile(max_outtake)  # Cap, installed capacity
        end

        # Construct nodes
        el_busbar_11124 = GeoAvailability(
            "El busbar_11124",                  # Node id
            products[1:2],                      # Resources available at the busbar
        )
        power_supply = RefSource(
            "Power supply",                     # Node id
            cap,                                # Cap, installed capacity
            OperationalProfile(El_cost),        # Variable operational cost per unit produced
            FixedProfile(0),                    # Fixed operational cost per unit produced
            Dict(Power => 1),                   # The generated resources with conversion value 1
        )
        waste_supply = RefSource(
            "Waste supply",                     # Node id
            FixedProfile(100),                  # Cap, installed capacity
            FixedProfile(1),                    # Variable operational cost per unit produced
            FixedProfile(0),                    # Fixed operational cost per unit produced
            Dict(Waste => 1),                   # The generated resources with conversion value 1
        )
        rated_capacity_chp = 10
        chp_Plant = RefNetworkNode(
            "CHP Plant",                        # Node id
            FixedProfile(rated_capacity_chp),   # cap: Installed capacity
            FixedProfile(0),                    # opex_var: variational operational vost per energy unit produced
            FixedProfile(0),                    # opex_fixed: is the fixed operational costs
            Dict(Waste => 1),                   # input: input `Resource`s with conversion value `Real`
            Dict(Heat => 1),                    # output: generated `Resource`s with conversion value `Real`
            [
                SingleInvData(
                    FixedProfile(1e8 / rated_capacity_chp), # Capex [NOK/MW]
                    FixedProfile(rated_capacity_chp),     # Max installed capacity [MW]
                    0,                     # initial capacity [MW]
                    BinaryInvestment(
                        FixedProfile(rated_capacity_chp), # Investment mode
                    ),
                    RollingLife(
                        FixedProfile(30),  # life_mode: type of handling the lifetime
                    ),
                ),
                EmissionsProcess(Dict(CO₂ => 0.207, NOx => 0.000092, CO => 0.000037)), # t/MWh
            ],
        )
        heat_central = RefNetworkNode(
            "Heat central",              # Node id
            FixedProfile(20),            # cap: Installed capacity
            FixedProfile(0.0),           # opex_var: variational operational vost per energy unit produced
            FixedProfile(0),             # opex_fixed: is the fixed operational costs
            Dict(Power => 1, Heat => 1), # input: input `Resource`s with conversion value `Real`
            Dict(Heat => 1.5),           # output: generated `Resource`s with conversion value `Real`
            [],
        )
        av = GenAvailability(
            "El busbar_1",                  # Node id
            [Power],                        # Resources available at the busbar
        )
        nodes = [el_busbar_11124, power_supply, waste_supply, chp_Plant, heat_central, av]
        #nodes = [el_busbar_11124, power_supply]

        # Create links between nodes
        links = [
            Direct("Link from power supply", power_supply, el_busbar_11124, Linear()),
            Direct("Link from Waste supply", waste_supply, chp_Plant, Linear()),
            Direct("Link from CHP Plant", chp_Plant, heat_central, Linear()),
            Direct("Link to Heat central", av, heat_central, Linear()),
            Direct("Link from Heat central", heat_central, el_busbar_11124, Linear()),
            Direct("Busbar link", el_busbar_11124, av, Linear()),
        ]
    elseif a_id == "Area 3"
        # Load the demand profile from file
        EV_charger_demand_file = readlines(inputFolder * raw"/charging.dat")
        EV_charger_demand_day = [parse(Float64, line) for line ∈ EV_charger_demand_file] # In MWh/h
        # Since the EV_charger is introduced in 2030, the El_change_factor is shifted such that
        # the initial profile is not scaled (starting at the second strategic period)
        EV_charger_change_factors = [1, El_change_factor[3] / El_change_factor[2]]
        EV_charger_demand = [
            if i == 1
                OperationalProfile(0.0 * ones(24))
            else
                OperationalProfile(
                    EV_charger_demand_day * EV_charger_change_factors[i - 1]
                )
            end for i ∈ 1:(T.len)
        ] # Make EV charger available from 2030 (that is FixedProfile in the first strategic period 2022 -- 2030)

        # Construct nodes
        el_busbar_11137 = GeoAvailability(
            "El busbar_11137", # Node id
            products[1:1],      # Resources available at the busbar
        )
        ev_charger = RefSink(
            "EV charger",                           # Node id
            StrategicProfile(EV_charger_demand),    # cap: the demand
            Dict(                                   # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),        # Penalty for surplus
                :deficit => FixedProfile(1e5),       # Penalty for deficit
            ),
            Dict(Power => 1),                        # input `Resource`s with conversion value `Real`
        )
        nodes = [el_busbar_11137, ev_charger]

        # Create links between nodes
        links = [Direct("Link to EV charger", el_busbar_11137, ev_charger, Linear())]
    elseif a_id == "Area 4"
        # Load the solar supply capacity from file
        max_outtake_file = readlines(inputFolder * raw"/solar.dat")
        max_outtake_day = [parse(Float64, line) for line ∈ max_outtake_file] # In MW
        max_max_outtake = maximum(max_outtake_day)
        profile = max_outtake_day / max_max_outtake

        # Construct nodes
        el_busbar_11149 = GeoAvailability(
            "El busbar_11149",                  # Node id
            products[1:1],                       # Resources available at the busbar
        )
        solar_Power = NonDisRES(
            "Solar Power",                  # id: Node id
            FixedProfile(0),                # cap: the installed capacity in MW
            OperationalProfile(profile),    # profile: the power production in each operational period as a ratio of the installed capacity at that time
            FixedProfile(0),                # opex_var: Variable operational cost per unit produced
            FixedProfile(0),                # opex_fixed: Fixed operational cost per unit produced
            Dict(Power => 1),               # output: The generated resources with conversion value 1
            [
                SingleInvData(
                    FixedProfile(5e8 / max_max_outtake), # Capex [NOK/MW]
                    FixedProfile(max_max_outtake),     # Max installed capacity [MW]
                    0,                                 # initial capacity [MW]
                    BinaryInvestment(
                        FixedProfile(max_max_outtake), # Investment mode
                    ),
                    RollingLife(FixedProfile(30)),  # Lifetime mode
                ),
            ],
        )
        battery = RefStorage{CyclicStrategic}(
            "Battery",               # Node id
            StorCapOpex(
                FixedProfile(100),   # Charge capacity in Wh/h
                FixedProfile(0),     # Storage variable OPEX for the charging in NOK/Wh
                FixedProfile(0),     # Storage fixed OPEX for the charging in NOK/Wh
            ),
            StorCap(
                FixedProfile(0),     # Storage capacity in Wh
            ),
            Power,                   # Stored resource
            Dict(Power => 1),        # Input resource with input ratio
            Dict(Power => 0.9),      # Output from the node with output ratio
            [
                StorageInvData(
                    level=NoStartInvData(
                        FixedProfile(0),             # capex: capital costs [NOK/MW]
                        FixedProfile(100),           # max_inst: maximum installed capacity
                        BinaryInvestment(
                            FixedProfile(100),       # inv_mode: chosen investment mode
                        ),
                        RollingLife(
                            FixedProfile(30), # life_mode: type of handling the lifetime
                        ),
                    ),
                ),
            ],
        )
        nodes = [el_busbar_11149, solar_Power, battery]

        # Create links between nodes
        links = [
            Direct("Link to solar power", solar_Power, el_busbar_11149, Linear())
            Direct("Link to Battery", el_busbar_11149, battery, Linear())
            Direct("Link from Battery", battery, el_busbar_11149, Linear())
        ]
    elseif a_id == "Area 5"
        # Construct nodes
        DH_Junction_points_11165 = GeoAvailability(
            "DH_Junction_points_11165",         # Node id
            products[2:2],                       # Resources available at the Junction
        )
        nodes = [DH_Junction_points_11165]
        links = []
    elseif a_id == "Area 6"
        # Construct nodes
        DH_Junction_points_11167 = GeoAvailability(
            "DH_Junction_points_11167",         # Node id
            products[2:2],                       # Resources available at the Junction
        )
        nodes = [DH_Junction_points_11167]
        links = []
    elseif a_id == "Area 7"
        # Construct nodes
        DH_Junction_points_11169 = GeoAvailability(
            "DH_Junction_points_11169",         # Node id
            products[2:2],                       # Resources available at the Junction
        )
        nodes = [DH_Junction_points_11169]
        links = []
    elseif a_id == "Area 8"
        # Create heat demand profiles
        Heat_load_coefficient = 10
        Heat_demand_repr = RepresentativeProfile([
            FixedProfile(0.2 * Heat_load_coefficient), # For the representative period winter
            FixedProfile(0.2),                       # For the representative period remaining (of the year)
        ])
        Heat_demand = [FixedProfile(0.0), Heat_demand_repr, Heat_demand_repr] # Available only from 2030
        # Construct nodes
        DH_Junction_points_11173 = GeoAvailability(
            "DH_Junction_points_11173",         # Node id
            products[2:2],                       # Resources available at the Junction
        )
        heat_for_ports_and_ships = RefSink(
            "Heat for port and ships",                        # Node id
            StrategicProfile(Heat_demand), # cap: the demand
            Dict(                               # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),    # Penalty for surplus
                :deficit => FixedProfile(1e5),   # Penalty for deficit
            ),
            Dict(Heat => 1),                     # input `Resource`s with conversion value `Real`
        )
        nodes = [DH_Junction_points_11173, heat_for_ports_and_ships]
        links = [
            Direct(
                "Link to heat for ports and ships",
                DH_Junction_points_11173,
                heat_for_ports_and_ships,
                Linear(),
            ),
        ]
    elseif a_id == "Area 9"
        Heat_load_coefficient = 10
        Heat_demand_repr = RepresentativeProfile([
            FixedProfile(0.2 * Heat_load_coefficient), # For the representative period winter
            FixedProfile(0.2),                       # For the representative period remaining (of the year)
        ])
        Heat_demand = [FixedProfile(0.0), Heat_demand_repr, Heat_demand_repr] # Available only from 2030
        # Construct nodes
        DH_Junction_points_11177 = GeoAvailability(
            "DH_Junction_points_11177",         # Node id
            products[2:2],                       # Resources available at the Junction
        )
        heat_for_airport = RefSink(
            "Heat for airport",                        # Node id
            StrategicProfile(Heat_demand), # cap: the demand
            Dict(                               # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),    # Penalty for surplus
                :deficit => FixedProfile(1e5),   # Penalty for deficit
            ),
            Dict(Heat => 1),                     # input `Resource`s with conversion value `Real`
        )
        nodes = [DH_Junction_points_11177, heat_for_airport]
        links = [
            Direct(
                "Link to heat for airport",
                DH_Junction_points_11177,
                heat_for_airport,
                Linear(),
            ),
        ]
    end
    return nodes, links
end

# Get case and model data
case, model = read_data()

# Construct JuMP model for optimization
m = EMG.create_model(case, model)

# Set optimizer for JuMP
set_optimizer(m, HiGHS.Optimizer)

# Solve the optimization problem
optimize!(m)

# Print solution summary
solution_summary(m)

## Plot topology and results in GUI

# Set folder where visualization info is saved and retrieved
path = joinpath(@__DIR__, "design", case_name) # folder where visualization info is saved and retrieved
path_to_results = joinpath(@__DIR__, "exported_files", case_name) # folder where visualization info is saved and retrieved

# Run the GUI
gui = GUI(
    case;
    design_path=path,
    model=m,
    periods_labels=["2022 - 2030", "2030 - 2040", "2040 - 2050"],
    representative_periods_labels=["Winter", "Remaining"],
    expand_all=true,
    path_to_results=path_to_results,
    case_name=case_name,
    scale_tot_opex=false,
    scale_tot_capex=true,
)
