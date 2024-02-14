using EnergyModelsBase
using EnergyModelsGeography
using JuMP
using HiGHS
using TimeStruct

const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography

function run_model(case, model, optimizer=nothing)
   @debug "Run model" optimizer

    m = EMG.create_model(case, model)

    if !isnothing(optimizer)
        set_optimizer(m, optimizer)
        optimize!(m)
        # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
        # TODO: save_solution(m) save results
    else
        @info "No optimizer given"
    end
    return m, case
end

function read_data()
    @debug "Read case data"
    @info "Hard coded dummy model for now."

    # Retrieve the products
    products = get_resources()
    NG    = products[1]
    Power = products[3]
    CO2   = products[4]

    model = OperationalModel(
                            Dict(
                                CO2 => StrategicProfile([160, 140, 120, 100]),
                                NG  => FixedProfile(1e6)
                            ),
                            Dict(
                                CO2 => FixedProfile(0),
                                NG  => FixedProfile(0)
                            ),
                            CO2,
                        )

    # Create input data for the areas
    area_ids    = [1, 2, 3, 4, 5, 6, 7]
    d_scale     = Dict(1=>3.0, 2=>1.5, 3=>1.0, 4=>0.5, 5=>0.5, 6=>0.0, 7=>3.0)
    gen_scale   = Dict(1=>1.0, 2=>1.0, 3=>1.0, 4=>0.5, 5=>1.0, 6=>1.0, 7=>1.0)
    mc_scale    = Dict(1=>2.0, 2=>2.0, 3=>1.5, 4=>0.5, 5=>0.5, 6=>0.5, 7=>3.0)

    tromsø_demand = [OperationalProfile([10 10 10 10 35 40 45 45 50 50 60 60 50 45 45 40 35 40 45 40 35 30 30 30]);
                     OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                     OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                     OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                    ]
    demand = Dict(1=>false, 2=>false, 3=>false, 4=>tromsø_demand, 5=>false, 6=>false, 7=>false)

    # Create identical areas with index accoriding to input array
    an           = Dict()
    transmission = []
    nodes        = []
    links        = []
    for a_id in area_ids
        n, l = get_sub_system_data(a_id, products, model;
                                   gen_scale = gen_scale[a_id], mc_scale = mc_scale[a_id],
                                   d_scale = d_scale[a_id], demand=demand[a_id])
        append!(nodes, n)
        append!(links, l)

        # Add area node for each subsystem
        an[a_id] = n[1]
    end

    # Create the individual areas and transmission modes
    areas = [RefArea(1, "Oslo", 10.751, 59.921, an[1]),
             RefArea(2, "Bergen", 5.334, 60.389, an[2]),
             RefArea(3, "Trondheim", 10.398, 63.4366, an[3]),
             RefArea(4, "Tromsø", 18.953, 69.669, an[4]),
             RefArea(5, "Kristiansand", 7.984, 58.146, an[5]),
             RefArea(6, "Sørlige Nordsjø II", 6.836, 57.151, an[6]),
             RefArea(7, "Danmark", 8.614, 56.359, an[7])]


    cap_ohl = FixedProfile(50.0)
    cap_lng = FixedProfile(100.0)
    loss = FixedProfile(0.05)
    opex_var = FixedProfile(0.05)
    opex_fix = FixedProfile(0.05)


    OB_OverheadLine_50MW   = RefStatic("OB_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix,  2, [])
    OT_OverheadLine_50MW   = RefStatic("OT_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2, [])
    OK_OverheadLine_50MW   = RefStatic("OK_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2, [])
    BT_OverheadLine_50MW   = RefStatic("BT_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2, [])
    BTN_LNG_Ship_100MW     = RefDynamic("BTN_LNG_100", NG, cap_lng, loss, opex_var, opex_fix, 1, [])
    BK_OverheadLine_50MW   = RefStatic("BK_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2, [])
    TTN_OverheadLine_50MW  = RefStatic("TTN_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2, [])
    KS_OverheadLine_50MW  = RefStatic("KS_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2, [])
    SD_OverheadLine_50MW  = RefStatic("SD_PowerLine_50", Power, cap_ohl, loss, opex_var, opex_fix, 2, [])

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

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, SimpleTimes(24, 1))

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

# Subsystem test data for geography package
function get_sub_system_data(i, products, modeltype;
                             gen_scale::Float64=1.0, mc_scale::Float64=1.0, d_scale::Float64=1.0, demand=false)

    NG, Coal, Power, CO2 = products

    # Use of standard demand if not provided differently
    if demand == false
        demand = [OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                  OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                  OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20]);
                  OperationalProfile([20 20 20 20 25 30 35 35 40 40 40 40 40 35 35 30 25 30 35 30 25 20 20 20])]
        demand *= d_scale
    end

    j=(i-1)*100
    nodes = [
            GeoAvailability(j+1, products),
            RefSource(j+2, FixedProfile(1e12), FixedProfile(30*mc_scale),
                            FixedProfile(0), Dict(NG => 1),
                            []),
            RefSource(j+3, FixedProfile(1e12), FixedProfile(9*mc_scale),
                            FixedProfile(0), Dict(Coal => 1),
                            []),
            RefNetworkNode(j+4, FixedProfile(25), FixedProfile(5.5*mc_scale),
                            FixedProfile(0), Dict(NG => 2),
                            Dict(Power => 1, CO2 => 1),
                            [CaptureEnergyEmissions(0.9)]),
            RefNetworkNode(j+5, FixedProfile(25), FixedProfile(6*mc_scale),
                            FixedProfile(0),  Dict(Coal => 2.5),
                            Dict(Power => 1),
                            []),
            RefStorage(j+6, FixedProfile(20), FixedProfile(600), FixedProfile(9.1),
                            FixedProfile(0),  CO2, Dict(CO2 => 1, Power => 0.02), Dict(CO2 => 1),
                            Array{Data}([])),
            RefSink(j+7, StrategicProfile(demand),
                            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
                            Dict(Power => 1)),
            ]

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

if runOptimization
    m, case = run_model(case, model, HiGHS.Optimizer)

    solution_summary(m)
end

## The following variables are set for the GUI
# Define colors for all products
products_color = ["Gas", "Coal", "Electricity", "ResourceEmit"]
idToColorMap = EnergyModelsGUI.setColors(case[:products], products_color)

# Do not use icons
idToIconMap = EnergyModelsGUI.setIcons(case[:nodes], [])


design_path::String = joinpath(@__DIR__, "..", "design", "EMG") # folder where visualization info is saved and retrieved