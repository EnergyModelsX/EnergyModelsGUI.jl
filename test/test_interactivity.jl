# Load case 7 for testing
case, model, m, gui = run_case()

root_design = get_root_design(gui)
components = get_components(root_design)
connections = get_connections(root_design)

area1 = get_component(components, 1)
area2 = get_component(components, 2)
area3 = get_component(components, 3)
area4 = get_component(components, 4)

time_menu = get_menu(gui, :time)
available_data_menu = get_menu(gui, :available_data)
period_menu = get_menu(gui, :period)
representative_period_menu = get_menu(gui, :representative_period)
export_type_menu = get_menu(gui, :export_type)
axes_menu = get_menu(gui, :axes)

pin_plot_button = get_button(gui, :pin_plot)

expand_all_toggle = get_toggle(gui, :expand_all)
simplified_toggle = get_toggle(gui, :simplified)

# Test specific GUI functionalities
@testset "Test interactivity" verbose = true begin
    op_cost = [3371970.00359, 5382390.00598, 2010420.00219]
    inv_cost = [0.0, 0.0, 29536224.881975]
    @testset "Compare with Integrate results" begin
        T = get_time_struct(gui)
        m = EMGUI.get_model(gui)
        for (i, t) ∈ enumerate(strategic_periods(T))
            if haskey(m, :cap_capex)
                tot_capex_sp = sum(value.(m[:cap_capex][:, t])) / duration_strat(t)
                @test inv_cost[i] ≈ tot_capex_sp
            end
        end

        for (i, t) ∈ enumerate(strategic_periods(T))
            tot_opex_sp =
                sum(value.(m[:opex_fixed][:, t])) + sum(value.(m[:opex_var][:, t]))
            @test op_cost[i] ≈ tot_opex_sp
        end
    end

    # Test Expand all toggle functionality
    @testset "get_toggle(gui,:expand_all).active" begin
        # Check that sub-components are initially not plotted (as pre_plot_sub_components = false)
        @test all(isempty(get_plots(component)) for component ∈ get_components(area1))
        expand_all_toggle.active = true

        # Test if node n_El 1 became invisible
        expand_all_toggle.active = false
        n_el_1 = get_component(area1, "El 1") # fetch the n_El 1 node

        # Test if node n_El 1 became invisible
        @test !get_plots(n_el_1)[1].visible[]

        # Test if node n_El 1 became visible again
        expand_all_toggle.active = true
        @test get_plots(n_el_1)[1].visible[]

        # Check that that sub-components are now plotted
        @test all(!isempty(get_plots(component)) for component ∈ get_components(area1))
    end

    # Test simplified toggle functionality
    @testset "get_toggle(gui,:simplified).active" begin
        # Check that simplified plots are initially not plotted
        @test all(isempty(get_simplified_plots(connection)) for connection ∈ connections)
        @test all(
            isempty(get_simplified_plots(connection)) for component ∈ components for
            connection ∈ get_connections(component)
        )

        # Also check that all colors are regular colors
        test_all_connection_colors(gui, :regular_colors)

        # Activate simplified view (for expanded view - simplified for all levels)
        simplified_toggle.active = true
        test_all_connection_colors(gui, :black)

        # Deactivate simplified view
        simplified_toggle.active = false
        test_all_connection_colors(gui, :regular_colors)

        # deexpand
        expand_all_toggle.active = false
        pick_component!(gui, connections[1], :topo)
        update!(gui)
        simplified_toggle.active = true

        # Check that simplified plots are used only on the current level
        test_connections_colors(gui, connections, :black)
        test_connections_colors(gui, components, :regular_colors)

        pick_component!(gui, area1, :topo)
        notify(get_button(gui, :open).clicks)
        test_connections_colors(gui, get_connections(area1), :regular_colors)
        simplified_toggle.active = true
        test_connections_colors(gui, get_connections(area1), :black)

        # Test that the previous toggling did not affect other areas
        for area ∈ [area2, area3, area4]
            notify(get_button(gui, :up).clicks)
            pick_component!(gui, area, :topo)
            notify(get_button(gui, :open).clicks)
            test_connections_colors(gui, get_connections(area), :regular_colors)
            update!(gui)
        end
    end

    _, _, _, gui_2 = run_case_EMI_geography_2()
    design_2 = get_root_design(gui_2)
    components_2 = get_components(design_2)
    connections_2 = get_connections(design_2)
    simplified_toggle_2 = get_toggle(gui_2, :simplified)
    available_data_menu_2 = get_menu(gui_2, :available_data)

    # Test simplify_all_levels=true functionality
    @testset "Test simplify_all_levels=true functionality" begin
        # Check that simplified plots are used on all levels
        test_all_connection_colors(gui_2, :black)
        for area ∈ components_2
            pick_component!(gui_2, area, :topo)
            notify(get_button(gui_2, :open).clicks)
            test_connections_colors(gui_2, get_connections(area), :black)
            simplified_toggle_2.active = false
            test_connections_colors(gui_2, get_connections(area), :regular_colors)
            notify(get_button(gui_2, :up).clicks)
        end
        simplified_toggle_2.active = false
    end

    # Test color toggling
    @testset "Toggle colors" begin
        oslo = get_component(design_2, 1)
        pick_component!(gui_2, get_plots(oslo)[1], :topo)
        update!(gui_2)
        @test oslo.color[] == get_selection_color(gui_2)
        pick_component!(gui_2, nothing, :topo) # deselect
        @test oslo.color[] == EMGUI.BLACK

        pick_component!(gui_2, get_plots(oslo)[1], :topo)
        notify(get_button(gui_2, :open).clicks) # Open Oslo
        node2 = get_component(oslo, 1) # fetch node n_1
        pick_component!(gui_2, get_plots(node2)[1], :topo)
        update!(gui_2)
        @test node2.color[] == get_selection_color(gui_2)
        pick_component!(gui_2, nothing, :topo) # deselect
        @test node2.color[] == EMGUI.BLACK
        notify(get_button(gui_2, :up).clicks) # Go back to the top level

        connection1 = get_connections(design_2)[5] # fetch the Oslo - Trondheim transmission
        pick_component!(gui_2, get_plots(connection1)[2], :topo)
        update!(gui_2)
        test_connection_colors(gui_2, connection1, :selection_color)
        pick_component!(gui_2, nothing, :topo) # deselect
        update!(gui_2)
        test_connection_colors(gui_2, connection1, :regular_colors)
    end

    # Test data-menu labeling
    @testset "Test data-menu labeling" begin
        Oslo_Trondheim = connections_2[5]
        pick_component!(gui_2, Oslo_Trondheim, :topo) # Select Oslo - Trondheim transmission
        modes_OT = modes(Oslo_Trondheim)
        update!(gui_2)
        options = collect(available_data_menu_2.options[])
        for name ∈ ["trans_out", "trans_in", "trans_neg", "trans_pos", "trans_loss"]
            for trans_mode ∈ ["PowerLine_50_OT", "Coal_Transport_50_OT"]
                element = fetch_element(modes_OT, trans_mode)

                select_data!(gui_2, name; selection = [element])

                i_selected = available_data_menu_2.i_selected[]
                str = options[i_selected][2].description * " ($name) [$trans_mode]"
                @test options[i_selected][1] == str
            end
        end
    end
    EMGUI.close(gui_2)

    # Test the open button functionality
    @testset "get_button(gui,:open).clicks" begin
        pick_component!(gui, area1, :topo) # Select Area 1
        notify(get_button(gui, :open).clicks) # Open Area 1
        @test get_var(gui, :title)[] == "top_level.Area 1"
    end

    # Test the "back" button functionality
    @testset "get_button(gui,:up).clicks" begin
        notify(get_button(gui, :up).clicks) # Go back to the top level
        @test get_var(gui, :title)[] == "top_level"
    end

    # Test the align horz. button (aligning nodes horizontally)
    @testset "get_button(gui,:align_horizontal).clicks" begin
        pick_component!(gui, area1, :topo) # Select Area 1
        pick_component!(gui, area2, :topo) # Select Area 2
        notify(get_button(gui, :align_horizontal).clicks) # Align Area 1 and 2 horizontally
        @test get_xy(area1)[][2] == get_xy(area2)[][2]
    end

    # Test the align vert. button (aligning nodes horizontally)
    clear_selection!(gui, :topo)
    @testset "get_button(gui,:align_vertical).clicks" begin
        pick_component!(gui, area2, :topo) # Select Area 2
        pick_component!(gui, area3, :topo) # Select Area 3
        notify(get_button(gui, :align_vertical).clicks) # Align Area 2 and 3 vertically
        @test get_xy(area2)[][1] == get_xy(area3)[][1]
    end

    # Test the save button functionality
    @testset "get_button(gui,:save).clicks" begin
        design_folder = joinpath(pkgdir(EMGUI), "examples", "design", "case7")
        root_design.file = joinpath(design_folder, "test_top_level.yml")
        for (i_area, area_design) ∈ enumerate(components)
            area_design.file = joinpath(design_folder, "test_Area $i_area.yml")
        end
        notify(get_button(gui, :save).clicks) # click the save button
        area4_dict = YAML.load_file(joinpath(design_folder, "test_Area 4.yml"))
        solar_power = get_component(area4, "Solar Power")
        battery = get_component(area4, "Battery")
        @test area4_dict["n_Solar Power"]["x"] ≈ get_xy(solar_power)[][1] atol = 1e-5
        @test area4_dict["n_Battery"]["y"] ≈ get_xy(battery)[][2] atol = 1e-5

        # Clean up files
        rm(joinpath(design_folder, "test_top_level.yml"))
        for (i_area, area_design) ∈ enumerate(components)
            rm(joinpath(design_folder, "test_Area $i_area.yml"))
        end
    end

    # Test reset view button
    @testset "get_button(gui,:reset_view).clicks" begin
        change::EMGUI.Point2f = EMGUI.Point2f(1.3f0, -5.5f0)
        xy = components[3].xy
        xc::Float32 = xy[][1]
        yc::Float32 = xy[][2]

        xy[] = (xc + change[1], yc + change[2])

        update_sub_system_locations!(components[3], change)
        notify(get_button(gui, :reset_view).clicks) # Reset view
        @test true # Hard to have a test here that works on CI
    end

    # Run through all components
    @testset "Run through all components" begin
        run_through_all(gui; break_after_first = false)
        true
    end

    @testset "get_menu(gui,:period).i_selected" begin
        clear_selection!(gui, :topo)
        sub_component = get_component(area2, "Power supply") # fetch the n_Power supply node
        pick_component!(gui, sub_component, :topo)
        update!(gui)
        select_data!(gui, "cap_use")
        time_axis = time_menu.selection[]

        period_menu.i_selected = 1
        data_point = get_ax(gui, :results).scene.plots[1][1][][17][2]
        @test data_point ≈ 2.8f0 atol = 1e-5

        period_menu.i_selected = 2
        data_point = get_ax(gui, :results).scene.plots[1][1][][17][2]
        @test data_point ≈ 4.0f0 atol = 1e-5

        period_menu.i_selected = 3
        data_point = get_ax(gui, :results).scene.plots[1][1][][17][2]
        @test data_point ≈ 1.2f0 atol = 1e-5
    end

    @testset "get_menu(gui,:representative_period).i_selected" begin
        clear_selection!(gui, :topo)
        heating1 = get_component(area1, "Heating 1") # fetch the Heating 1 node
        pick_component!(gui, heating1, :topo)
        update!(gui)
        select_data!(gui, "flow_in")
        time_axis = time_menu.selection[]

        representative_period_menu.i_selected = 2
        notify(representative_period_menu.selection)
        data_point = get_ax(gui, :results).scene.plots[1][1][][10][2]
        @test data_point ≈ 0.2f0 atol = 1e-5

        representative_period_menu.i_selected = 1
        notify(representative_period_menu.selection)
        data_point = get_ax(gui, :results).scene.plots[1][1][][10][2]
        @test data_point ≈ 2.0f0 atol = 1e-5
    end

    @testset "get_menu(gui,:time).i_selected" begin
        # continue with the test from above
        # Show some data over representative periods
        select_data!(gui, "cap")

        # Show some data over strategic periods periods
        select_data!(gui, "penalty.deficit")

        # Show some data over strategic operational periods
        select_data!(gui, "flow_in")

        # Test data for representative periods
        ax = get_ax(gui, :results)
        time_menu.i_selected[] = 2
        data_points = vcat([p[1][] for p ∈ get_vis_plots(ax)]...)
        @test data_points[1][2] ≈ 2.0f0 atol = 1e-5
        @test data_points[2][2] ≈ 0.2f0 atol = 1e-5

        check_visibility(t) =
            all([x[:plot].visible[] for x ∈ get_plotted_data(gui) if x[:time_axis] == t])

        time_menu.i_selected[] = 1
        @test check_visibility(:results_sp) &&
              !check_visibility(:results_rp) &&
              check_visibility(:results_sc) &&
              !check_visibility(:results_op)
        time_menu.i_selected[] = 2
        @test !check_visibility(:results_sp) &&
              check_visibility(:results_rp) &&
              check_visibility(:results_sc) &&
              !check_visibility(:results_op)
        time_menu.i_selected[] = 3
        @test !check_visibility(:results_sp) &&
              !check_visibility(:results_rp) &&
              check_visibility(:results_sc) &&
              !check_visibility(:results_op)
        time_menu.i_selected[] = 4
        @test !check_visibility(:results_sp) &&
              !check_visibility(:results_rp) &&
              check_visibility(:results_sc) &&
              check_visibility(:results_op)
    end

    @testset "pin_plot_button.clicks" begin
        clear_selection!(gui, :topo)
        sub_component = get_component(area4, "Solar Power") # fetch the Solar Power node
        pick_component!(gui, sub_component, :topo)
        update!(gui)
        select_data!(gui, "profile")
        time_axis = time_menu.selection[]
        notify(pin_plot_button.clicks)
        sub_component2 = get_component(area3, "EV charger") # fetch the EV charger node
        pick_component!(gui, sub_component2, :topo) # Select Area 1
        update!(gui)
        select_data!(gui, "cap")
        notify(pin_plot_button.clicks)
        notify(pin_plot_button.clicks) # test redundant clicks
        data_point = get_ax(gui, :results).scene.plots[1][1][][5][2]
        @test data_point ≈ 0.25f0 atol = 1e-5
        data_point = get_ax(gui, :results).scene.plots[4][1][][5][2]
        @test data_point ≈ 0.6f0 atol = 1e-5
    end

    @testset "reset_view_results_button.clicks" begin
        ax_results = get_ax(gui, :results)
        width_x = ax_results.finallimits[].widths[1]
        origin_x = ax_results.finallimits[].origin[1]
        EMGUI.xlims!(ax_results, 1, 2)
        notify(get_button(gui, :reset_view_results).clicks)
        @test ax_results.finallimits[].widths[1] == width_x
        @test ax_results.finallimits[].origin[1] == origin_x
    end

    global_logger(logger_org)
    valid_combinations = Dict(
        "All" => ["jpg", "jpeg", "svg", "xlsx", "png", "lp", "mps"],
        "Plots" =>
            ["bmp", "tif", "tiff", "jpg", "jpeg", "svg", "xlsx", "png", "lp", "mps"],
        "Topo" => ["bmp", "tif", "tiff", "jpg", "jpeg", "svg", "png", "lp", "mps"],
    )
    @testset "get_button(gui,:export).clicks" begin
        tmpdir = mktempdir(testdir; prefix = "exported_files_")
        get_vars(gui)[:path_to_results] = tmpdir
        path = get_var(gui, :path_to_results)

        # Loop through all combinations of export options
        for i_axes ∈ range(1, length(axes_menu.options[]))
            println("i_axes = $i_axes")
            axes_menu.i_selected = i_axes
            for i_type ∈ range(1, length(export_type_menu.options[]))
                println("  i_type = $i_type")
                export_type_menu.i_selected = i_type
                axes_str = axes_menu.selection[]
                file_ending = export_type_menu.selection[]
                filename = joinpath(path, axes_str * "." * file_ending)
                if file_ending ∈ valid_combinations[axes_str]
                    msg = "Exported results to $filename"
                elseif file_ending == "REPL"
                    notify(get_button(gui, :export).clicks)
                    continue
                else
                    msg = "Exporting $(axes_str) to a $file_ending file is not supported"
                end
                @test_logs (:info, msg) EMGUI.export_to_file(gui)
            end
        end

        # Test if all valid files were created
        for (axes_str, file_endings) ∈ valid_combinations
            for file_ending ∈ file_endings
                @test isfile(joinpath(path, "$axes_str.$file_ending"))
            end
        end
    end
    global_logger(logger_new)

    @testset "get_button(gui,:remove_plot).clicks" begin
        time_axis = time_menu.selection[]
        element = get_visible_data(gui, time_axis)[1]
        pick_component!(gui, element, :results)

        notify(get_button(gui, :remove_plot).clicks)
        notify(get_button(gui, :remove_plot).clicks) # test redundant clicks
        @test !get_ax(gui, :results).scene.plots[1].visible[]
    end

    @testset "get_button(gui,:clear_all).clicks" begin
        clear_selection!(gui, :topo)
        update_available_data_menu!(gui, nothing) # Make sure the menu is updated
        select_data!(gui, "emissions_strategic")
        notify(pin_plot_button.clicks)
        select_data!(gui, "emissions_total")
        notify(pin_plot_button.clicks)
        notify(get_button(gui, :clear_all).clicks)
        time_axis = time_menu.selection[]
        @test all([!x.visible[] for x ∈ get_ax(gui, :results).scene.plots])
    end

    @testset "Test plotting of representative periods from JuMP" begin
        sub_component = get_component(area4, "Battery") # fetch the Battery node
        pick_component!(gui, sub_component, :topo)
        update!(gui)
        get_menu(gui, :period).i_selected = 3
        select_data!(gui, "stor_level_Δ_rp")
        @test get_ax(gui, :results).scene.plots[3][1][][1][2] ≈ -7.2 atol = 1e-5
        @test get_ax(gui, :results).scene.plots[3][1][][2][2] ≈ 7.2 atol = 1e-5
    end

    @testset "Test icon not found" begin
        id_to_icon_map = Dict("Battery" => "Battery icon") # Use a non-existing icon
        id_to_icon_map = set_icons(id_to_icon_map)
        products = get_products(case)
        nodes = get_nodes(case)
        links = get_links(case)
        areas = get_areas(case)
        transmissions = get_transmissions(case)
        test_sink = RefSink(
            "Test multiple sink products",
            FixedProfile(0),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e5)),
            Dict(products[1] => 1, products[2] => 1),
        )
        push!(nodes, test_sink)
        test_source = RefSource(
            "Test multiple source products",
            FixedProfile(0),
            FixedProfile(0),
            FixedProfile(0),
            Dict(products[1] => 1, products[2] => 1),
        )
        av = nodes[1]
        push!(nodes, test_source)
        push!(links, Direct("Link to test source", test_source, av, Linear()))
        push!(links, Direct("Link to test sink", av, test_sink, Linear()))
        case2 = Case(
            get_time_struct(case),
            products,
            [nodes, links, areas, transmissions],
            [[get_nodes, get_links], [get_areas, get_transmissions]],
        )
        gui2 = GUI(case2; id_to_icon_map, scenarios_labels = ["Scenario 1"])
        components2 = get_components(get_root_design(gui2))
        @test isempty(get_components(components2[4])[3].id_to_icon_map["Battery"])
        EMGUI.close(gui2)
    end

    ## Run a case with no representative periods nor scenarios
    @testset "Test SP(OP)" begin
        _, _, _, gui3 = run_test_case(; use_rp = false, use_sc = false)
        available_data_menu = get_menu(gui3, :available_data)

        # Test plotting over operational periods
        select_data!(gui3, "emissions_total")
        @test get_ax(gui3, :results).scene.plots[1][1][][24][2] ≈ 0.655 atol = 1e-5

        # Test plotting over strategic periods
        select_data!(gui3, "emissions_strategic")
        @test get_ax(gui3, :results).scene.plots[2][1][][3][2] ≈ 20799.525 atol = 1e-5
        EMGUI.close(gui3)
    end

    ## Run a case with scenarios but no representative periods
    @testset "Test SP(SC(OP))" begin
        case, model, m, gui3 = run_test_case(; use_rp = false, use_sc = true)
        available_data_menu = get_menu(gui3, :available_data)

        # Test plotting over operational periods
        select_data!(gui3, "emissions_total")
        get_menu(gui3, :scenario).i_selected = 4
        @test get_ax(gui3, :results).scene.plots[1][1][][24][2] ≈ 0.131 atol = 1e-5

        # Test plotting over strategic periods
        select_data!(gui3, "emissions_strategic")
        @test get_ax(gui3, :results).scene.plots[2][1][][3][2] ≈ 12937.30455 atol = 1e-5

        # Test plotting over scenarios
        sink = get_components(get_root_design(gui3))[2]
        pick_component!(gui3, sink, :topo)
        update!(gui3)
        select_data!(gui3, "penalty.deficit")
        @test get_ax(gui3, :results).scene.plots[3][1][][4][2] ≈ 200000 atol = 1e-5
        EMGUI.close(gui3)
    end

    ## Run a case with representative periods but no scenarios
    @testset "Test SP(RP(OP))" begin
        _, _, _, gui3 = run_test_case(; use_rp = true, use_sc = false)
        available_data_menu = get_menu(gui3, :available_data)
        ax_results = get_ax(gui3, :results)

        # Test plotting over operational periods
        select_data!(gui3, "emissions_total")
        get_menu(gui3, :representative_period).i_selected = 2
        @test ax_results.scene.plots[1][1][][24][2] ≈ 1.048 atol = 1e-5

        # Test plotting over strategic periods
        select_data!(gui3, "emissions_strategic")
        @test ax_results.scene.plots[2][1][][2][2] ≈ 20601.06 atol = 1e-5
        # Test plotting over representative periods
        get_menu(gui3, :period).i_selected = 3
        sink = get_components(get_root_design(gui3))[2]
        pick_component!(gui3, sink, :topo)
        update!(gui3)
        select_data!(gui3, "penalty.deficit")
        @test ax_results.scene.plots[3][1][][2][2] ≈ 2.0e6 atol = 1e-5
        EMGUI.close(gui3)
    end

    ## Run a case with representative periods and scenarios
    @testset "Test SP(RP(SC(OP)))" begin
        _, _, _, gui3 = run_test_case(; use_rp = true, use_sc = true)
        available_data_menu = get_menu(gui3, :available_data)
        ax_results = get_ax(gui3, :results)
        period_menu = get_menu(gui3, :period)
        representative_period_menu = get_menu(gui3, :representative_period)
        scenario_menu = get_menu(gui3, :scenario)

        # Test plotting over operational periods
        select_data!(gui3, "emissions_total")

        # Test updating menu with non-tensorial timestructure
        period_menu.i_selected = 3
        @test ax_results.scene.plots[1][1][][24][2] ≈ 1.965 atol = 1e-5

        representative_period_menu.i_selected = 2
        @test ax_results.scene.plots[1][1][][24][2] ≈ 1.2576 atol = 1e-5

        representative_period_menu.i_selected = 1
        @test ax_results.scene.plots[1][1][][24][2] ≈ 1.965 atol = 1e-5

        scenario_menu.i_selected = 4
        @test ax_results.scene.plots[1][1][][24][2] ≈ 0.393 atol = 1e-5

        period_menu.i_selected = 2
        @test ax_results.scene.plots[1][1][][24][2] ≈ 0.262 atol = 1e-5

        representative_period_menu.i_selected = 2
        @test ax_results.scene.plots[1][1][][24][2] ≈ 1.048 atol = 1e-5

        scenario_menu.i_selected = 3
        @test ax_results.scene.plots[1][1][][24][2] ≈ 0.4192 atol = 1e-5

        period_menu.i_selected = 1
        @test ax_results.scene.plots[1][1][][24][2] ≈ 0.1965 atol = 1e-5

        period_menu.i_selected = 3
        @test ax_results.scene.plots[1][1][][24][2] ≈ 0.9825 atol = 1e-5

        representative_period_menu.i_selected = 2
        @test ax_results.scene.plots[1][1][][24][2] ≈ 3.7728 atol = 1e-5

        # Test plotting over strategic periods
        select_data!(gui3, "emissions_strategic")
        @test ax_results.scene.plots[2][1][][2][2] ≈ 7648.6446 atol = 1e-5

        # Test plotting over scenarios
        sink = get_components(get_root_design(gui3))[2]
        pick_component!(gui3, sink, :topo)
        update!(gui3)
        select_data!(gui3, "penalty.deficit")
        @test ax_results.scene.plots[3][1][][2][2] ≈ 4.0e6 atol = 1e-5
        EMGUI.close(gui3)
    end
end
EMGUI.close(gui)
