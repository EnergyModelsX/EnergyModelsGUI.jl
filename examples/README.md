# Running the examples

You have to add the package `EnergyModelsGUI` to your current project in order to run the examples.

You can run from the Julia REPL the following code:

```julia
# Starts the Julia REPL
using EnergyModelsGUI

# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")

# Install required packages (use the project.toml file in the test folder of the repository)
using Pkg
Pkg.activate(exdir)
Pkg.instantiate()

# Fetch functions to generate examples
include(joinpath(exdir, "generate_examples.jl"))

# Run an example (*e.g.*, EMI_geography.jl):
include(joinpath(exdir, "EMI_geography.jl"))
```
