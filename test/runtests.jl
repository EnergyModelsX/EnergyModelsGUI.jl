using EnergyModelsGUI
using Test
using YAML
using Logging

const TEST_ATOL = 1e-6
const EMGUI = EnergyModelsGUI

pkg_dir = pkgdir(EnergyModelsGUI)
exdir = joinpath(pkg_dir, "examples")
testdir = joinpath(pkg_dir, "test")

# Include function that can loop through all components and plot its data
include(joinpath(testdir, "utils.jl"))

# Include the code that generates example data
env = Base.active_project()
ENV["EMX_TEST"] = true # Set flag for example scripts to check if they are run as part of the tests
include(joinpath(exdir, "generate_examples.jl"))
Pkg.activate(env)
include(joinpath(testdir, "case7.jl"))
include(joinpath(testdir, "example_test.jl"))

# Add utilities needed for examples
include(joinpath(exdir, "utils.jl"))

logger_org = global_logger()
logger_new = ConsoleLogger(stderr, Logging.Warn)
global_logger(logger_new)

@testset "EnergyModelsGUI" verbose = true begin
    redirect_stdio(stdout = devnull) do
        # Run all Aqua tests
        include(joinpath(testdir, "Aqua.jl"))

        # Check if there is need for formatting
        include(joinpath(testdir, "JuliaFormatter.jl"))

        # The following tests simply checks if the main examples can be run without errors
        include(joinpath(testdir, "test_examples.jl"))

        # The following tests results input and output functionality (saving and loading results)
        include(joinpath(testdir, "test_results_IO.jl"))

        # Test Base.show() functionalities
        include(joinpath(testdir, "test_show.jl"))

        # Test specific GUI functionalities related to interactivity
        include(joinpath(testdir, "test_interactivity.jl"))

        # Test descriptive names functionalities
        include(joinpath(testdir, "test_descriptive_names.jl"))
    end
end
global_logger(logger_org)
