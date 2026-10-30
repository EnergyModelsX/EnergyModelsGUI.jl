# Runs all examples in the examples environment. This file is started in a separate process
# by `test_examples.jl` and is not part of the test environment.
using Test

# Prepare the examples environment before loading EnergyModelsGUI from it
exdir = joinpath(@__DIR__, "..", "examples")
include(joinpath(exdir, "generate_examples.jl"))

using EnergyModelsGUI
const EMGUI = EnergyModelsGUI

@testset "Run examples" verbose = true begin
    files = first(walkdir(exdir))[3]
    for file ∈ files
        if splitext(file)[2] == ".jl" && splitext(file)[1] != "generate_examples"
            @testset "Example $file" begin
                @info "Run example $file"
                gui = include(joinpath(exdir, file))

                @test termination_status(EMGUI.get_model(gui)) == MOI.OPTIMAL

                EMGUI.close(gui)
            end
        end
    end
end
