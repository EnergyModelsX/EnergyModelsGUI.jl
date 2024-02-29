# Examples

For the content of the individual examples, see the [examples](https://gitlab.sintef.no/clean_export/energymodelsgui.jl/-/tree/main/examples) directory in the project repository.

## The package is installed with `] add`

First, add the [*Clean Export* Julia packages repository](https://gitlab.sintef.no/clean_export/registrycleanexport). Then run 
```
~/some/directory/ $ julia           # Starts the Julia REPL
julia> ]                            # Enter Pkg mode 
pkg> add EnergyModelsGUI            # Install the package EnergyModelsBase to the current environment.
```
From the Julia REPL, run
```julia
# Starts the Julia REPL
using Pkg 
using EnergyModelsGUI

# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")

# Activate project for the examples in the EnergyModelsGUI repository
Pkg.activate(exdir) 
Pkg.instantiate()

# Include the code into the Julia REPL to run the following example
include(joinpath(exdir, "EMG_geography.jl"))
```