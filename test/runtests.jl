using EnergyModelsGUI
using Test
using YAML

const TEST_ATOL = 1e-6
const EMGUI = EnergyModelsGUI

# Include function that can loop through all components and plot its data
include("utils.jl")

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

        # Test miscellaneous functionalities
        include("test_functionality.jl")

        # Test specific GUI functionalities related to interactivity
        include("test_interactivity.jl")
    end
end
