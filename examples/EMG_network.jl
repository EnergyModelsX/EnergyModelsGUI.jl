using EnergyModelsBase
using EnergyModelsGeography
using JuMP
using HiGHS
using TimeStruct

const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography

function read_data()
    @debug "Read case data"

    # Retrieve the products
    products = get_resources()
    NG    = products[1]
    Power = products[3]
    CO2   = products[4]

    # Variables for the individual entries of the time structure
    op_duration = 1 # Each operational period has a duration of 2
    op_number = 24   # There are in total 4 operational periods
    operational_periods = SimpleTimes(op_number, op_duration)

    # The number of operational periods times the duration of the operational periods, which
    # can also be extracted using the function `duration` of a `SimpleTimes` structure.
    # This implies, that a strategic period is 8 times longer than an operational period,
    # resulting in the values below as "/2h".
    op_per_strat = duration(operational_periods)

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, operational_periods; op_per_strat)
    model = OperationalModel(
        Dict(
            CO2 => StrategicProfile([160, 140, 120, 100]),  # CO₂ emission cap in t/24h
            NG  => FixedProfile(1e6),                       # NG cap in MWh/24h
        ),
        Dict(
            CO2 => FixedProfile(0),                         # CO₂ emission cost in EUR/t
            NG  => FixedProfile(0),                         # NG emission cost in EUR/t
        ),
        CO2,
    )

    # Create input data for the individual areas
    # The input data is based on scaling factors and/or specified demands
    area_ids    = [1, 2, 3, 4, 5, 6, 7]
    d_scale     = Dict(1=>3.0, 2=>1.5, 3=>1.0, 4=>0.5, 5=>0.5, 6=>0.0, 7=>3.0)
    mc_scale    = Dict(1=>2.0, 2=>2.0, 3=>1.5, 4=>0.5, 5=>0.5, 6=>0.5, 7=>3.0)

    tromsø_demand = [OperationalProfile([10 10 10 10 35 40 45 45 50 50 60 60 50 45 45 40 35 40 45 40 35 30 30 30]);
                     OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                     OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                     OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                    ]
    demand = Dict(1=>false, 2=>false, 3=>false, 4=>tromsø_demand, 5=>false, 6=>false, 7=>false)

    # Create identical areas with index according to the input array
    an           = Dict()
    nodes        = []
    links        = []
    for a_id in area_ids
        n, l = get_sub_system_data(
            a_id,
            products;
            mc_scale = mc_scale[a_id],
            d_scale = d_scale[a_id],
            demand=demand[a_id],
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

    OB_OverheadLine_50MW   = RefStatic("OB_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix,  2)
    OT_OverheadLine_50MW   = RefStatic("OT_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    OK_OverheadLine_50MW   = RefStatic("OK_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    BT_OverheadLine_50MW   = RefStatic("BT_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    BTN_LNG_Ship_100MW     = RefDynamic("BTN_LNG_100", NG, cap_lng, loss, opex_var, opex_fix, 1)
    BK_OverheadLine_50MW   = RefStatic("BK_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    TTN_OverheadLine_50MW  = RefStatic("TTN_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    KS_OverheadLine_50MW  = RefStatic("KS_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)
    SD_OverheadLine_50MW  = RefStatic("SD_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2)

    # Create the different transmission corridors between the individual areas
    transmission = [
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

    # WIP data structure
    case = Dict(
                :areas          => Array{Area}(areas),
                :transmission   => Array{Transmission}(transmission),
                :nodes          => Array{EMB.Node}(nodes),
                :links          => Array{Link}(links),
                :products       => products,
                :T              => T,
                )
    return case, model
end

function get_resources()

    # Define the different resources
    NG       = ResourceEmit("NG", 0.2)
    Coal     = ResourceCarrier("Coal", 0.35)
    Power    = ResourceCarrier("Power", 0.)
    CO2      = ResourceEmit("CO2",1.)
    products = [NG, Coal, Power, CO2]

    return products
end

# Subsystem test data for geography package. All subsystems are the same, except for the
# profiles
# The subsystem is similar to the subsystem in the `network.jl` example of EnergyModelsBase.
function get_sub_system_data(
        i,
        products;
        mc_scale::Float64=1.0,
        d_scale::Float64=1.0,
        demand=false,
    )

    NG, Coal, Power, CO2 = products

    # Use of standard demand if not provided differently
    d_standard = OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20])
    if demand == false
        demand = [d_standard; d_standard; d_standard; d_standard]
        demand *= d_scale
    end

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO₂ storage.
    j=(i-1)*100
    nodes = [
            GeoAvailability(j+1, products),
            RefSource(
                j+2,                        # Node id
                FixedProfile(1e12),         # Capacity in MW
                FixedProfile(30*mc_scale),  # Variable OPEX in EUR/MW
                FixedProfile(0),            # Fixed OPEX in EUR/24h
                Dict(NG => 1),              # Output from the Node, in this gase, NG
            ),
            RefSource(
                j+3,                        # Node id
                FixedProfile(1e12),         # Capacity in MW
                FixedProfile(9*mc_scale),   # Variable OPEX in EUR/MWh
                FixedProfile(0),            # Fixed OPEX in EUR/24h
                Dict(Coal => 1),            # Output from the Node, in this gase, coal
            ),
            RefNetworkNode(
                j+4,                        # Node id
                FixedProfile(25),           # Capacity in MW
                FixedProfile(5.5*mc_scale), # Variable OPEX in EUR/MWh
                FixedProfile(0),            # Fixed OPEX in EUR/24h
                Dict(NG => 2),              # Input to the node with input ratio
                Dict(Power => 1, CO2 => 1), # Output from the node with output ratio
                # Line above: CO2 is required as output for variable definition, but the
                # value does not matter
                [CaptureEnergyEmissions(0.9)], # Additonal data for emissions and CO₂ capture
            ),
            RefNetworkNode(
                j+5,                        # Node id
                FixedProfile(25),           # Capacity in MW
                FixedProfile(6*mc_scale),   # Variable OPEX in EUR/MWh
                FixedProfile(0),            # Fixed OPEX in EUR/24h
                Dict(Coal => 2.5),          # Input to the node with input ratio
                Dict(Power => 1),           # Output from the node with output ratio
                [EmissionsEnergy()],        # Additonal data for emissions
            ),
            RefStorage(
                j+6,                        # Node id
                FixedProfile(20),           # Rate capacity in t/h
                FixedProfile(600),          # Storage capacity in t
                FixedProfile(9.1),          # Storage variable OPEX for the rate in EUR/t
                FixedProfile(0),            # Storage fixed OPEX for the rate in EUR/(t/h 24h)
                CO2,                        # Stored resource
                Dict(CO2 => 1, Power => 0.02), # Input resource with input ratio
                # Line above: This implies that storing CO2 requires Power
                Dict(CO2 => 1),             # Output from the node with output ratio
                # In practice, for CO₂ storage, this is never used.
                Data[]
            ),
            RefSink(
                j+7,                        # Node id
                StrategicProfile(demand),   # Demand in MW
                Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
                # Line above: Surplus and deficit penalty for the node in EUR/MWh
                Dict(Power => 1),           # Energy demand and corresponding ratio
            ),
            ]

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
            Direct(j+14,nodes[1],nodes[4],Linear())
            Direct(j+15,nodes[1],nodes[5],Linear())
            Direct(j+16,nodes[1],nodes[6],Linear())
            Direct(j+17,nodes[1],nodes[7],Linear())
            Direct(j+21,nodes[2],nodes[1],Linear())
            Direct(j+31,nodes[3],nodes[1],Linear())
            Direct(j+41,nodes[4],nodes[1],Linear())
            Direct(j+51,nodes[5],nodes[1],Linear())
            Direct(j+61,nodes[6],nodes[1],Linear())
            ]
    return nodes, links
end

case, model = read_data()
m = EMG.create_model(case, model)


set_optimizer(m, optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true))
optimize!(m)
solution_summary(m)

## Code above identical to the example EnergyModelsBase.jl/examples/network.jl
##########################################################################################################################
## Code below for displaying the GUI

using EnergyModelsGUI

# Define colors for all products
products_color = ["Gas", "Coal", "Electricity", "ResourceEmit"]
idToColorMap = setColors(case[:products], products_color)

# Set folder where visualization info is saved and retrieved
design_path = joinpath(@__DIR__, "..", "design", "EMG", "network")

# Run the GUI
gui = GUI(case; design_path, idToColorMap, model = m)