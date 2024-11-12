import EnergyModelsGUI:
    get_root_design,
    get_components,
    get_connections,
    get_menu,
    get_button,
    update!,
    toggle_selection_color!,
    get_plots,
    get_selection_color,
    get_selected_systems,
    get_selected_plots,
    get_visible_data,
    get_var,
    get_xy,
    get_toggle,
    get_ax,
    update_info_box!,
    update_available_data_menu!,
    update_sub_system_locations!,
    pick_component!,
    clear_selection,
    get_design,
    get_vis_plots,
    get_plotted_data,
    select_data!

# Test specific GUI functionalities
@testset "Test interactivity" verbose = true begin
    # Test GUI interactivity with the case7 example
    include("../examples/case7.jl")

    case, model, m, gui = run_case()

    op_cost = [3371970.00359, 5382390.00598, 2010420.00219]
    inv_cost = [0.0, 0.0, 29536224.881975]
    @testset "Compare with Integrate results" begin
        T = get_design(gui).system[:T]
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
    root_design = get_root_design(gui)
    components = get_components(root_design)
    connections = get_connections(root_design)

    time_menu = get_menu(gui, :time)
    available_data_menu = get_menu(gui, :available_data)
    period_menu = get_menu(gui, :period)
    representative_period_menu = get_menu(gui, :representative_period)
    export_type_menu = get_menu(gui, :export_type)
    axes_menu = get_menu(gui, :axes)

    pin_plot_button = get_button(gui, :pin_plot)

    # Test color toggling
    @testset "Toggle colors" begin
        area1 = components[1] # fetch Area 1
        plt_area1 = area1.plots[1]
        pick_component!(gui, plt_area1; pick_topo_component=true)
        update!(gui)
        @test area1.color[] == get_selection_color(gui)
        pick_component!(gui, nothing; pick_topo_component=true)
        @test area1.color[] == :black

        node2 = get_components(components[1])[2] # fetch node El 1
        plt_node2 = node2.plots[1]
        pick_component!(gui, plt_node2; pick_topo_component=true)
        update!(gui)
        @test node2.color[] == get_selection_color(gui)
        pick_component!(gui, nothing; pick_topo_component=true)
        @test node2.color[] == :black

        connection1 = connections[1] # fetch the Area 1 - Area 2 transmission
        plt_connection1 = connection1.plots[1][][1]
        pick_component!(gui, plt_connection1; pick_topo_component=true)
        update!(gui)
        @test get_plots(connection1)[1][][1].color[] == get_selection_color(gui)
        pick_component!(gui, nothing; pick_topo_component=true)
        @test get_plots(connection1)[1][][1].color[] == connection1.colors[1]

        link1 = get_connections(components[1])[5] # fetch the link to heat pump
        plt_link1 = link1.plots[1][][1]
        pick_component!(gui, plt_link1; pick_topo_component=true)
        update!(gui)
        @test get_plots(link1)[1][][1].color[] == get_selection_color(gui)
        pick_component!(gui, nothing; pick_topo_component=true)
        for plot ∈ link1.plots
            for (i, color) ∈ enumerate(link1.colors)
                @test plot[][i].color[] == color
            end
        end
    end

    # Test the open button functionality
    area1 = components[1] # fetch Area 1
    @testset "get_button(gui,:open).clicks" begin
        pick_component!(gui, area1; pick_topo_component=true) # Select Area 1
        notify(get_button(gui, :open).clicks) # Open Area 1
        @test get_var(gui, :title)[] == "top_level.Area 1"
    end

    # Test the "back" button functionality
    @testset "get_button(gui,:up).clicks" begin
        notify(get_button(gui, :up).clicks) # Go back to the top level
        @test get_var(gui, :title)[] == "top_level"
    end

    # Test the align horz. button (aligning nodes horizontally)
    area2 = components[2] # fetch Area 2
    @testset "get_button(gui,:align_horizontal).clicks" begin
        pick_component!(gui, area1; pick_topo_component=true) # Select Area 1
        pick_component!(gui, area2; pick_topo_component=true) # Select Area 2
        notify(get_button(gui, :align_horizontal).clicks) # Align Area 1 and 2 horizontally
        @test get_xy(components[1])[][2] == get_xy(components[2])[][2]
    end

    # Test the align vert. button (aligning nodes horizontally)
    area3 = components[3] # fetch Area 3
    clear_selection(gui; clear_topo=true)
    @testset "get_button(gui,:align_vertical).clicks" begin
        pick_component!(gui, area2; pick_topo_component=true) # Select Area 2
        pick_component!(gui, area3; pick_topo_component=true) # Select Area 3
        notify(get_button(gui, :align_vertical).clicks) # Align Area 2 and 3 vertically
        @test get_xy(components[2])[][1] == get_xy(components[3])[][1]
    end

    # Test the save button functionality
    @testset "get_button(gui,:save).clicks" begin
        design_folder = joinpath(@__DIR__, "..", "examples", "design", "case7")
        root_design.file = joinpath(design_folder, "test_top_level.yml")
        for (i_area, area_design) ∈ enumerate(components)
            area_design.file = joinpath(design_folder, "test_Area $i_area.yml")
        end
        notify(get_button(gui, :save).clicks) # click the save button
        area4_dict = YAML.load_file(joinpath(design_folder, "test_Area 4.yml"))
        sub_components = get_components(components[4])
        @test area4_dict["n_Solar Power"]["x"] ≈ get_xy(sub_components[2])[][1] atol = 1e-5
        @test area4_dict["n_Battery"]["y"] ≈ get_xy(sub_components[3])[][2] atol = 1e-5

        # Clean up files
        rm(joinpath(design_folder, "test_top_level.yml"))
        for (i_area, area_design) ∈ enumerate(components)
            rm(joinpath(design_folder, "test_Area $i_area.yml"))
        end
    end

    # Test reset view button
    @testset "get_button(gui,:reset_view).clicks" begin
        change::Tuple{Real,Real} = (1.3, -5.5)
        xy = components[3].xy
        xc::Real = xy[][1]
        yc::Real = xy[][2]

        xy[] = (xc + change[1], yc + change[2])

        update_sub_system_locations!(components[3], change)
        notify(get_button(gui, :reset_view).clicks) # Reset view
        @test true # Hard to have a test here that works on CI
    end

    # Test Expand all toggle functionality
    @testset "get_toggle(gui,:expand_all).active" begin
        # Test if node n_El 1 became invisible
        get_toggle(gui, :expand_all).active = false
        sub_components = get_components(components[1])
        @test !get_plots(sub_components[2])[1].visible[]

        # Test if node n_El 1 became visible
        get_toggle(gui, :expand_all).active = true
        @test get_plots(sub_components[2])[1].visible[]
    end

    # Run through all components
    @testset "Run through all components" begin
        run_through_all(gui; break_after_first=false)
        true
    end

    @testset "get_menu(gui,:period).i_selected" begin
        clear_selection(gui; clear_topo=true)
        sub_component = get_components(components[2])[2] # fetch the n_Power supply node
        pick_component!(gui, sub_component; pick_topo_component=true)
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
        clear_selection(gui; clear_topo=true)
        sub_component = get_components(components[1])[4] # fetch the Heating 1 node
        pick_component!(gui, sub_component; pick_topo_component=true)
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
        clear_selection(gui; clear_topo=true)
        sub_component = get_components(components[4])[2] # fetch the Solar Power node
        pick_component!(gui, sub_component; pick_topo_component=true)
        update!(gui)
        select_data!(gui, "profile")
        time_axis = time_menu.selection[]
        notify(pin_plot_button.clicks)
        sub_component2 = components[3].components[2] # fetch the EV charger node
        pick_component!(gui, sub_component2; pick_topo_component=true) # Select Area 1
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

    @testset "get_button(gui,:export).clicks" begin
        # Loop through all combinations of export options
        path = get_var(gui, :path_to_results)
        for i_axes ∈ range(1, length(axes_menu.options[]))
            axes_menu.i_selected = i_axes
            for i_type ∈ range(1, length(export_type_menu.options[]))
                export_type_menu.i_selected = i_type
                notify(get_button(gui, :export).clicks)
            end
        end
        for file_ending ∈ ["svg", "xlsx", "png", "lp", "mps"]
            @test isfile(joinpath(path, "All." * file_ending))
        end
        for file_ending ∈ ["bmp", "tif", "tiff", "jpg", "jpeg", "svg", "xlsx", "png"]
            @test isfile(joinpath(path, "results." * file_ending))
        end
        for file_ending ∈ ["svg"]
            @test isfile(joinpath(path, "topo." * file_ending))
        end
    end

    @testset "get_button(gui,:remove_plot).clicks" begin
        time_axis = time_menu.selection[]
        element = get_visible_data(gui, time_axis)[1]
        pick_component!(gui, element; pick_results_component=true)

        notify(get_button(gui, :remove_plot).clicks)
        notify(get_button(gui, :remove_plot).clicks) # test redundant clicks
        @test !get_ax(gui, :results).scene.plots[1].visible[]
    end

    @testset "get_button(gui,:clear_all).clicks" begin
        clear_selection(gui; clear_topo=true)
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
        sub_component = get_components(components[4])[3] # fetch the Battery node
        pick_component!(gui, sub_component; pick_topo_component=true)
        update!(gui)
        get_menu(gui, :period).i_selected = 3
        select_data!(gui, "stor_level_Δ_rp")
        @test get_ax(gui, :results).scene.plots[3][1][][1][2] ≈ -7.2 atol = 1e-5
        @test get_ax(gui, :results).scene.plots[3][1][][2][2] ≈ 7.2 atol = 1e-5
    end

    @testset "Test icon not found" begin
        id_to_icon_map = Dict("Battery" => "Battery icon") # Use a non-existing icon
        id_to_icon_map = set_icons(id_to_icon_map)
        products = case[:products]
        test_sink = RefSink(
            "Test multiple sink products",
            FixedProfile(0),
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e5)),
            Dict(products[1] => 1, products[2] => 1),
        )
        push!(case[:nodes], test_sink)
        test_source = RefSource(
            "Test multiple source products",
            FixedProfile(0),
            FixedProfile(0),
            FixedProfile(0),
            Dict(products[1] => 1, products[2] => 1),
        )
        av = case[:nodes][1]
        push!(case[:nodes], test_source)
        push!(case[:links], Direct("Link to test source", test_source, av, Linear()))
        push!(case[:links], Direct("Link to test sink", av, test_sink, Linear()))
        gui = GUI(case; id_to_icon_map=id_to_icon_map, scenarios_labels=["Scenario 1"])
        components = get_components(get_root_design(gui))
        @test isempty(get_components(components[4])[3].id_to_icon_map["Battery"])
    end

    # Test GUI interactivity with the example_test for different time structures
    include("example_test.jl")

    ## Run a case with no representative periods nor scenarios
    case, model, m, gui = run_case(; use_rp=false, use_sc=false)
    available_data_menu = get_menu(gui, :available_data)
    @testset "Test SP(OP)" begin

        # Test plotting over operational periods
        select_data!(gui, "emissions_total")
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 0.655 atol = 1e-5

        # Test plotting over strategic periods
        select_data!(gui, "emissions_strategic")
        @test get_ax(gui, :results).scene.plots[2][1][][3][2] ≈ 20799.525 atol = 1e-5
    end

    ## Run a case with scenarios but no representative periods
    case, model, m, gui = run_case(; use_rp=false, use_sc=true)
    available_data_menu = get_menu(gui, :available_data)
    @testset "Test SP(SC(OP))" begin
        # Test plotting over operational periods
        select_data!(gui, "emissions_total")
        get_menu(gui, :scenario).i_selected = 4
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 0.131 atol = 1e-5

        # Test plotting over strategic periods
        select_data!(gui, "emissions_strategic")
        @test get_ax(gui, :results).scene.plots[2][1][][3][2] ≈ 12937.30455 atol = 1e-5

        # Test plotting over scenarios
        sink = get_components(get_root_design(gui))[2]
        pick_component!(gui, sink; pick_topo_component=true)
        update!(gui)
        select_data!(gui, "penalty.deficit")
        @test get_ax(gui, :results).scene.plots[3][1][][4][2] ≈ 200000 atol = 1e-5
    end

    ## Run a case with representative periods but no scenarios
    case, model, m, gui = run_case(; use_rp=true, use_sc=false)
    available_data_menu = get_menu(gui, :available_data)
    @testset "Test SP(RP(OP))" begin
        # Test plotting over operational periods
        select_data!(gui, "emissions_total")
        get_menu(gui, :representative_period).i_selected = 2
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 1.048 atol = 1e-5

        # Test plotting over strategic periods
        select_data!(gui, "emissions_strategic")
        @test get_ax(gui, :results).scene.plots[2][1][][2][2] ≈ 20601.06 atol = 1e-5

        # Test plotting over representative periods
        get_menu(gui, :period).i_selected = 3
        sink = get_components(get_root_design(gui))[2]
        pick_component!(gui, sink; pick_topo_component=true)
        update!(gui)
        select_data!(gui, "penalty.deficit")
        @test get_ax(gui, :results).scene.plots[3][1][][2][2] ≈ 2.0e6 atol = 1e-5
    end

    ## Run a case with representative periods and scenarios
    case, model, m, gui = run_case(; use_rp=true, use_sc=true)
    available_data_menu = get_menu(gui, :available_data)

    @testset "Test SP(RP(SC(OP)))" begin
        # Test plotting over operational periods
        select_data!(gui, "emissions_total")

        # Test updating menu with non-tensorial timestructure
        get_menu(gui, :period).i_selected = 3
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 1.965 atol = 1e-5
        get_menu(gui, :representative_period).i_selected = 2
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 1.2576 atol = 1e-5
        get_menu(gui, :representative_period).i_selected = 1
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 1.965 atol = 1e-5
        get_menu(gui, :scenario).i_selected = 4
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 0.393 atol = 1e-5
        get_menu(gui, :period).i_selected = 2
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 0.262 atol = 1e-5
        get_menu(gui, :representative_period).i_selected = 2
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 1.048 atol = 1e-5
        get_menu(gui, :scenario).i_selected = 3
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 0.4192 atol = 1e-5
        get_menu(gui, :period).i_selected = 1
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 0.1965 atol = 1e-5

        get_menu(gui, :period).i_selected = 3
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 0.9825 atol = 1e-5
        get_menu(gui, :representative_period).i_selected = 2
        @test get_ax(gui, :results).scene.plots[1][1][][24][2] ≈ 3.7728 atol = 1e-5

        # Test plotting over strategic periods
        select_data!(gui, "emissions_strategic")
        @test get_ax(gui, :results).scene.plots[2][1][][2][2] ≈ 7648.6446 atol = 1e-5

        # Test plotting over scenarios
        sink = get_components(get_root_design(gui))[2]
        pick_component!(gui, sink; pick_topo_component=true)
        update!(gui)
        select_data!(gui, "penalty.deficit")
        @test get_ax(gui, :results).scene.plots[3][1][][2][2] ≈ 4.0e6 atol = 1e-5
    end
end
