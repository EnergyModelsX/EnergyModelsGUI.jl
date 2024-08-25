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
            end
        end
    end
end
