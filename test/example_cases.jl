# Case builders used by the tests, based on the examples of other EMX packages:
# - `generate_example_network`: `examples/network.jl` of EnergyModelsBase
# - `generate_example_ss`: `examples/sink_source.jl` of EnergyModelsBase
# - `generate_example_geo_investment`: `examples/investments.jl` of EnergyModelsGeography
# - `generate_example_hp`: `examples/simple_hydro_power.jl` of EnergyModelsRenewableProducers

"""
    generate_example_network()

Generate the data for an example consisting of a simple electricity network.
The more stringent CO₂ emission in latter investment periods force the utilization of the
more expensive natural gas power plant with CCS to reduce emissions.
"""
function generate_example_network()
    @info "Generate case data - Simple network example"

    # Define the different resources and their emission intensity in tCO2/MWh
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [NG, Coal, Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods, which
    # can also be extracted using the function `duration` of a `SimpleTimes` structure.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = op_duration * op_number

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(   # Emission cap for CO₂ in t/8h and for NG in MWh/8h
            CO2 => StrategicProfile([160, 140, 120, 100]),
            NG => FixedProfile(1e6),
        ),
        Dict(   # Emission price for CO₂ in EUR/t and for NG in EUR/MWh
            CO2 => FixedProfile(0),
            NG => FixedProfile(0),
        ),
        CO2,    # CO2 instance
    )

    # Creation of the emission data for the individual nodes.
    capture_data = CaptureEnergyEmissions(0.9)
    emission_data = EmissionsEnergy()

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO₂ storage.
    nodes = [
        GenAvailability("Availability", products),
        RefSource(
            "NG source",                # Node id
            FixedProfile(100),          # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/MW/8h
            Dict(NG => 1),              # Output from the Node, in this case, NG
        ),
        RefSource(
            "coal source",              # Node id
            FixedProfile(100),          # Capacity in MW
            FixedProfile(9),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/8h
            Dict(Coal => 1),            # Output from the Node, in this case, coal
        ),
        RefNetworkNode(
            "NG+CCS power plant",       # Node id
            FixedProfile(25),           # Capacity in MW
            FixedProfile(5.5),          # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/8h
            Dict(NG => 2),              # Input to the node with input ratio
            Dict(Power => 1, CO2 => 1), # Output from the node with output ratio
            # Line above: CO2 is required as output for variable definition, but the
            # value does not matter
            [capture_data],             # Additonal data for emissions and CO₂ capture
        ),
        RefNetworkNode(
            "coal power plant",         # Node id
            FixedProfile(25),           # Capacity in MW
            FixedProfile(6),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/8h
            Dict(Coal => 2.5),          # Input to the node with input ratio
            Dict(Power => 1),           # Output from the node with output ratio
            [emission_data],            # Additonal data for emissions
        ),
        RefStorage{AccumulatingEmissions}(
            "CO2 storage",              # Node id
            StorCapOpex(
                FixedProfile(60),       # Charge capacity in t/h
                FixedProfile(9.1),      # Storage variable OPEX for the charging in EUR/t
                FixedProfile(0)         # Storage fixed OPEX for the charging in EUR/(t/h 8h)
            ),
            StorCap(FixedProfile(600)), # Storage capacity in t
            CO2,                        # Stored resource
            Dict(CO2 => 1, Power => 0.02), # Input resource with input ratio
            # Line above: This implies that storing CO₂ requires Power
            Dict(CO2 => 1),             # Output from the node with output ratio
            # In practice, for CO₂ storage, this is never used.
        ),
        RefSink(
            "electricity demand",       # Node id
            OperationalProfile([20, 30, 40, 30]), # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(Power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
        Direct("Av-NG_pp", nodes[1], nodes[4], Linear())
        Direct("Av-coal_pp", nodes[1], nodes[5], Linear())
        Direct("Av-CO2_stor", nodes[1], nodes[6], Linear())
        Direct("Av-demand", nodes[1], nodes[7], Linear())
        Direct("NG_src-av", nodes[2], nodes[1], Linear())
        Direct("Coal_src-av", nodes[3], nodes[1], Linear())
        Direct("NG_pp-av", nodes[4], nodes[1], Linear())
        Direct("Coal_pp-av", nodes[5], nodes[1], Linear())
        Direct("CO2_stor-av", nodes[6], nodes[1], Linear())
    ]

    # Input data structure
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])
    return case, model
end

"""
    generate_example_ss()

Generate the data for an example consisting of an electricity source and sink. It shows how
the source adjusts to the demand.
"""
function generate_example_ss()
    @info "Generate case data - Simple sink-source example"

    # Define the different resources and their emission intensity in tCO2/MWh
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods, which
    # can also be extracted using the function `duration` of a `SimpleTimes` structure.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = op_duration * op_number

    # Creation of the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO₂ in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        CO2,                            # CO₂ instance
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    nodes = [
        RefSource(
            "electricity source",       # Node id
            FixedProfile(50),           # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/MW/8h
            Dict(Power => 1),           # Output from the Node, in this case, Power
        ),
        RefSink(
            "electricity demand",       # Node id
            OperationalProfile([20, 30, 40, 30]), # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(Power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
        Direct("source-demand", nodes[1], nodes[2], Linear()),
    ]

    # Input data structure
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])
    return case, model
end

"""
    generate_example_geo_investment()

Generate the data for an example consisting of a simple electricity and CO₂ network. It is
loosely adapted from the `network.jl` example of `EnergyModelsBase`:
https://github.com/EnergyModelsX/EnergyModelsBase.jl/blob/main/examples/network.jl

The example consists of two areas, a coal area with a coal power plant, a flat electricity
demand, and a CO₂ storage site, and a natural gas area with a natural gas power plant with
CCS and a variable electricity demand. The latter has lower deficit costs if not sufficient
electricity is delivered.

There is initially no transmission capacity between both areas, neither for electricity, nor
for CO₂. As a consequence, exchange of energy or mass requires investing into transmission
capacity.
"""
function generate_example_geo_investment()
    @info "Generate case data - Simple geographic example with investments"

    # Define the different resources and their emission intensity in t CO₂/MWh
    ng = ResourceCarrier("NG", 0.2)
    coal = ResourceCarrier("Coal", 0.35)
    power = ResourceCarrier("Power", 0.0)
    co2 = ResourceEmit("CO₂", 1.0)
    𝒫 = [ng, coal, power, co2]

    # Variables for the individual entries of the time structure
    op_duration = 4 # Each operational period has a duration of 4 (hours)
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # Each operational period should correspond to a duration of 4 h while a duration if 1
    # of a strategic period should correspond to a year.
    # This implies, that a strategic period is 8760 times longer than an operational period,
    # resulting in the values below as "/year".
    op_per_strat = 8760

    # Creation of the time structure and global data
    𝒯 = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = InvestmentModel(
        Dict(co2 => StrategicProfile([200, 100] .* 500)), # CO₂ emission cap in t/year
        Dict(co2 => FixedProfile(0)),               # CO₂ emission cost in EUR/t
        co2,                                        # CO₂ instance
        0.07,                                       # Discount rate in absolute value
    )

    ## Create the first area: It consists of a coal sources, a coal power plant, an
    ## electricity demand with a fixed profile, and a CO₂ storage site
    # Create the nodes
    𝒩₁ = [
        GeoAvailability("Reg_1-Availability", 𝒫),
        RefSource(
            "Reg_1-Coal_source",        # Node id
            FixedProfile(100),          # Capacity in MW
            FixedProfile(9),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(coal => 1),            # Output from the Node, in this case, coal
        ),
        RefNetworkNode(
            "Reg_1-Coal_power_plant",   # Node id
            FixedProfile(25),           # Capacity in MW
            FixedProfile(6),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(coal => 2.5),          # Input to the node with input ratio
            Dict(power => 1),           # Output from the node with output ratio
            [EmissionsEnergy()],        # Additional data for emissions
            # Line above: `EmissionsEnergy` implies that the emissions data corresponds to
            # emissions through fuel usage as calculated by the CO₂ intensity and efficiency.
        ),
        RefStorage{AccumulatingEmissions}(
            "Reg_1-CO2_storage",        # Node id
            StorCapOpex(
                FixedProfile(60),       # Charge capacity in t/h
                FixedProfile(9.1),      # Storage variable OPEX for the charging in EUR/t
                FixedProfile(0)         # Storage fixed OPEX for the charging in EUR/(t/h year)
            ),
            StorCap(FixedProfile(600)), # Storage capacity in t
            co2,                        # Stored resource
            Dict(co2 => 1, power => 0.02), # Input resource with input ratio
            # Line above: This implies that storing CO₂ requires power
            Dict(co2 => 1),             # Output from the node with output ratio
            # Line above: In the case of `AccumulatingEmissions`, you must provide the
            # stored resource as one of the keys. Its value does however not matter as the
            # outlet flow value is fixed to 0.
        ),
        RefSink(
            "Reg_1-Electricity_demand", # Node id
            FixedProfile(10),           # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e3)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    # NOTE: This hard coding based on indexing is error prone. It is in general advised to
    #       use a mapping dictionary to avoid any problems when introducing new technology
    #       nodes.
    ℒ₁ = [
        Direct("Reg_1-av-coal_pp", 𝒩₁[1], 𝒩₁[3], Linear())
        Direct("Reg_1-av-CO2_stor", 𝒩₁[1], 𝒩₁[4], Linear())
        Direct("Reg_1-av-demand", 𝒩₁[1], 𝒩₁[5], Linear())
        Direct("Reg_1-coal_src-av", 𝒩₁[2], 𝒩₁[1], Linear())
        Direct("Reg_1-coal_pp-av", 𝒩₁[3], 𝒩₁[1], Linear())
    ]

    # Create the area
    area_1 = RefArea(1, "Coal area", 6.62, 51.04, 𝒩₁[1])

    ## Create the second area: It consists of a natural gas sources, a natrual gas power
    ## plant with CCS, and an electricity demand with a variable profile
    # Create the nodes
    𝒩₂ = [
        GeoAvailability("Reg_2-Availability", 𝒫),
        RefSource(
            "Reg_2-NG_source",          # Node id
            FixedProfile(200),          # Capacity in MW
            FixedProfile(30),           # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(ng => 1),              # Output from the Node, in this case, ng
        ),
        RefNetworkNode(
            "Reg_2-ng+CCS_power_plant", # Node id
            StrategicProfile([25, 50]), # Capacity in MW
            FixedProfile(5.5),          # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(ng => 2),              # Input to the node with input ratio
            Dict(power => 1, co2 => 0), # Output from the node with output ratio
            # Line above: `co2` is required as output for variable definition, but the
            # value does not matter as it is not utilized in the model.
            [CaptureEnergyEmissions(0.9)],  # Additional data for emissions and CO₂ capture
            # Line above: `CaptureEnergyEmissions` implies that the emissions data corresponds
            # to emissions through fuel usage as calculated by the CO₂ intensity and efficiency.
            # 90 % of the CO₂ emissions are captured as given by the value 0.9.
        ),
        RefSink(
            "Reg_2-Electricity_demand", # Node id
            OperationalProfile([10, 20, 30, 20]),   # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(5e2)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    # NOTE: This hard coding based on indexing is error prone. It is in general advised to
    #       use a mapping dictionary to avoid any problems when introducing new technology
    #       nodes.
    ℒ₂ = [
        Direct("Reg_2-av-NG_pp", 𝒩₂[1], 𝒩₂[3], Linear())
        Direct("Reg_2-av-demand", 𝒩₂[1], 𝒩₂[4], Linear())
        Direct("Reg_2-NG_src-av", 𝒩₂[2], 𝒩₂[1], Linear())
        Direct("Reg_2-NG_pp-av", 𝒩₂[3], 𝒩₂[1], Linear())
    ]

    # Create the area
    area_2 = RefArea(2, "Natural gas area", 6.83, 53.45, 𝒩₂[1])

    # Merge the data into single vectors
    𝒩 = vcat(𝒩₁, 𝒩₂)
    ℒ = vcat(ℒ₁, ℒ₂)
    𝒜 = [area_1, area_2]

    # Create the transmission modes for transporting power and CO₂ between the areas
    power_inv_data = SingleInvData(
        FixedProfile(50 * 1e3), # CAPEX in EUR/MW
        FixedProfile(10),       # Max installed capacity [MW]
        ContinuousInvestment(FixedProfile(0), FixedProfile(10)),
        # Line above: Investment mode with the following arguments:
        # 1. argument: min added capactity per investment period [MW]
        # 2. argument: max added capactity per investment period [MW]
    )
    power_line = RefStatic(
        "power_line",           # ID of the transmission mode
        power,                  # Transported resource
        FixedProfile(0),        # Capacity in MW
        FixedProfile(0.02),     # Relative loss as fraction of the transported energy
        FixedProfile(0),        # Variable OPEX in EUR/MWh
        FixedProfile(0),        # Fixed OPEX in EUR/MW/year
        2,                      # Directions of transport, in this case, bidirectional
        [power_inv_data],
    )
    co2_pipe_inv_data = SingleInvData(
        FixedProfile(260 * 1e3),  # CAPEX in EUR/(t/h)
        FixedProfile(40),       # Max installed capacity [t/h]
        SemiContinuousInvestment(FixedProfile(5), FixedProfile(20)),
        # Line above: Investment mode with the following arguments:
        # 1. argument: min added capactity per investment period [t/h]
        # 2. argument: max added capactity per investment period [t/h]
    )
    co2_pipeline = PipeSimple(
        "co2_pipeline",         # ID of the transmission mode
        co2,                    # Resource at the inlet
        co2,                    # Resource at the outlet
        power,                  # Additional required resource for transportation
        FixedProfile(0.01),     # Fraction of `CO₂` required as `power` for transporting the resource in MWh/t
        # Line above: the fraction can be seen as, e.g., pumping or compression requirement
        FixedProfile(0),        # Capacity in t/h
        FixedProfile(0),        # Relative loss as fraction of the transported `CO₂`
        FixedProfile(0),        # Variable OPEX in EUR/t
        FixedProfile(0),        # Fixed OPEX in EUR/(t/h)/year
        [co2_pipe_inv_data],
    )

    # Create the transmission corridor between the two areas
    # Note that the corridor is defined from the natural gas area as pipeline transport is
    # always unidirectional
    ℒᵗʳᵃⁿˢ = [Transmission(𝒜[2], 𝒜[1], [power_line, co2_pipeline])]

    # Input data structure
    # It is also explained on
    # https://energymodelsx.github.io/EnergyModelsBase.jl/stable/library/public/case_element/
    case = Case(
        𝒯,                  # Chosen time structure
        𝒫,                  # Resources used
        [𝒩, ℒ, 𝒜, ℒᵗʳᵃⁿˢ],  # Nodes, Links, Areas, and Transmission corridors used
        [[get_nodes, get_links], [get_areas, get_transmissions]],
        # Line above: the first vector corresponds to the original couplings between `Node`s
        # through `Link`s. The second vector introduces couplings between `Area`s through
        # `Transmission` corridors.
    )
    return case, model
end

"""
    generate_example_data()

Generate the data for an example consisting of a simple electricity network with a
non-dispatchable power source, a regulated hydro power plant, as well as a demand.
It illustrates how the hydro power plant can balance the intermittent renewable power
generation.
"""
function generate_example_hp()
    @info "Generate case data - Simple `HydroStor` example"

    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 1.0)
    products = [CO2, Power]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = op_duration * op_number

    # Create the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )
    # Create the Availability/bus node for the system
    av = GenAvailability(1, products)

    # Create a non-dispatchable renewable energy source
    wind = NonDisRES(
        "wind",             # Node ID
        FixedProfile(2),    # Capacity in MW
        OperationalProfile([0.9, 0.4, 0.1, 0.8]), # Profile
        FixedProfile(5),    # Variable OPEX in EUR/MW
        FixedProfile(10),   # Fixed OPEX in EUR/8h
        Dict(Power => 1),   # Output from the Node, in this gase, Power
    )

    # Create a regulated hydro power plant without storage capacity
    hydro = HydroStor{CyclicStrategic}(
        "hydropower",       # Node ID
        StorCapOpexFixed(FixedProfile(90), FixedProfile(3)),
        # Line above for the storage level:
        #   Argument 1: Storage capacity in MWh
        #   Argument 2: Fixed OPEX in EUR/8h
        StorCapOpexVar(FixedProfile(2.0), FixedProfile(8)),
        # Line above for the discharge rate:
        #   Argument 1: Rate capacity in MW
        #   Argument 2: Variable OPEX in EUR/MWh
        FixedProfile(10),   # Initial storage level in MWh
        FixedProfile(1),    # Inflow to the Node in MW
        FixedProfile(0.0),  # Minimum storage level as fraction
        Power,              # Stored resource
        Dict(Power => 0.9), # Input to the power plant, irrelevant in this case
        Dict(Power => 1),   # Output from the Node, in this gase, Power
    )

    # Create a power demand node
    sink = RefSink(
        "electricity demand",   # Node id
        FixedProfile(2),    # Demand in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(Power => 1),   # Energy demand and corresponding ratio
    )

    # Create the array of ndoes
    nodes = [av, wind, hydro, sink]

    # Connect all nodes with the availability node for the overall energy balance
    links = [
        Direct("wind-av", wind, av),
        Direct("hy-av", hydro, av),
        Direct("av-hy", av, hydro),
        Direct("av-demand", av, sink),
    ]

    # Create the case dictionary
    case = Case(T, products, [nodes, links])

    return case, model
end
