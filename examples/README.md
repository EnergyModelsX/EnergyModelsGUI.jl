# Running the examples

You have to add the package `EnergyModelsGUI` to your current project in order to run the examples.

You can run from the Julia REPL the following code:

```julia
# Starts the Julia REPL
using EnergyModelsGUI

# Install required packages (use the project.toml file in the test folder of the repository)
testDir = joinpath(pkgdir(EnergyModelsGUI), "test")
using Pkg 
Pkg.activate(testDir) 
Pkg.instantiate()

# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")

# Include the code into the Julia REPL to run an example (i.e., EMB_sink_source.jl):
include(joinpath(exdir, "EMB_sink_source.jl"))
```