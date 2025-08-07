using JuliaFormatter

@testset "JuliaFormatter.jl" begin
    @test begin
        format(joinpath(@__DIR__, ".."))
    end
end
