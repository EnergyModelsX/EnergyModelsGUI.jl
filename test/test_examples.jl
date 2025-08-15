examples_for_results_from_file = Dict(
    "EMB_network.jl" => 0.0,
    "EMI_geography.jl" => 0.0,
    "EMR_hydro_power.jl" => 0.0,
)
exdir = joinpath(@__DIR__, "..", "examples")

@testset "Run examples" verbose = true begin
    files = first(walkdir(exdir))[3]
    for file ∈ files
        if splitext(file)[2] == ".jl" &&
           splitext(file)[1] != "utils" &&
           splitext(file)[1] != "generate_examples" &&
           !(file == "case7.jl") # Skip case7 as this is tested in test_interactivity.jl
            @testset "Example $file" begin
                @info "Run example $file"
                gui = include(joinpath(exdir, file))

                @test termination_status(EMGUI.get_model(gui)) == MOI.OPTIMAL

                if file ∈ keys(examples_for_results_from_file)
                    # Store objective value for later testing
                    examples_for_results_from_file[file] =
                        objective_value(EMGUI.get_model(gui))
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

        obj_value = examples_for_results_from_file[file]
        @test obj_value ≈ EMGUI.get_obj_value(EMGUI.get_model(gui)) atol = 1e-6
        EMGUI.close(gui)
    end
end

@testset "Test reading model results from files" verbose = true begin
    file = "EMB_network.jl"
    case, _ = generate_example_network()
    test_reading_results_from_file(file, case, examples_for_results_from_file)

    file = "EMI_geography.jl"
    case, model = generate_example_data_geo()
    test_reading_results_from_file(file, case, examples_for_results_from_file)

    file = "EMR_hydro_power.jl"
    case, model = generate_example_hp()
    test_reading_results_from_file(file, case, examples_for_results_from_file)
end
