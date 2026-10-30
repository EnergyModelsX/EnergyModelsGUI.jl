using EnergyModelsGUI
using Test
using YAML
using Logging
using CSV
using DataFrames

const TEST_ATOL = 1e-6
const EMGUI = EnergyModelsGUI

pkg_dir = pkgdir(EnergyModelsGUI)
testdir = joinpath(pkg_dir, "test")

# Include function that can loop through all components and plot its data
include(joinpath(testdir, "utils.jl"))

# Include the code that generates the cases
include(joinpath(testdir, "case7.jl"))
include(joinpath(testdir, "EMI_geography_2.jl"))
include(joinpath(testdir, "example_test.jl"))
include(joinpath(testdir, "example_all_structures.jl"))
include(joinpath(testdir, "example_cases.jl"))

logger_org = global_logger()
logger_new = ConsoleLogger(stderr, Logging.Warn)
global_logger(logger_new)

@testset "EnergyModelsGUI" verbose = true begin
    redirect_stdio(stdout = devnull) do
        # Run all Aqua tests
        include(joinpath(testdir, "Aqua.jl"))

        # Check if there is need for formatting
        include(joinpath(testdir, "JuliaFormatter.jl"))

        # Test some of the utility functionality
        include(joinpath(testdir, "test_utils.jl"))

        # The following tests results input and output functionality (saving and loading results)
        include(joinpath(testdir, "test_results_IO.jl"))

        # Test Base.show() functionalities
        include(joinpath(testdir, "test_show.jl"))

        # Test specific GUI functionalities related to interactivity
        include(joinpath(testdir, "test_interactivity.jl"))

        # Test descriptive names functionalities
        include(joinpath(testdir, "test_descriptive_names.jl"))

        # The following tests simply checks if the main examples can be run without errors
        include(joinpath(testdir, "test_examples.jl"))
    end
end
global_logger(logger_org)
