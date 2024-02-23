# Running the examples

You have to add the package `EnergyModelsGUI` to your current project in order to run the examples.

You can run from the Julia REPL the following code:

```julia
# Starts the Julia REPL
julia> using EnergyModelsGUI
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")
# Include the code into the Julia REPL to run an example (i.e., EMB_sink_source.jl)
julia> include(joinpath(exdir, "EMB_sink_source.jl"))
```