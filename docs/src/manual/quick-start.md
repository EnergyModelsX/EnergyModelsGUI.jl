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

A complete overview of the keyword arguments available for the `GUI` functions is available *[in its docstring](@ref GUI(case::Case; kwargs...))*.

!!! tip "Example"
    The GUI and its functionality is described through *[an example](@ref man-exampl)*.
    You can also load different examples from the example folder, if desired.

### [Visualization of saved results](@id man-quick-saved)

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

### [Technologies with period partitions](@id man-quick-partitions)

[`TimeStruct`](https://github.com/sintefore/TimeStruct.jl) (version 0.9.12 and later) allows for partitioning the operational periods of a time structure into `PeriodPartition`s.
Technologies using them, *e.g.*, the `PeriodDemandSink` of [`EnergyModelsFlex`](https://github.com/EnergyModelsX/EnergyModelsFlex.jl), have `PartitionProfile` fields and `JuMP` variables indexed over these partitions.
`EnergyModelsGUI` visualizes this data through the time axis option *Partition*, which is only available for elements with partitioned data.

Partitions differ between elements and are not part of the time structure of the case.
`EnergyModelsGUI` therefore has to construct the partitions of each element itself through the function [`period_partitions`](@ref EnergyModelsGUI.period_partitions).
By default, it uses the field `period_duration` of the element, following the convention of `EnergyModelsFlex`.
If your technology stores the duration of its partitions differently, you must provide a method for your type returning the vector of `PeriodPartition`s for the time structure `𝒯` of the case.
Consider the case in which these are stored within the field `duation`, you must create a new method:

```julia
using EnergyModelsGUI, TimeStruct

function EnergyModelsGUI.period_partitions(n::MyPeriodNode, 𝒯::TimeStructure)
    return collect(partition_duration(𝒯, n.duration))
end
```

The method can be defined in your script or in the package introducing the technology, *e.g.*, through a package extension on `EnergyModelsGUI`.
It is our aim to include a default method within `EnergyModelsBase` which can be extended in a later stage.

!!! warning "Requirements for period partitions"
    1. Without a method of `period_partitions` for an element lacking the field `period_duration`, a warning naming the element and the required method is issued and the partitioned data of this element is not available for plotting.
       All other data of the element and of the case remains available.
    2. The method is also required when loading results from file.
       The partition labels written by `save_results` are not unique across elements, so the partitions are rebuilt for each element through `period_partitions` when reading the CSV files.
