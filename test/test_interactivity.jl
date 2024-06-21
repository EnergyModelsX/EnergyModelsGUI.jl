# Test specific GUI functionalities
@testset "Test interactivity" verbose = true begin
    # Test GUI functionalities with the case7 example
    include("../examples/case7.jl")

    # Test color toggling
    @testset "Toggle colors" begin
        area1 = gui.root_design.components[1] # fetch Area 1
        EMGUI.toggle_selection_color!(gui, area1, true)
        EMGUI.update!(gui)
        @test area1.color[] == gui.vars[:selection_color]
        EMGUI.toggle_selection_color!(gui, area1, false)
        @test area1.color[] == :black

        node2 = gui.root_design.components[1].components[2] # fetch node El 1
        EMGUI.toggle_selection_color!(gui, node2, true)
        EMGUI.update!(gui)
        @test node2.color[] == gui.vars[:selection_color]
        EMGUI.toggle_selection_color!(gui, node2, false)
        @test node2.color[] == :black

        connection1 = gui.root_design.connections[1] # fetch the Area 1 - Area 2 transmission
        EMGUI.toggle_selection_color!(gui, connection1, true)
        EMGUI.update!(gui)
        @test connection1.plots[1][][1].color[] == gui.vars[:selection_color]
        EMGUI.toggle_selection_color!(gui, connection1, false)
        @test connection1.plots[1][][1].color[] == connection1.colors[1]

        link1 = gui.root_design.components[1].connections[5] # fetch the link to heat pump
        EMGUI.toggle_selection_color!(gui, link1, true)
        EMGUI.update!(gui)
        @test link1.plots[1][][1].color[] == gui.vars[:selection_color]
        EMGUI.toggle_selection_color!(gui, link1, false)
        for plot ∈ link1.plots
            for (i, color) ∈ enumerate(link1.colors)
                @test plot[][i].color[] == color
            end
        end
    end

    # Test the open button functionality
    area1 = gui.root_design.components[1] # fetch Area 1
    @testset "gui.buttons[:open].clicks" begin
        push!(gui.vars[:selected_systems], area1) # Select Area 1
        notify(gui.buttons[:open].clicks) # Open Area 1
        @test gui.vars[:title][] == "top_level.Area 1"
    end

    # Test the "back" button functionality
    @testset "gui.buttons[:up].clicks" begin
        notify(gui.buttons[:up].clicks) # Go back to the top level
        @test gui.vars[:title][] == "top_level"
    end

    # Test the align horz. button (aligning nodes horizontally)
    area2 = gui.root_design.components[2] # fetch Area 2
    @testset "gui.buttons[:align_horizontal].clicks" begin
        push!(gui.vars[:selected_systems], area1) # Select Area 1
        push!(gui.vars[:selected_systems], area2) # Select Area 2
        notify(gui.buttons[:align_horizontal].clicks) # Align Area 1 and 2 horizontally
        @test gui.root_design.components[1].xy[][2] == gui.root_design.components[2].xy[][2]
    end

    # Test the align vert. button (aligning nodes horizontally)
    area3 = gui.root_design.components[3] # fetch Area 3
    empty!(gui.vars[:selected_systems])
    @testset "gui.buttons[:align_vertical].clicks" begin
        push!(gui.vars[:selected_systems], area2) # Select Area 1
        push!(gui.vars[:selected_systems], area3) # Select Area 3
        notify(gui.buttons[:align_vertical].clicks) # Align Area 2 and 3 vertically
        @test gui.root_design.components[2].xy[][1] == gui.root_design.components[3].xy[][1]
    end

    # Test the save button functionality
    @testset "gui.buttons[:save].clicks" begin
        design_folder = joinpath(@__DIR__, "..", "examples", "design", "case7")
        gui.root_design.file = joinpath(design_folder, "test_top_level.yml")
        for (i_area, area_design) ∈ enumerate(gui.root_design.components)
            area_design.file = joinpath(design_folder, "test_Area $i_area.yml")
        end
        notify(gui.buttons[:save].clicks) # click the save button
        area4_coords = YAML.load_file(joinpath(design_folder, "test_Area 4.yml"))
        @test area4_coords["n_Solar Power"]["x"] ≈
            gui.root_design.components[4].components[2].xy[][1] atol = 1e-5
        @test area4_coords["n_Battery"]["y"] ≈
            gui.root_design.components[4].components[3].xy[][2] atol = 1e-5

        # Clean up files
        rm(joinpath(design_folder, "test_top_level.yml"))
        for (i_area, area_design) ∈ enumerate(gui.root_design.components)
            rm(joinpath(design_folder, "test_Area $i_area.yml"))
        end
    end

    # Test reset view button
    @testset "gui.buttons[:reset_view].clicks" begin
        gui.root_design.components[3].xy[] = (-92.5, 37)
        notify(gui.buttons[:reset_view].clicks) # Reset view
        @test true # Hard to have a test here that works on CI
    end

    # Test Expand all toggle functionality
    @testset "gui.toggles[:expand_all].active" begin

        # Test if node n_El 1 became invisible
        gui.toggles[:expand_all].active = false
        @test !gui.design.components[1].components[2].plots[1].visible[]

        # Test if node n_El 1 became visible
        gui.toggles[:expand_all].active = true
        @test gui.design.components[1].components[2].plots[1].visible[]
    end

    ## Run through all components
    #@testset "Run through all components" begin
    #    run_through_all(gui; break_after_first=false)
    #    true
    #end

    @testset "gui.menus[:period].i_selected" begin
        empty!(gui.vars[:selected_systems])
        sub_component = gui.root_design.components[2].components[2] # fetch the n_Power supply node
        push!(gui.vars[:selected_systems], sub_component) # Manually add to :selected_systems
        EMGUI.update!(gui)
        available_data = [x[1] for x ∈ collect(gui.menus[:available_data].options[])]
        i_selected = findfirst(
            x -> x == "Absolute capacity utilization (cap_use)", available_data
        )
        gui.menus[:available_data].i_selected = i_selected # Select flow_out (CO2)
        time_axis = gui.menus[:time].selection[]

        gui.menus[:period].i_selected = 1
        data_point = gui.axes[time_axis].scene.plots[1][1][][35][2]
        @test data_point == 2.1003003f0

        gui.menus[:period].i_selected = 2
        data_point = gui.axes[time_axis].scene.plots[1][1][][35][2]
        @test data_point == 3.3003004f0

        gui.menus[:period].i_selected = 3
        data_point = gui.axes[time_axis].scene.plots[1][1][][35][2]
        @test data_point == 1.2f0
    end

    @testset "gui.menus[:representative_period].i_selected" begin
        empty!(gui.vars[:selected_systems])
        sub_component = gui.root_design.components[1].components[4] # fetch the Heating 1 node
        push!(gui.vars[:selected_systems], sub_component) # Manually add to :selected_systems
        EMGUI.update!(gui)
        available_data = [x[2][:name] for x ∈ collect(gui.menus[:available_data].options[])]
        i_selected = findfirst(x -> x == "flow_in", available_data)
        gui.menus[:available_data].i_selected = i_selected # Select flow_out (CO2)
        time_axis = gui.menus[:time].selection[]

        gui.menus[:representative_period].i_selected = 2
        notify(gui.menus[:representative_period].selection)
        data_point = gui.axes[time_axis].scene.plots[1][1][][10][2]
        @test data_point == 0.2f0

        gui.menus[:representative_period].i_selected = 1
        notify(gui.menus[:representative_period].selection)
        data_point = gui.axes[time_axis].scene.plots[1][1][][10][2]
        @test data_point == 2.0f0
    end

    @testset "gui.buttons[:pin_plot].clicks" begin
        empty!(gui.vars[:selected_systems])
        sub_component = gui.root_design.components[4].components[2] # fetch the Solar Power node
        push!(gui.vars[:selected_systems], sub_component) # Manually add to :selected_systems
        EMGUI.update!(gui)
        available_data = [x[2][:name] for x ∈ collect(gui.menus[:available_data].options[])]
        i_selected = findfirst(x -> x == "profile", available_data)
        gui.menus[:available_data].i_selected = i_selected # Select flow_out (CO2)
        time_axis = gui.menus[:time].selection[]
        notify(gui.buttons[:pin_plot].clicks)
        sub_component2 = gui.root_design.components[3].components[2] # fetch the EV charger node
        push!(gui.vars[:selected_systems], sub_component2) # Manually add to :selected_systems
        EMGUI.update!(gui)
        available_data = [x[2][:name] for x ∈ collect(gui.menus[:available_data].options[])]
        i_selected = findfirst(x -> x == "cap", available_data)
        gui.menus[:available_data].i_selected = i_selected # Select flow_out (CO2)
        notify(gui.buttons[:pin_plot].clicks)
        data_point = gui.axes[time_axis].scene.plots[1][1][][10][2]
        @test data_point == 0.25f0
        data_point = gui.axes[time_axis].scene.plots[2][1][][10][2]
        @test data_point == 0.6f0
    end

    @testset "gui.buttons[:export].clicks" begin
        # Loop through all combinations of export options
        path = gui.vars[:path_to_results]
        for i_axes ∈ range(1, length(gui.menus[:axes].options[]))
            gui.menus[:axes].i_selected = i_axes
            for i_type ∈ range(1, length(gui.menus[:export_type].options[]))
                gui.menus[:export_type].i_selected = i_type
                notify(gui.buttons[:export].clicks)
            end
        end
        for file_ending ∈ ["svg", "xlsx", "png", "lp", "mps"]
            @test isfile(joinpath(path, "All." * file_ending))
        end
        for file_ending ∈ ["bmp", "tif", "tiff", "jpg", "jpeg", "svg", "xlsx", "png"]
            @test isfile(joinpath(path, "Plots_results_op." * file_ending))
        end
    end

    @testset "gui.buttons[:remove_plot].clicks" begin
        time_axis = gui.menus[:time].selection[]
        push!(gui.vars[:selected_plots], gui.vars[:visible_plots][time_axis][1])
        notify(gui.buttons[:remove_plot].clicks)
        @test !gui.axes[time_axis].scene.plots[1].visible[]
    end

    @testset "gui.buttons[:clear_all].clicks" begin
        empty!(gui.vars[:selected_systems])
        EMGUI.update_available_data_menu!(gui, nothing) # Make sure the menu is updated
        available_data = [x[2][:name] for x ∈ collect(gui.menus[:available_data].options[])]
        i_selected = findfirst(x -> x == "emissions_strategic", available_data)
        gui.menus[:available_data].i_selected = i_selected # Select emission_strategic (NG)
        notify(gui.buttons[:pin_plot].clicks)
        i_selected = findfirst(x -> x == "emissions_total", available_data)
        gui.menus[:available_data].i_selected = i_selected # Select emissions_total (NG)
        notify(gui.buttons[:pin_plot].clicks)
        notify(gui.buttons[:clear_all].clicks)
        time_axis = gui.menus[:time].selection[]
        @test all([!x.visible[] for x ∈ gui.axes[time_axis].scene.plots])
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
        gui = GUI(case; id_to_icon_map, scenarios_labels=["Scenario 1"])
        @test isempty(gui.root_design.components[4].components[3].id_to_icon_map["Battery"])
    end
end
