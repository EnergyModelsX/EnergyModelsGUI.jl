tmpdir = mktempdir(@__DIR__; prefix = "exported_files_")

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
