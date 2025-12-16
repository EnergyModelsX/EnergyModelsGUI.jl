using Pkg
# Activate the local environment including EnergyModelsGeography, HiGHS, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMX_TEST") && Pkg.develop(path = joinpath(@__DIR__, ".."))
# Install the dependencies.
Pkg.instantiate()

using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsInvestments
using EnergyModelsRenewableProducers
using TimeStruct
using JuMP
using HiGHS
using PrettyTables

const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography

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
    generate_example_geo()

Generate the data for an example consisting of a simple electricity network. The simple \
network is existing within 5 regions with differing demand. Each region has the same \
technologies.

The example is partly based on the provided example `network.jl` in `EnergyModelsBase`.
"""
function generate_example_geo()
    @info "Generate case data - Simple network example with 5 regions with the same \
    technologies"

    # Retrieve the products
    products = get_resources()
    NG = products[1]
    Power = products[3]
    CO2 = products[4]

    # Variables for the individual entries of the time structure
    op_duration = 1 # Each operational period has a duration of 2
    op_number = 24   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods, which
    # can also be extracted using the function `duration` of a `SimpleTimes` structure.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/24h".
    op_per_strat = op_duration * op_number

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(
            CO2 => StrategicProfile([160, 140, 120, 100]),  # CO₂ emission cap in t/24h
            NG  => FixedProfile(1e6)                       # NG cap in MWh/24h
        ),
        Dict(
            CO2 => FixedProfile(0),                         # CO₂ emission cost in EUR/t
            NG  => FixedProfile(0)                         # NG emission cost in EUR/t
        ),
        CO2,
    )

    # Create input data for the individual areas
    # The input data is based on scaling factors and/or specified demands
    area_ids = [1, 2, 3, 4, 5, 6, 7]
    d_scale  = Dict(1 => 3.0, 2 => 1.5, 3 => 1.0, 4 => 0.5, 5 => 0.5, 6 => 0.0, 7 => 3.0)
    mc_scale = Dict(1 => 2.0, 2 => 2.0, 3 => 1.5, 4 => 0.5, 5 => 0.5, 6 => 0.5, 7 => 3.0)

    op_data = OperationalProfile([
        10,
        10,
        10,
        10,
        35,
        40,
        45,
        45,
        50,
        50,
        60,
        60,
        50,
        45,
        45,
        40,
        35,
        40,
        45,
        40,
        35,
        30,
        30,
        30,
    ])
    tromsø_demand = [op_data;
        op_data;
        op_data;
        op_data
    ]
    demand = Dict(
        1 => false,
        2 => false,
        3 => false,
        4 => tromsø_demand,
        5 => false,
        6 => false,
        7 => false,
    )

    # Create identical areas with index according to the input array
    an    = Dict()
    nodes = EMB.Node[]
    links = Link[]
    for a_id ∈ area_ids
        n, l = get_sub_system_data(
            a_id,
            products;
            mc_scale = mc_scale[a_id],
            d_scale = d_scale[a_id],
            demand = demand[a_id],
        )
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[a_id] = n[1]
    end

    # Create the individual areas
    # The individual fields are:
    #   1. id   - Identifier of the area
    #   2. name - Name of the area
    #   3. lon  - Longitudinal position of the area
    #   4. lon  - Latitudinal position of the area
    #   5. node - Availability node of the area
    areas = [RefArea(1, "Oslo", 10.751, 59.921, an[1]),
        RefArea(2, "Bergen", 5.334, 60.389, an[2]),
        RefArea(3, "Trondheim", 10.398, 63.4366, an[3]),
        RefArea(4, "Tromsø", 18.953, 69.669, an[4]),
        RefArea(5, "Kristiansand", 7.984, 58.146, an[5]),
        RefArea(6, "Sørlige Nordsjø II", 6.836, 57.151, an[6]),
        RefArea(7, "Danmark", 8.614, 56.359, an[7])]

    # Create the individual transmission modes to transport the energy between the
    # individual areass.
    # The individuaal fields are explained below, while the other fields are:
    #   1. Identifier of the transmission mode
    #   2. Transported resource
    #   7. 2 for bidirectional transport, 1 for unidirectional
    #   8. Potential additional data
    cap_ohl = FixedProfile(50.0)    # Capacity of an overhead line in MW
    cap_lng = FixedProfile(100.0)   # Capacity of the LNG transport in MW
    loss = FixedProfile(0.05)       # Relative loss of either transport mode
    opex_var = FixedProfile(0.05)   # Variable OPEX in EUR/MWh
    opex_fix = FixedProfile(0.05)   # Fixed OPEX in EUR/24h

    OB_OverheadLine_50MW  = RefStatic("OB_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    OT_OverheadLine_50MW  = RefStatic("OT_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    OK_OverheadLine_50MW  = RefStatic("OK_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    BT_OverheadLine_50MW  = RefStatic("BT_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    BTN_LNG_Ship_100MW    = RefDynamic("BTN_LNG_100", NG, cap_lng, loss, opex_var, opex_fix, 1)
    BK_OverheadLine_50MW  = RefStatic("BK_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    TTN_OverheadLine_50MW = RefStatic("TTN_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    KS_OverheadLine_50MW  = RefStatic("KS_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    SD_OverheadLine_50MW  = RefStatic("SD_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)

    # Create the different transmission corridors between the individual areas
    transmissions = [
        Transmission(areas[1], areas[2], [OB_OverheadLine_50MW]),
        Transmission(areas[1], areas[3], [OT_OverheadLine_50MW]),
        Transmission(areas[1], areas[5], [OK_OverheadLine_50MW]),
        Transmission(areas[2], areas[3], [BT_OverheadLine_50MW]),
        Transmission(areas[2], areas[4], [BTN_LNG_Ship_100MW]),
        Transmission(areas[2], areas[5], [BK_OverheadLine_50MW]),
        Transmission(areas[3], areas[4], [TTN_OverheadLine_50MW]),
        Transmission(areas[5], areas[6], [KS_OverheadLine_50MW]),
        Transmission(areas[6], areas[7], [SD_OverheadLine_50MW]),
    ]

    # Input data structure
    case = Case(
        T,
        products,
        [nodes, links, areas, transmissions],
        [[get_nodes, get_links], [get_areas, get_transmissions]],
    )
    return case, model
end

function get_resources()

    # Define the different resources
    NG       = ResourceEmit("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0.0)
    CO2      = ResourceEmit("CO2", 1.0)
    products = [NG, Coal, Power, CO2]

    return products
end

# Subsystem test data for geography package. All subsystems are the same, except for the
# profiles
# The subsystem is similar to the subsystem in the `network.jl` example of EnergyModelsBase.
function get_sub_system_data(
    i,
    products;
    mc_scale::Float64 = 1.0,
    d_scale::Float64 = 1.0,
    demand = false,
)
    NG, Coal, Power, CO2 = products

    # Use of standard demand if not provided differently
    d_standard = OperationalProfile([
        20,
        20,
        20,
        20,
        25,
        30,
        35,
        35,
        40,
        40,
        40,
        40,
        40,
        35,
        35,
        30,
        25,
        30,
        35,
        30,
        25,
        20,
        20,
        20,
    ])
    if demand == false
        demand = [d_standard; d_standard; d_standard; d_standard]
        demand *= d_scale
    end

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO₂ storage.
    j = (i - 1) * 100
    nodes = [
        GeoAvailability(j + 1, products),
        RefSource(
            j + 2,                        # Node id
            FixedProfile(1e12),         # Capacity in MW
            FixedProfile(30 * mc_scale),  # Variable OPEX in EUR/MW
            FixedProfile(0),            # Fixed OPEX in EUR/24h
            Dict(NG => 1),              # Output from the Node, in this case, NG
        ),
        RefSource(
            j + 3,                        # Node id
            FixedProfile(1e12),         # Capacity in MW
            FixedProfile(9 * mc_scale),   # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/24h
            Dict(Coal => 1),            # Output from the Node, in this case, coal
        ),
        RefNetworkNode(
            j + 4,                        # Node id
            FixedProfile(25),           # Capacity in MW
            FixedProfile(5.5 * mc_scale), # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/24h
            Dict(NG => 2),              # Input to the node with input ratio
            Dict(Power => 1, CO2 => 1), # Output from the node with output ratio
            # Line above: CO2 is required as output for variable definition, but the
            # value does not matter
            [CaptureEnergyEmissions(0.9)], # Additonal data for emissions and CO₂ capture
        ),
        RefNetworkNode(
            j + 5,                        # Node id
            FixedProfile(25),           # Capacity in MW
            FixedProfile(6 * mc_scale),   # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/24h
            Dict(Coal => 2.5),          # Input to the node with input ratio
            Dict(Power => 1),           # Output from the node with output ratio
            [EmissionsEnergy()],        # Additonal data for emissions
        ),
        RefStorage{AccumulatingEmissions}(
            j + 6,                        # Node id
            StorCapOpex(
                FixedProfile(20),       # Charge capacity in t/h
                FixedProfile(9.1),      # Storage variable OPEX for the charging in EUR/t
                FixedProfile(0)        # Storage fixed OPEX for the charging in EUR/(t/h 8h)
            ),
            StorCap(FixedProfile(600)), # Storage capacity in t
            CO2,                        # Stored resource
            Dict(CO2 => 1, Power => 0.02), # Input resource with input ratio
            # Line above: This implies that storing CO2 requires Power
            Dict(CO2 => 1),             # Output from the node with output ratio
            # In practice, for CO₂ storage, this is never used.
            Data[],
        ),
        RefSink(
            j + 7,                        # Node id
            StrategicProfile(demand),   # Demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            # Line above: Surplus and deficit penalty for the node in EUR/MWh
            Dict(Power => 1),           # Energy demand and corresponding ratio
        ),
    ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
        Direct(j + 14, nodes[1], nodes[4], Linear())
        Direct(j + 15, nodes[1], nodes[5], Linear())
        Direct(j + 16, nodes[1], nodes[6], Linear())
        Direct(j + 17, nodes[1], nodes[7], Linear())
        Direct(j + 21, nodes[2], nodes[1], Linear())
        Direct(j + 31, nodes[3], nodes[1], Linear())
        Direct(j + 41, nodes[4], nodes[1], Linear())
        Direct(j + 51, nodes[5], nodes[1], Linear())
        Direct(j + 61, nodes[6], nodes[1], Linear())
    ]
    return nodes, links
end

"""
    generate_example_data_geo()

Generate the data for an example consisting of a simple electricity network. The simple \
network is existing within 5 regions with differing demand. Each region has the same \
technologies.

The example is partly based on the provided example `network.jl` in `EnergyModelsGeography`.
It will be repalced in the near future with a simplified example.
"""
function generate_example_data_geo()
    @info "Generate data coded dummy model for now (Investment Model)"

    # Retrieve the products
    products = get_resources_inv()
    NG = products[1]
    Power = products[3]
    CO2 = products[4]

    # Create input data for the areas
    area_ids = [1, 2, 3, 4]
    d_scale = Dict(1 => 3.0, 2 => 1.5, 3 => 1.0, 4 => 0.5)
    mc_scale = Dict(1 => 2.0, 2 => 2.0, 3 => 1.5, 4 => 0.5)
    gen_scale = Dict(1 => 1.0, 2 => 1.0, 3 => 1.0, 4 => 0.5)

    # Create identical areas with index according to input array
    an = Dict()
    nodes = EMB.Node[]
    links = Link[]
    for a_id ∈ area_ids
        n, l = get_sub_system_data_inv(
            a_id,
            products;
            gen_scale = gen_scale[a_id],
            mc_scale = mc_scale[a_id],
            d_scale = d_scale[a_id],
        )
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[a_id] = n[1]
    end

    # Create the individual areas
    areas = [
        RefArea(1, "Oslo", 10.751, 59.921, an[1]),
        RefArea(2, "Bergen", 5.334, 60.389, an[2]),
        RefArea(3, "Trondheim", 10.398, 63.437, an[3]),
        RefArea(4, "Tromsø", 18.953, 69.669, an[4]),
    ]

    # Create the investment data for the different power line investment modes
    inv_data_12 = SingleInvData(
        FixedProfile(500),
        FixedProfile(50),
        FixedProfile(0),
        BinaryInvestment(FixedProfile(50.0)),
    )

    inv_data_13 = SingleInvData(
        FixedProfile(10),
        FixedProfile(100),
        FixedProfile(0),
        SemiContinuousInvestment(FixedProfile(10), FixedProfile(100)),
    )

    inv_data_23 = SingleInvData(
        FixedProfile(10),
        FixedProfile(50),
        FixedProfile(20),
        DiscreteInvestment(FixedProfile(6)),
    )

    inv_data_34 = SingleInvData(
        FixedProfile(10),
        FixedProfile(50),
        FixedProfile(0),
        ContinuousInvestment(FixedProfile(1), FixedProfile(100)),
    )

    # Create the TransmissionModes and the Transmission corridors
    OverheadLine_50MW_12 = RefStatic(
        "PowerLine_50",
        Power,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_12],
    )
    OverheadLine_50MW_13 = RefStatic(
        "PowerLine_50",
        Power,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_13],
    )
    OverheadLine_50MW_23 = RefStatic(
        "PowerLine_50",
        Power,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_23],
    )
    OverheadLine_50MW_34 = RefStatic(
        "PowerLine_50",
        Power,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_34],
    )
    LNG_Ship_100MW = RefDynamic(
        "LNG_100",
        NG,
        FixedProfile(100.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
    )

    transmissions = [
        Transmission(areas[1], areas[2], [OverheadLine_50MW_12]),
        Transmission(areas[1], areas[3], [OverheadLine_50MW_13]),
        Transmission(areas[2], areas[3], [OverheadLine_50MW_23]),
        Transmission(areas[3], areas[4], [OverheadLine_50MW_34]),
        Transmission(areas[4], areas[2], [LNG_Ship_100MW]),
    ]

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, SimpleTimes(24, 1))
    em_limits = Dict(NG => FixedProfile(1e6), CO2 => StrategicProfile([450, 400, 350, 300]))
    em_cost = Dict(NG => FixedProfile(0), CO2 => FixedProfile(0))
    modeltype = InvestmentModel(em_limits, em_cost, CO2, 0.07)

    # Input data structure
    case = Case(
        T,
        products,
        [nodes, links, areas, transmissions],
        [[get_nodes, get_links], [get_areas, get_transmissions]],
    )
    return case, modeltype
end

function get_resources_inv()

    # Define the different resources
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [NG, Coal, Power, CO2]

    return products
end

function get_sub_system_data_inv(
    i,
    products;
    gen_scale::Float64 = 1.0,
    mc_scale::Float64 = 1.0,
    d_scale::Float64 = 1.0,
    demand = false,
)
    NG, Coal, Power, CO2 = products

    if demand == false
        demand = [
            OperationalProfile([
                20,
                20,
                20,
                20,
                25,
                30,
                35,
                35,
                40,
                40,
                40,
                40,
                40,
                35,
                35,
                30,
                25,
                30,
                35,
                30,
                25,
                20,
                20,
                20,
            ]),
            OperationalProfile([
                20,
                20,
                20,
                20,
                25,
                30,
                35,
                35,
                40,
                40,
                40,
                40,
                40,
                35,
                35,
                30,
                25,
                30,
                35,
                30,
                25,
                20,
                20,
                20,
            ]),
            OperationalProfile([
                20,
                20,
                20,
                20,
                25,
                30,
                35,
                35,
                40,
                40,
                40,
                40,
                40,
                35,
                35,
                30,
                25,
                30,
                35,
                30,
                25,
                20,
                20,
                20,
            ]),
            OperationalProfile([
                20,
                20,
                20,
                20,
                25,
                30,
                35,
                35,
                40,
                40,
                40,
                40,
                40,
                35,
                35,
                30,
                25,
                30,
                35,
                30,
                25,
                20,
                20,
                20,
            ]),
        ]
        demand *= d_scale
    end

    j = (i - 1) * 100
    nodes = [
        GeoAvailability(j + 1, products),
        RefSink(
            j + 2,
            StrategicProfile(demand),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
            Dict(Power => 1),
        ),
        RefSource(
            j + 3,
            FixedProfile(30),
            FixedProfile(30 * mc_scale),
            FixedProfile(100),
            Dict(NG => 1),
            [
                SingleInvData(
                    FixedProfile(1000), # capex [€/kW]
                    FixedProfile(200),  # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(10), FixedProfile(200)), # investment mode
                ),
            ],
        ),
        RefSource(
            j + 4,
            FixedProfile(9),
            FixedProfile(9 * mc_scale),
            FixedProfile(100),
            Dict(Coal => 1),
            [
                SingleInvData(
                    FixedProfile(1000), # capex [€/kW]
                    FixedProfile(200),  # max installed capacity [kW]
                    FixedProfile(0),
                    ContinuousInvestment(FixedProfile(10), FixedProfile(200)), # investment mode
                ),
            ],
        ),
        RefNetworkNode(
            j + 5,
            FixedProfile(0),
            FixedProfile(5.5 * mc_scale),
            FixedProfile(100),
            Dict(NG => 2),
            Dict(Power => 1, CO2 => 0),
            [
                SingleInvData(
                    FixedProfile(600),  # capex [€/kW]
                    FixedProfile(25),   # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(25)), # investment mode
                ),
                CaptureEnergyEmissions(0.9),
            ],
        ),
        RefNetworkNode(
            j + 6,
            FixedProfile(0),
            FixedProfile(6 * mc_scale),
            FixedProfile(100),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                SingleInvData(
                    FixedProfile(800),  # capex [€/kW]
                    FixedProfile(25),   # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(25)), # investment mode
                ),
                EmissionsEnergy(),
            ],
        ),
        RefStorage{AccumulatingEmissions}(
            j + 7,
            StorCapOpex(FixedProfile(0), FixedProfile(9.1 * mc_scale), FixedProfile(100)),
            StorCap(FixedProfile(0)),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(600),
                        ContinuousInvestment(FixedProfile(0), FixedProfile(600)),
                    ),
                    level = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(600),
                        ContinuousInvestment(FixedProfile(0), FixedProfile(600)),
                    ),
                ),
            ],
        ),
        RefNetworkNode(
            j + 8,
            FixedProfile(0),
            FixedProfile(0 * mc_scale),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                SingleInvData(
                    FixedProfile(10000),    # capex [€/kW]
                    FixedProfile(25),       # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(2)), # investment mode
                ),
                EmissionsEnergy(),
            ],
        ),
        RefStorage{AccumulatingEmissions}(
            j + 9,
            StorCapOpex(FixedProfile(3), FixedProfile(0 * mc_scale), FixedProfile(0)),
            StorCap(FixedProfile(5)),
            CO2,
            Dict(CO2 => 1, Power => 0.02),
            Dict(CO2 => 1),
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(30),
                        ContinuousInvestment(FixedProfile(0), FixedProfile(3)),
                    ),
                    level = NoStartInvData(
                        FixedProfile(500),
                        FixedProfile(50),
                        ContinuousInvestment(FixedProfile(0), FixedProfile(2)),
                    ),
                ),
            ],
        ),
        RefNetworkNode(
            j + 10,
            FixedProfile(0),
            FixedProfile(0 * mc_scale),
            FixedProfile(0),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [
                SingleInvData(
                    FixedProfile(10000),    # capex [€/kW]
                    FixedProfile(10000),    # max installed capacity [kW]
                    ContinuousInvestment(FixedProfile(0), FixedProfile(10000)), # investment mode
                ),
                EmissionsEnergy(),
            ],
        ),
    ]

    links = [
        Direct(j * 10 + 15, nodes[1], nodes[5], Linear())
        Direct(j * 10 + 16, nodes[1], nodes[6], Linear())
        Direct(j * 10 + 17, nodes[1], nodes[7], Linear())
        Direct(j * 10 + 18, nodes[1], nodes[8], Linear())
        Direct(j * 10 + 19, nodes[1], nodes[9], Linear())
        Direct(j * 10 + 110, nodes[1], nodes[10], Linear())
        Direct(j * 10 + 12, nodes[1], nodes[2], Linear())
        Direct(j * 10 + 31, nodes[3], nodes[1], Linear())
        Direct(j * 10 + 41, nodes[4], nodes[1], Linear())
        Direct(j * 10 + 51, nodes[5], nodes[1], Linear())
        Direct(j * 10 + 61, nodes[6], nodes[1], Linear())
        Direct(j * 10 + 71, nodes[7], nodes[1], Linear())
        Direct(j * 10 + 81, nodes[8], nodes[1], Linear())
        Direct(j * 10 + 91, nodes[9], nodes[1], Linear())
        Direct(j * 10 + 101, nodes[10], nodes[1], Linear())
    ]
    return nodes, links
end

"""
    generate_example_network_investment()

Generate the data for an example consisting of a simple electricity network.
The more stringent CO₂ emission in latter investment periods force the investment into both
the natural gas power plant with CCS and the CO₂ storage node.
"""
function generate_example_network_investment()
    @info "Generate case data - Simple network example with investments"

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

    # Each operational period should correspond to a duration of 2 h while a duration if 1
    # of a strategic period should correspond to a year.
    # This implies, that a strategic period is 8760 times longer than an operational period,
    # resulting in the values below as "/year".
    op_per_strat = 8760

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, operational_periods; op_per_strat)
    model = InvestmentModel(
        Dict(   # Emission cap for CO₂ in t/year and for NG in MWh/year
            CO2 => StrategicProfile([170, 150, 130, 110]) * 1000,
            NG => FixedProfile(1e6),
        ),
        Dict(   # Emission price for CO₂ in EUR/t and for NG in EUR/MWh
            CO2 => FixedProfile(0),
            NG => FixedProfile(0),
        ),
        CO2,    # CO2 instance
        0.07,   # Discount rate in absolute value
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
            FixedProfile(30),           # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(NG => 1),              # Output from the Node, in this case, NG
        ),
        RefSource(
            "coal source",              # Node id
            FixedProfile(100),          # Capacity in MW
            FixedProfile(9),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(Coal => 1),            # Output from the Node, in this case, coal
        ),
        RefNetworkNode(
            "NG+CCS power plant",       # Node id
            FixedProfile(0),            # Capacity in MW
            FixedProfile(5.5),          # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(NG => 2),              # Input to the node with input ratio
            Dict(Power => 1, CO2 => 0), # Output from the node with output ratio
            # Line above: CO2 is required as output for variable definition, but the
            # value does not matter
            [
                capture_data,           # Additonal data for emissions and CO₂ capture
                SingleInvData(
                    FixedProfile(600 * 1e3),  # Capex in EUR/MW
                    FixedProfile(40),       # Max installed capacity [MW]
                    SemiContinuousInvestment(FixedProfile(5), FixedProfile(40)),
                    # Line above: Investment mode with the following arguments:
                    # 1. argument: min added capactity per sp [MW]
                    # 2. argument: max added capactity per sp [MW]
                ),
            ],
        ),
        RefNetworkNode(
            "coal power plant",         # Node id
            FixedProfile(40),           # Capacity in MW
            FixedProfile(6),            # Variable OPEX in EUR/MWh
            FixedProfile(0),            # Fixed OPEX in EUR/MW/year
            Dict(Coal => 2.5),          # Input to the node with input ratio
            Dict(Power => 1),           # Output from the node with output ratio
            [emission_data],            # Additonal data for emissions
        ),
        RefStorage{AccumulatingEmissions}(
            "CO2 storage",              # Node id
            StorCapOpex(
                FixedProfile(0),       # Charge capacity in t/h
                FixedProfile(9.1),      # Storage variable OPEX for the charging in EUR/t
                FixedProfile(0)         # Storage fixed OPEX for the charging in EUR/(t/h year)
            ),
            StorCap(FixedProfile(1e8)), # Storage capacity in t
            CO2,                        # Stored resource
            Dict(CO2 => 1, Power => 0.02), # Input resource with input ratio
            # Line above: This implies that storing CO₂ requires Power
            Dict(CO2 => 1),             # Output from the node with output ratio
            # In practice, for CO₂ storage, this is never used.
            [
                StorageInvData(
                    charge = NoStartInvData(
                        FixedProfile(200 * 1e3),  # CAPEX [EUR/(t/h)]
                        FixedProfile(60),       # Max installed capacity [EUR/(t/h)]
                        ContinuousInvestment(FixedProfile(0), FixedProfile(5)),
                        # Line above: Investment mode with the following arguments:
                        # 1. argument: min added capactity per sp [t/h]
                        # 2. argument: max added capactity per sp [t/h]
                        UnlimitedLife(),        # Lifetime mode
                    ),
                ),
            ],
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
    generate_example_ss_investment(lifemode = RollingLife; discount_rate = 0.05)

Generate the data for an example consisting of an electricity source and sink.
The electricity source has initially no capacity. Hence, investments are required.
"""
function generate_example_ss_investment(lifemode = RollingLife; discount_rate = 0.05)
    @info "Generate case data - Simple sink-source example"

    # Define the different resources and their emission intensity in tCO2/MWh
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # Each operational period should correspond to a duration of 2 h while a duration if 1
    # of a strategic period should correspond to a year.
    # This implies, that a strategic period is 8760 times longer than an operational period,
    # resulting in the values below as "/year".
    op_per_strat = 8760

    sp_duration = 5 # The duration of a investment period is given as 5 years

    # Creation of the time structure and global data
    T = TwoLevel(4, sp_duration, operational_periods; op_per_strat)

    # Create the global data
    model = InvestmentModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO₂ in t/year
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO₂ in EUR/t
        CO2,                            # CO₂ instance
        discount_rate,                  # Discount rate in absolute value
    )

    # The lifetime of the technology is 15 years, requiring reinvestment in the
    # 5th investment period
    lifetime = FixedProfile(15)

    # Create the investment data for the source node
    investment_data_source = SingleInvData(
        FixedProfile(300 * 1e3),  # capex [€/MW]
        FixedProfile(50),       # max installed capacity [MW]
        ContinuousInvestment(FixedProfile(0), FixedProfile(30)),
        # Line above: Investment mode with the following arguments:
        # 1. argument: min added capactity per sp [MW]
        # 2. argument: max added capactity per sp [MW]
        lifemode(lifetime),     # Lifetime mode
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    nodes = [
        RefSource(
            "electricity source",       # Node id
            FixedProfile(0),            # Capacity in MW
            FixedProfile(10),           # Variable OPEX in EUR/MW
            FixedProfile(5),            # Fixed OPEX in EUR/MW/year
            Dict(Power => 1),           # Output from the Node, in this case, Power
            [investment_data_source],   # Additional data used for adding the investment data
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

"""
    generate_example_snd()

Generate the data for an example consisting of a simple electricity network with a
non-dispatchable power source, a standard source, as well as a demand.
It illustrates how the non-dispatchable power source requires a balancing power source.
"""
function generate_example_snd()
    @info "Generate case data - Simple `NonDisRES` example"

    # Define the different resources and their emission intensity in tCO2/MWh
    # CO2 has to be defined, even if not used, as it is required for the `EnergyModel` type
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    products = [Power, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2
    op_number = 4   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/8h".
    op_per_strat = op_duration * op_number

    # Creation of the time structure and global data
    T = TwoLevel(2, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),  # Emission cap for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)),   # Emission price for CO2 in EUR/t
        CO2,                            # CO2 instance
    )

    # Create the individual test nodes, corresponding to a system with an electricity
    # demand/sink and source
    source = RefSource(
        "source",           # Node ID
        FixedProfile(2),    # Capacity in MW
        FixedProfile(30),   # Variable OPEX in EUR/MW
        FixedProfile(10),   # Fixed OPEX in EUR/8h
        Dict(Power => 1),   # Output from the Node, in this gase, Power
    )
    sink = RefSink(
        "electricity demand",   # Node id
        FixedProfile(2),    # Demand in MW
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        # Line above: Surplus and deficit penalty for the node in EUR/MWh
        Dict(Power => 1),   # Energy demand and corresponding ratio
    )
    nodes = [source, sink]

    # Connect the two nodes with each other
    links = [Direct("source-demand", nodes[1], nodes[2], Linear())]

    # Create the additonal non-dispatchable power source
    wind = NonDisRES(
        "wind",             # Node ID
        FixedProfile(4),    # Capacity in MW
        OperationalProfile([0.9, 0.4, 0.1, 0.8]), # Profile of the NonDisRES node
        FixedProfile(10),   # Variable OPEX in EUR/MW
        FixedProfile(10),   # Fixed OPEX in EUR/8h
        Dict(Power => 1),   # Output from the Node, in this gase, Power
    )

    # Update the case data with the non-dispatchable power source and link
    push!(nodes, wind)
    link = Direct("wind-demand", nodes[3], nodes[2], Linear())
    push!(links, link)
    case = Case(T, products, [nodes, links])

    return case, model
end
