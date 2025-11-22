function generate_example_data_geo_all_resources()
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    H2 = ResourceCarrier("H2", 0.0)
    Waste = ResourceCarrier("Waste", 0.0)
    Biomass = ResourceCarrier("Biomass", 0.0)
    Oil = ResourceCarrier("Oil", 0.3)
    products = [NG, Coal, Power, CO2, H2, Waste, Biomass, Oil]

    area_ids  = [1, 2, 3, 4]
    d_scale   = Dict(1 => 3.0, 2 => 1.5, 3 => 1.0, 4 => 0.5)
    mc_scale  = Dict(1 => 2.0, 2 => 2.0, 3 => 1.5, 4 => 0.5)
    gen_scale = Dict(1 => 1.0, 2 => 1.0, 3 => 1.0, 4 => 0.5)

    an    = Dict{Int,EMB.Node}()
    nodes = EMB.Node[]
    links = Link[]

    for a_id ∈ area_ids
        n, l = get_sub_system_data_inv(
            a_id,
            products;
            gen_scale = gen_scale[a_id],
            mc_scale  = mc_scale[a_id],
            d_scale   = d_scale[a_id],
        )
        append!(nodes, n)
        append!(links, l)

        an[a_id] = n[1]
    end

    areas = [
        RefArea(1, "Oslo", 10.751, 59.921, an[1]),
        RefArea(2, "Bergen", 5.334, 60.389, an[2]),
        RefArea(3, "Trondheim", 10.398, 63.437, an[3]),
        RefArea(4, "Tromsø", 18.953, 69.669, an[4]),
    ]

    inv_data_binary = SingleInvData(
        FixedProfile(500),  # capex
        FixedProfile(50),   # max cap
        FixedProfile(0),
        BinaryInvestment(FixedProfile(50.0)),
    )

    inv_data_semicont = SingleInvData(
        FixedProfile(10),
        FixedProfile(100),
        FixedProfile(0),
        SemiContinuousInvestment(FixedProfile(10), FixedProfile(100)),
    )

    inv_data_discrete = SingleInvData(
        FixedProfile(10),
        FixedProfile(50),
        FixedProfile(20),
        DiscreteInvestment(FixedProfile(6)),
    )

    inv_data_continuous = SingleInvData(
        FixedProfile(10),
        FixedProfile(50),
        FixedProfile(0),
        ContinuousInvestment(FixedProfile(1), FixedProfile(100)),
    )

    inv_data_oil = SingleInvData(
        FixedProfile(10),
        FixedProfile(50),
        FixedProfile(0),
        ContinuousInvestment(FixedProfile(1), FixedProfile(100)),
    )

    OverheadLine_50MW_12 = RefStatic(
        "PowerLine_50_12",
        Power,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_binary],
    )

    OverheadLine_50MW_23 = RefStatic(
        "PowerLine_50_23",
        Power,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_discrete],
    )

    OverheadLine_50MW_34 = RefStatic(
        "PowerLine_50_34",
        Power,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_continuous],
    )

    LNG_Ship_100MW_42 = RefDynamic(
        "LNG_100_42",
        NG,
        FixedProfile(100.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
    )

    PowerLine_50MW_OT = RefStatic(
        "PowerLine_50_OT",
        Power,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_semicont],
    )

    NG_Pipeline_100MW_OT = RefStatic(
        "NG_Pipeline_100_OT",
        NG,
        FixedProfile(100.0),
        FixedProfile(0.03),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_continuous],
    )

    Coal_Transport_50MW_OT = RefDynamic(
        "Coal_Transport_50_OT",
        Coal,
        FixedProfile(50.0),
        FixedProfile(0.08),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [],
    )

    CO2_Pipeline_100MW_OT = RefStatic(
        "CO2_Pipeline_100_OT",
        CO2,
        FixedProfile(100.0),
        FixedProfile(0.02),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_continuous],
    )

    H2_Pipeline_100MW_OT = RefStatic(
        "H2_Pipeline_100_OT",
        H2,
        FixedProfile(100.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [],
    )

    Waste_Transport_50MW_OT = RefDynamic(
        "Waste_Transport_50_OT",
        Waste,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [],
    )

    Biomass_Transport_50MW_OT = RefDynamic(
        "Biomass_Transport_50_OT",
        Biomass,
        FixedProfile(50.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [],
    )

    Oil_Pipeline_100MW_OT = RefStatic(
        "Oil_Pipeline_100_OT",
        Oil,
        FixedProfile(100.0),
        FixedProfile(0.05),
        FixedProfile(0),
        FixedProfile(0),
        2,
        [inv_data_oil],
    )

    transmissions = [
        Transmission(areas[1], areas[2], [OverheadLine_50MW_12]),
        Transmission(areas[2], areas[3], [OverheadLine_50MW_23]),
        Transmission(areas[3], areas[4], [OverheadLine_50MW_34]),
        Transmission(areas[4], areas[2], [LNG_Ship_100MW_42]),
        Transmission(
            areas[1],
            areas[3],
            [
                PowerLine_50MW_OT,
                NG_Pipeline_100MW_OT,
                Coal_Transport_50MW_OT,
                CO2_Pipeline_100MW_OT,
                H2_Pipeline_100MW_OT,
                Waste_Transport_50MW_OT,
            ],
        ),
        Transmission(
            areas[3],
            areas[1],
            [
                Biomass_Transport_50MW_OT,
                Oil_Pipeline_100MW_OT,
            ],
        ),
    ]

    T = TwoLevel(4, 1, SimpleTimes(24, 1))
    em_limits = Dict(
        NG  => FixedProfile(1e6),
        CO2 => StrategicProfile([450, 400, 350, 300]),
    )
    em_cost = Dict(
        NG  => FixedProfile(0),
        CO2 => FixedProfile(0),
    )

    modeltype = InvestmentModel(em_limits, em_cost, CO2, 0.07)

    case = Case(
        T,
        products,
        [nodes, links, areas, transmissions],
        [[get_nodes, get_links], [get_areas, get_transmissions]],
    )

    return case, modeltype
end

function run_case_EMI_geography_2()
    # Get case and model data
    case, model = generate_example_data_geo_all_resources()

    # Construct JuMP model for optimization
    m = create_model(case, model)

    # Set optimizer for JuMP
    set_optimizer(m, HiGHS.Optimizer)

    # Solve the optimization problem
    optimize!(m)

    # Print solution summary
    solution_summary(m)

    ## Plot topology and results in GUI
    gui = GUI(
        case;
        design_path = joinpath(@__DIR__, "design", "EMI", "geography_2"),
        model = m,
        coarse_coast_lines = false,
        scale_tot_opex = true,
        scale_tot_capex = false,
        pre_plot_sub_components = false,
    )

    return case, model, m, gui
end
