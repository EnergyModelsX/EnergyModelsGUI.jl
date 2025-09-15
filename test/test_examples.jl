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

                EMGUI.close(gui)
            end
        end
    end
    Pkg.activate(env)
end
