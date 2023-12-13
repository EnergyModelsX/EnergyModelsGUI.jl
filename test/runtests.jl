using EnergyModelsGUI
using Test

@testset "EnergyModelsGUI.jl" begin
    @test begin
        x,y = EnergyModelsGUI.place_nodes_in_semicircle(7, 2, 1.1, 10.2, 60.06)
        x ≈ 9.247372055837117 && y ≈ 60.61
    end
end
