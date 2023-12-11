# Examples

For the content of the individual examples, see the [examples](https://gitlab.sintef.no/clean_export/energymodelsgui.jl/-/tree/main/examples) directory in the project repository.

## The package is installed with `] add`

First, add the [*Clean Export* Julia packages repository](https://gitlab.sintef.no/clean_export/registrycleanexport). Then run 
```
~/some/directory/ $ julia           # Starts the Julia REPL
julia> ]                            # Enter Pkg mode 
pkg> add EnergyModelsGUI    # Install the package EnergyModelsBase to the current environment.
```
From the Julia REPL, run
```julia
# Starts the Julia REPL
julia> using EnergyModelsGUI
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")
# Include the code into the Julia REPL to run the following example
julia> include(joinpath(exdir, "generate_EMG.jl"))
# Specify path for saving design information:
julia> path = joinpath(@__DIR__, "design") # folder where visualization info is saved and retrieved
# Generate the system topology:
julia> design = EnergyModelsGUI.EnergySystemDesign(case, path);
#Plot the topology:
julia> EnergyModelsGUI.view(design)
```