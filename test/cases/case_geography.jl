function generate_case_geography()
    NG = ResourceEmit("NG", 0.2)
    Coal = ResourceCarrier("Coal", 0.35)
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    H2 = ResourceCarrier("H2", 0.0)
    Waste = ResourceCarrier("Waste", 0.0)
    Biomass = ResourceCarrier("Biomass", 0.0)
    Oil = ResourceCarrier("Oil", 0.3)
    products = [NG, Coal, Power, CO2, H2, Waste, Biomass, Oil]

    # Create the individual areas with their nodes and links
    d_standard = OperationalProfile(read_profile("standard demand.dat")) # In MW
    area_1, nodes_1, links_1 = case_geography_area(
        1, "Oslo", 10.751, 59.921, products, d_standard; mc_scale = 2.0, d_scale = 3.0,
    )
    area_2, nodes_2, links_2 = case_geography_area(
        2, "Bergen", 5.334, 60.389, products, d_standard; mc_scale = 2.0, d_scale = 1.5,
    )
    area_3, nodes_3, links_3 = case_geography_area(
        3, "Trondheim", 10.398, 63.437, products, d_standard; mc_scale = 1.5,
        d_scale = 1.0,
    )
    area_4, nodes_4, links_4 = case_geography_area(
        4, "Tromsø", 18.953, 69.669, products, d_standard; mc_scale = 0.5, d_scale = 0.5,
    )
    areas = [area_1, area_2, area_3, area_4]

    # Investment data of the transmission modes
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

    # Bidirectional transmission mode without operational costs
    mode(type, id, resource, cap, loss, data...) = type(
        id,
        resource,
        FixedProfile(cap),  # Capacity
        FixedProfile(loss), # Relative loss
        FixedProfile(0),    # Variable OPEX
        FixedProfile(0),    # Fixed OPEX
        2,                  # Bidirectional transport
        data...,
    )

    transmissions = [
        Transmission(
            areas[1],
            areas[2],
            [mode(RefStatic, "PowerLine_50_12", Power, 50.0, 0.05, [inv_data_binary])],
        ),
        Transmission(
            areas[2],
            areas[3],
            [mode(RefStatic, "PowerLine_50_23", Power, 50.0, 0.05, [inv_data_discrete])],
        ),
        Transmission(
            areas[3],
            areas[4],
            [mode(RefStatic, "PowerLine_50_34", Power, 50.0, 0.05, [inv_data_continuous])],
        ),
        Transmission(areas[4], areas[2], [mode(RefDynamic, "LNG_100_42", NG, 100.0, 0.05)]),
        Transmission(
            areas[1],
            areas[3],
            [
                mode(RefStatic, "PowerLine_50_OT", Power, 50.0, 0.05, [inv_data_semicont]),
                mode(
                    RefStatic,
                    "NG_Pipeline_100_OT",
                    NG,
                    100.0,
                    0.03,
                    [inv_data_continuous],
                ),
                mode(RefDynamic, "Coal_Transport_50_OT", Coal, 50.0, 0.08),
                mode(
                    RefStatic,
                    "CO2_Pipeline_100_OT",
                    CO2,
                    100.0,
                    0.02,
                    [inv_data_continuous],
                ),
                mode(RefStatic, "H2_Pipeline_100_OT", H2, 100.0, 0.05),
                mode(RefDynamic, "H2_Transport_50_OT", H2, 50.0, 0.05),
                mode(RefDynamic, "Waste_Transport_50_OT", Waste, 50.0, 0.05),
            ],
        ),
        Transmission(
            areas[3],
            areas[1],
            [
                mode(RefDynamic, "Biomass_Transport_50_OT", Biomass, 50.0, 0.05),
                mode(
                    RefStatic,
                    "Oil_Pipeline_100_OT",
                    Oil,
                    100.0,
                    0.05,
                    [inv_data_continuous],
                ),
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
        [
            EMB.Node[nodes_1; nodes_2; nodes_3; nodes_4],
            Link[links_1; links_2; links_3; links_4],
            areas,
            transmissions,
        ],
        [[get_nodes, get_links], [get_areas, get_transmissions]],
    )

    return case, modeltype
end

# Area with investments in the nodes; the standard demand is scaled by `d_scale`
function case_geography_area(i, name, lon, lat, products, d_standard; mc_scale, d_scale)
    NG, Coal, Power, CO2 = products
    demand = fill(d_standard, 4) * d_scale

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
            [continuous_inv(1000, 200, 10, 200)],
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
            [continuous_inv(600, 25, 0, 25), CaptureEnergyEmissions(0.9)],
        ),
        RefNetworkNode(
            j + 6,
            FixedProfile(0),
            FixedProfile(6 * mc_scale),
            FixedProfile(100),
            Dict(Coal => 2.5),
            Dict(Power => 1),
            [continuous_inv(800, 25, 0, 25), EmissionsEnergy()],
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
            [continuous_inv(10000, 25, 0, 2), EmissionsEnergy()],
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
            [continuous_inv(10000, 10000, 0, 10000), EmissionsEnergy()],
        ),
    ]

    # Links from the availability node to the other nodes and back. The ids are the
    # concatenated node numbers (for example 110 for 1 → 10) shifted by `j * 10`.
    links = [
        [
            Direct(j * 10 + parse(Int, "1$k"), nodes[1], nodes[k], Linear()) for
            k ∈ [5:10; 2]
        ]
        [Direct(j * 10 + parse(Int, "$(k)1"), nodes[k], nodes[1], Linear()) for k ∈ 3:10]
    ]

    # Create the area
    area = RefArea(i, name, lon, lat, nodes[1])
    return area, nodes, links
end

function run_case_geography()
    # Get case and model data
    case, model = generate_case_geography()

    # Construct JuMP model for optimization
    m = create_model(case, model)

    # Set optimizer for JuMP
    set_optimizer(m, HiGHS.Optimizer)

    # Solve the optimization problem
    optimize!(m)

    # Check that the case is unchanged (relative MIP gap of HiGHS)
    @test isapprox(objective_value(m), -1.5246627469650488e6; rtol = 1e-4)

    ## Plot topology and results in GUI
    gui = GUI(
        case;
        design_path = joinpath(@__DIR__, "design", "EMI", "geography_2"),
        model = m,
        coarse_coast_lines = false,
        scale_tot_opex = true,
        scale_tot_capex = false,
        pre_plot_sub_components = false,
        simplified_connection_plotting = true,
        simplify_all_levels = true,
    )

    return case, model, m, gui
end
