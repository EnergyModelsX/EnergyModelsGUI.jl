@testset "Run examples" verbose = true begin
    exdir = joinpath(@__DIR__, "..", "examples")
    files = first(walkdir(exdir))[3]
    for file ∈ files
        if splitext(file)[2] == ".jl" &&
           splitext(file)[1] != "utils" &&
           !(file == "case7.jl") # Skip case7 as this is tested in test_interactivity.jl
            @testset "Example $file" begin
                @info "Run example $file"
                include(joinpath(exdir, file))

                @test termination_status(m) == MOI.OPTIMAL

                if file ∈ ["EMB_network.jl", "EMI_geography.jl", "EMR_hydro_power.jl"]
                    @info "Test reading results from files in the $file case"
                    # Test reading model results from files
                    obj_value = objective_value(m)
                    directory = joinpath(@__DIR__, "exported_files", splitext(file)[1])
                    if !ispath(directory)
                        mkpath(directory)
                    end
                    EMGUI.save_results(EMGUI.get_model(gui); directory)
                    gui = GUI(case; model = directory)

                    @test obj_value ≈ EMGUI.get_obj_value(EMGUI.get_model(gui)) atol = 1e-6
                end
            end
        end
    end
end
