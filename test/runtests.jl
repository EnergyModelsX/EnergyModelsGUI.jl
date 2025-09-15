using EnergyModelsGUI
using Test
using YAML
using GLMakie

const TEST_ATOL = 1e-6
const EMGUI = EnergyModelsGUI

# Include function that can loop through all components and plot its data
include("utils.jl")

# Include the code that generates example data
exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")
env = Base.active_project()
ENV["EMX_TEST"] = true # Set flag for example scripts to check if they are run as part of the tests
include(joinpath(exdir, "generate_examples.jl"))
Pkg.activate(env)
include("case7.jl")
include("example_test.jl")

# Add utilities needed for examples
include("../examples/utils.jl")

@testset "EnergyModelsGUI" verbose = true begin
    redirect_stdio(stdout = devnull) do
        # Run all Aqua tests
        include("Aqua.jl")

        # Check if there is need for formatting
        include("JuliaFormatter.jl")

        # The following tests simply checks if the main examples can be run without errors
        include("test_examples.jl")

        # The following tests results input and output functionality (saving and loading results)
        include("test_results_IO.jl")

        # Test specific GUI functionalities related to interactivity
        include("test_interactivity.jl")
    end
end
