examples_for_results_from_file = Dict(
    "EMB_network.jl" => Dict(),
    "EMI_geography.jl" => Dict(),
    "EMR_hydro_power.jl" => Dict(),
)
exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")

@testset "Run examples" verbose = true begin
    files = first(walkdir(exdir))[3]
    for file ∈ files
        if splitext(file)[2] == ".jl" &&
           splitext(file)[1] != "utils" &&
           splitext(file)[1] != "generate_examples"
            @testset "Example $file" begin
                @info "Run example $file"
                gui = include(joinpath(exdir, file))

                @test termination_status(EMGUI.get_model(gui)) == MOI.OPTIMAL

                if file ∈ keys(examples_for_results_from_file)
                    # Store objective value for later testing
                    m = EMGUI.get_model(gui)
                    examples_for_results_from_file[file]["vars"] = Dict(
                        var => vec(EMGUI.get_values(m[var])) for
                        var ∈ EMGUI.get_JuMP_names(gui) if !isempty(m[var])
                    )
                    examples_for_results_from_file[file]["objective_value"] =
                        objective_value(m)
                    directory = joinpath(@__DIR__, "exported_files", splitext(file)[1])
                    if !ispath(directory)
                        mkpath(directory)
                    end

                    # Save results for later testing
                    EMGUI.save_results(EMGUI.get_model(gui); directory)
                end
                EMGUI.close(gui)
            end
        end
    end
end

function test_reading_results_from_file(file, case, examples_for_results_from_file)
    @testset "Example $file" begin
        directory = joinpath(@__DIR__, "exported_files", splitext(file)[1])
        @info "Test reading results from files in the $file case"
        gui = GUI(case; model = directory)

        # Test the value of the objective function
        obj_value = examples_for_results_from_file[file]["objective_value"]
        m = EMGUI.get_model(gui)
        @test obj_value ≈ EMGUI.get_obj_value(m) atol = 1e-6

        # Test that all variables have the expected values
        for (key, vals) ∈ examples_for_results_from_file[file]["vars"]
            @test all(isapprox.(vals, EMGUI.get_values(m[key]), atol = 1e-6))
        end
        EMGUI.close(gui)
    end
end

@testset "Test reading model results from files" verbose = true begin
    file = "EMB_network.jl"
    case, _ = generate_example_network()
    test_reading_results_from_file(file, case, examples_for_results_from_file)

    file = "EMI_geography.jl"
    case, _ = generate_example_data_geo()
    test_reading_results_from_file(file, case, examples_for_results_from_file)

    file = "EMR_hydro_power.jl"
    case, _ = generate_example_hp()
    test_reading_results_from_file(file, case, examples_for_results_from_file)
end
