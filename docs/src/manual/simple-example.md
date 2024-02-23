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
julia> using EnergyModelsGUI
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")
# Choose if you want to run the optimization part of the examples
julia> runOptimization::Bool = true
# Include the code into the Julia REPL to run the following example
julia> include(joinpath(exdir, "generate_EMG.jl"))
# Start the GUI:
julia> gui = GUI(case; design_path, idToColorMap, idToIconMap, model = m)
```