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

@testset "Test reading PeriodPartition results from files" verbose = true begin
    directory = joinpath(tmpdir, "case7")
    if !ispath(directory)
        mkdir(directory)
    end

    # Save the results of case7 (including variables indexed over `PeriodPartition`s)
    case, model, m, gui_jump = run_case()
    EMGUI.save_results(m; directory)
    df_csv = CSV.read(joinpath(directory, "demand_sink_deficit.csv"), DataFrame)
    @test "pd" ∈ names(df_csv)

    # Generate the GUI from saved files
    gui = GUI(case; model = directory)
    m_df = EMGUI.get_model(gui)
    T = EMGUI.get_time_struct(gui)
    @test eltype(m_df[:demand_sink_deficit][!, :t]) <: TimeStruct.PeriodPartition

    # Test that all variables have the expected values
    for var ∈ EMGUI.get_JuMP_names(gui)
        if !isempty(m[var])
            vals = vec(EMGUI.get_values(m[var]))
            @test length(vals) == length(EMGUI.get_values(m_df[var]))
            @test all(isapprox.(vals, EMGUI.get_values(m_df[var]), atol = TEST_ATOL))
        end
    end

    # Test that the partition data is identical to the data of the GUI using the JuMP model
    area1 = get_component(get_components(get_root_design(gui)), "area1")
    hot_water = get_element(get_component(area1, "Hot water 1"))
    el_1 = get_element(get_component(area1, "El 1"))
    @test EMGUI.has_partition_data(gui, hot_water)
    @test !EMGUI.has_partition_data(gui, el_1)
    available_data_jump = EMGUI.get_available_data(gui_jump)[hot_water]
    available_data_csv = EMGUI.get_available_data(gui)[hot_water]
    for var ∈ ["demand_sink_deficit", "demand_sink_surplus"]
        is_var = x -> EMGUI.get_name(x) == var
        container_jump = EMGUI.getfirst(is_var, available_data_jump)
        container_csv = EMGUI.getfirst(is_var, available_data_csv)
        @test EMGUI.is_partition_data(container_csv)
        for sp ∈ 1:3, rp ∈ 1:2
            pds_jump, vals_jump, ax_jump = EMGUI.get_data(m, container_jump, T, sp, rp, 1)
            pds_csv, vals_csv, ax_csv = EMGUI.get_data(m_df, container_csv, T, sp, rp, 1)
            @test ax_csv == ax_jump == :results_pt
            @test string.(pds_csv) == string.(pds_jump)
            @test vals_csv ≈ vals_jump atol = TEST_ATOL
        end
    end

    # Test that elements without partitions are highlighted
    @test_logs (:warn, r"El 1") EMGUI.period_partitions(el_1, T)

    EMGUI.close(gui)
    EMGUI.close(gui_jump)
end
