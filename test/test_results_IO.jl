tmpdir = mktempdir(testdir; prefix = "exported_files_")

function get_case(file)
    if file == "EMB_network.jl"
        case, model = generate_example_network()
    elseif file == "EMI_geography.jl"
        case, model = generate_example_data_geo()
    elseif file == "EMR_hydro_power.jl"
        case, model = generate_example_hp()
    end
    return case, model
end

@testset "Test reading model results from files" verbose = true begin
    for file ∈ ["EMB_network.jl", "EMI_geography.jl", "EMR_hydro_power.jl"]
        directory = joinpath(tmpdir, splitext(file)[1])
        if !ispath(directory)
            mkdir(directory)
        end

        # Save results for later testing
        case, model = get_case(file)
        optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
        m = run_model(case, model, optimizer)

        # Save results
        EMGUI.save_results(m; directory)

        # Generate the GUI from saved files
        gui = GUI(case; model = directory)

        # Test the value of the objective function
        obj_value = objective_value(m)
        m_df = EMGUI.get_model(gui)
        @test obj_value ≈ EMGUI.get_obj_value(m_df) atol = 1e-6

        # Test that all variables have the expected values
        for var ∈ EMGUI.get_JuMP_names(gui)
            if !isempty(m[var])
                vals = vec(EMGUI.get_values(m[var]))
                @test all(isapprox.(vals, EMGUI.get_values(m_df[var]), atol = 1e-6))
            end
        end
        EMGUI.close(gui)
    end
end

@testset "Test reading additional plot data from files" verbose = true begin
    # Read the case and model data from previous test
    file = "EMB_network.jl"
    directory = joinpath(tmpdir, splitext(file)[1])
    case, model = get_case(file)

    # Create additional plot data and save it to a CSV file
    test_additional_plots_dir = joinpath(tmpdir, "test_additional_plots")
    if !ispath(test_additional_plots_dir)
        mkdir(test_additional_plots_dir)
    end
    cap_use_path = joinpath(directory, "cap_use.csv")
    additional_data = CSV.read(cap_use_path, DataFrame)
    additional_data.val = Float64.(additional_data.val)
    additional_data = unstack(
        additional_data,
        Not([:element, :val]),
        :element,
        :val;
        fill = NaN,
    )
    cap_use_unstacked_path = joinpath(test_additional_plots_dir, "cap_use_unstacked.csv")
    CSV.write(cap_use_unstacked_path, additional_data)

    # Generate the GUI with the additional plot
    gui = GUI(case;
        model = directory,
        additional_plots = [
            Dict("data" => additional_data, "normalize" => true),
            Dict("data" => cap_use_unstacked_path, "normalize" => true),
        ],
    )

    pin_plot_button = get_button(gui, :pin_plot)
    available_data_menu = get_menu(gui, :available_data)

    for node_name ∈ ["NG source", "electricity demand"]
        clear_selection!(gui, :topo)
        notify(get_button(gui, :clear_all).clicks)
        node = get_component(get_root_design(gui), node_name)
        pick_component!(gui, node, :topo)
        update!(gui)
        select_data!(gui, "cap_use")
        data_points = get_ax(gui, :results).scene.plots[1][1][]
        ref_values = [data_point[2] for data_point ∈ data_points]

        # normalize
        ref_values ./= maximum(ref_values)

        # Select the additional data
        clear_selection!(gui, :topo)
        select_data!(gui, "n_$(node_name)")
        notify(pin_plot_button.clicks)
        select_data!(gui, "n_$(node_name)"; fun = findlast)
        data_points_dataframe = get_ax(gui, :results).scene.plots[1][1][]
        data_points_csv = get_ax(gui, :results).scene.plots[2][1][]

        for data_points ∈ [data_points_dataframe, data_points_csv]
            values = [data_point[2] for data_point ∈ data_points]
            values ./= maximum(values)
            @test all(isapprox.(values, ref_values, atol = 1e-6))
        end
    end

    EMGUI.close(gui)
end
