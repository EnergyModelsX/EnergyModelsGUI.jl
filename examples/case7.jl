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
case_name = "case7"

function read_data()
    @info "Setting up $case_name"

    # Define the different resources and their emission intensity in tCO2/MWh
    Power = ResourceCarrier("Power", 0.0)
    Heat = ResourceCarrier("Heat", 0.0)
    WarmWater = ResourceCarrier("WarmWater", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [Power, Heat, WarmWater, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 1  # Each operational period has a duration of one hour
    op_number = 24   # There are in total 24 operational periods (one for each hour in a day)

    operational_periods = SimpleTimes(op_number, op_duration)
    no_days_in_year = 365
    no_segments = 2
    no_hours_in_year = 24 * no_days_in_year
    representative_periods = RepresentativePeriods(
        no_segments,
        no_hours_in_year,
        [100, 265] / no_days_in_year,
        fill(operational_periods, no_segments),
    )

    # Creation of the time structure
    dur = [8, 10, 10]          # duration of the three strategic period 2022--2029, 2030--2039, 2040--2049

    T = TwoLevel(dur, representative_periods; op_per_strat = 8760)

    noSP = length(dur)     # Number of strategic periods

    # Create operational model (global data)
    em_limits = Dict(CO2 => StrategicProfile(0.0 * ones(noSP)))   # Emission cap for CO2 in t/year
    em_cost = Dict(CO2 => FixedProfile(0))  # Emission price for CO2 in NOK/t
    discount_rate = 0.05 # discount rate in the investment optimization
    model = InvestmentModel(em_limits, em_cost, CO2, discount_rate)

    # Create input data for the areas
    area_ids = ["Area 1", "Area 2", "Area 3", "Area 4"]
    noAreas = length(area_ids) # Number of areas

    # Create identical areas with index accoriding to input array
    an = Vector(undef, noAreas)
    nodes = []
    links = []
    for (i, a_id) ∈ enumerate(area_ids)
        n, l = get_sub_system_data(a_id, products, T)
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[i] = n[1]
    end

    # Set coordinates of the areas
    coordinates = [[-92, 40], [-93, 40], [-92, 38], [-93, 41]]
    lon = [xy[1] for xy ∈ coordinates]
    lat = [xy[2] for xy ∈ coordinates]

    # Create the individual areas and transmission modes
    areas = [RefArea(i, area_ids[i], lon[i], lat[i], an[i]) for i ∈ eachindex(area_ids)]

    # Set parameters for the power line
    capacity, lossRatio = get_cable_data()
    trans_cap = StrategicProfile(capacity * [1, 1, 0]) # Decomission the powerline in 2040
    trans_cap2 = FixedProfile(capacity)
    trans_cap3 = StrategicProfile(capacity * [0, 0, 1]) # Try to resolve the decomissioning with a Solar+Battery system in Area 4
    loss = FixedProfile(lossRatio)
    opex_var = FixedProfile(0.0) # No variable cost in operating the power line
    opex_fix = FixedProfile(0.0) # No fixed cost in operating the power line
    direction = 2 # Power flow direction can go two ways

    # Create a power line between the busbars
    Power_line = RefStatic(
        "El power line_11126", Power, trans_cap, loss, opex_var, opex_fix, direction, [],
    )
    Power_line2 = RefStatic(
        "El power line_11139", Power, trans_cap2, loss, opex_var, opex_fix, direction,
        [],
    )
    Power_line3 = RefStatic(
        "El power line_11139", Power, trans_cap3, loss, opex_var, opex_fix, direction,
        [],
    )

    # Construct the transmission object
    transmission = [
        Transmission(areas[2], areas[1], [Power_line])
        Transmission(areas[2], areas[3], [Power_line2])
        Transmission(areas[4], areas[1], [Power_line3])
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
function get_sub_system_data(a_id, products, T)
    Power = products[1]
    Heat = products[2]
    WarmWater = products[3]
    El_change_factor = [1, 2, 4] # Alter the electricity change factor. This scales the demand for electricity by a factor 2 for 2030--2039 and a factor 4 for 2040--2049
    inputFolder = joinpath(@__DIR__, "Inputfiles")
    if a_id == "Area 1"
        # Load the demand profile from file
        El_1_demand_file = readlines(inputFolder * raw"/el load.dat")
        El_1_demand_day = [parse(Float64, line) for line ∈ El_1_demand_file] # In MWh/h
        El_1_demand = [
            OperationalProfile(El_1_demand_day * El_change_factor[i]) for i ∈ 1:(T.len)
        ]

        # Create heat and warm water demand profiles
        Heat_load_coefficient = 10
        Heat_demand = [
            FixedProfile(0.2 * Heat_load_coefficient), # For the representative period winter
            FixedProfile(0.2),                       # For the representative period remaining (of the year)
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
            products[1:1],                     # Resources available at the busbar
        )
        el_1 = RefSink(
            "El 1",                           # Node id
            StrategicProfile(El_1_demand),    # cap: the demand
            Dict(                             # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),  # Penalty for surplus
                :deficit => FixedProfile(1e5) # Penalty for deficit
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
            Dict(                               # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),    # Penalty for surplus
                :deficit => FixedProfile(1e5)   # Penalty for deficit
            ),
            Dict(Heat => 1),                     # input `Resource`s with conversion value `Real`
        )
        hot_water_1 = RefSink(
            "Hot water 1",                      # Node id
            FixedProfile(0.2),                  # cap: the demand
            Dict(                               # penality: penalties for surplus or deficits
                :surplus => FixedProfile(0),    # Penalty for surplus
                :deficit => FixedProfile(1e5)   # Penalty for deficit
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
                    FixedProfile(cap),       # Max installed capacity [MW]
                    BinaryInvestment(
                        FixedProfile(cap)   # Investment mode
                    ),
                    RollingLife(
                        FixedProfile(30)    # life_mode: type of handling the lifetime
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
                    BinaryInvestment(
                        FixedProfile(1)  # Investment mode
                    ),
                    RollingLife(
                        FixedProfile(30) # life_mode: type of handling the lifetime
                    ),
                ),
            ],
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
            Direct(1, el_busbar_11125, el_1, Linear()),
            Direct(2, el_busbar_11125, heat_generator, Linear()),
            Direct(3, el_busbar_11125, water_heater, Linear()),
            Direct(4, heat_generator, heating_1, Linear()),
            Direct(5, water_heater, hot_water_1, Linear()),
            Direct(6, el_busbar_11125, heat_pump, Linear()),
            Direct(7, heat_pump, heating_1, Linear()),
            Direct(8, waste_heat_data_center, heat_pump, Linear()),
        ]
    elseif a_id == "Area 2"
        # Load the electricity cost from file
        El_cost_file = readlines(inputFolder * raw"/el cost.dat")
        El_cost = [parse(Float64, line) for line ∈ El_cost_file] # In NOK/MWh

        # Load the power supply capacity from file
        max_outtake_file = readlines(inputFolder * raw"/10.dat")
        max_outtake = [parse(Float64, line) for line ∈ max_outtake_file] # In MW
        max_waste_outtake = [
            i > 1 ? FixedProfile(0.0) : FixedProfile(0.0) for i ∈ 1:(T.len)
        ] # Make Waste supply available only from 2030

        # Construct nodes
        el_busbar_11124 = GeoAvailability(
            "El busbar_11124",                  # Node id
            products[1:1],                       # Resources available at the busbar
        )
        power_supply = RefSource(
            "Power supply",                     # Node id
            OperationalProfile(max_outtake),    # Cap, installed capacity
            OperationalProfile(El_cost),        # Variable operational cost per unit produced
            FixedProfile(0),                    # Fixed operational cost per unit produced
            Dict(Power => 1),                   # The generated resources with conversion value 1
        )
        nodes = [el_busbar_11124, power_supply]

        # Create links between nodes
        links = [Direct("Link from power supply", power_supply, el_busbar_11124, Linear())]
    elseif a_id == "Area 3"
        # Load the demand profile from file
        EV_charger_demand_file = readlines(inputFolder * raw"/charging.dat")
        EV_charger_demand_day = [parse(Float64, line) for line ∈ EV_charger_demand_file] # In MWh/h
        EV_charger_change_factors = [1, El_change_factor[3] / El_change_factor[2]] # Since the EV_charger is introduced in 2030, the El_change_factor is shifted such that the initial profile is not scaled (starting at the second strategic period) # Since the EV_charger is introduced in 2030, the El_change_factor is shifted such that the initial profile is not scaled (starting at the second strategic period)
        EV_charger_demand = [
            if i == 1
                OperationalProfile(0.0 * ones(24))
            else
                OperationalProfile(
                    EV_charger_demand_day * EV_charger_change_factors[i-1],
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
                :deficit => FixedProfile(1e5)       # Penalty for deficit
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
                    BinaryInvestment(
                        FixedProfile(max_max_outtake) # Investment mode
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
                FixedProfile(0)     # Storage fixed OPEX for the charging in NOK/Wh
            ),
            StorCap(
                FixedProfile(0)     # Storage capacity in Wh
            ),
            Power,                   # Stored resource
            Dict(Power => 1),        # Input resource with input ratio
            Dict(Power => 0.9),      # Output from the node with output ratio
            [
                StorageInvData(
                    level = NoStartInvData(
                        FixedProfile(0),             # capex: capital costs [NOK/MW]
                        FixedProfile(100),           # max_inst: maximum installed capacity
                        BinaryInvestment(
                            FixedProfile(100)       # inv_mode: chosen investment mode
                        ),
                        RollingLife(
                            FixedProfile(30) # life_mode: type of handling the lifetime
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
    end
    return nodes, links
end

function run_case()
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
        design_path = path,
        model = m,
        periods_labels = ["2022 - 2030", "2030 - 2040", "2040 - 2050"],
        representative_periods_labels = ["Winter", "Remaining"],
        expand_all = true,
        path_to_results = path_to_results,
        case_name = case_name,
        scale_tot_opex = false,
        scale_tot_capex = true,
    )

    return case, model, m, gui
end
