# [Quick Start](@id man-quick)

## [Installation](@id man-quick-install)

> 1. Install the most recent version of [Julia], preferably using the Juliaup version multiplexer (<https://github.com/JuliaLang/juliaup>)
> 2. Install the package [`EnergyModelsGUI`](https://energymodelsx.github.io/EnergyModelsGUI.jl/) by running:
>
>    ```
>    ] add EnergyModelsGUI
>    ```

## [Use](@id man-quick-use)

!!! note
    `EnergyModelsGUI` extends `EnergyModelsBase` with a graphical user interface.
    As a consequence, it requires the declaration of a [`Case`](@extref EnergyModelsBase.Case) in `EnergyModelsX`.

    To this end, you also have to add the packages [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/) and potentially [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/stable/) and [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) to create your energy model cases first.

If you already have constructed a [`Case`](@extref EnergyModelsBase.Case) in `EMX` you can view this case with

```julia
using EnergyModelsGUI

GUI(case)
```

This allows you to investigate all provided parameters, but does not show you the results from the analysis.
The results from a `JuMP` model can be visualized through the keyword argument `model` for a given `JuMP` model `m`:

```julia
GUI(case; model=m)
```

It is furthermore possible to visualize results from a saved model run.
This however requires you to first save the results from a model run through the function [`save_results`](@ref).
You can then visualize the results from a saved model run, again with the keyword argument `model`.

For a given `JuMP` model `m`, this approach is given by

```julia
# Specify the directory for saving the results and save the results
dir_save = `path-to-results`
save_results(m; directory = dir_save)

# Load the results from the saved directory
GUI(case; model = dir_save)
```

!!! warning "Requirements for loading from file"

    1. You **must** always provide a [`Case`](@extref EnergyModelsBase.Case) in `EnergyModelsX` corresponding to the model results when reading input data.
       This case can be created anew from corresponding functions.
       It **cannot** be a saved `Case` as the pointers to specific instances of, *e.g.*, `Link`s are not recreated when loading a `Case`.
    2. You **must** use the function `save_results` for saving your results as we require the meta data when reading the CSV files for translating the data into the correct format.

A complete overview of the keyword arguments available for the `GUI` functions is available *[in its docstring](@ref GUI(case::Case; kwargs...))*.

!!! tip "Example"
    The GUI and its functionality is described through *[an example](@ref man-exampl)*.
    You can also load different examples from the folder, if desired
