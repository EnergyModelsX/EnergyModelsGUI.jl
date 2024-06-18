# EnergyModelsGUI.jl

```@docs
EnergyModelsGUI
```

**EnergyModelsX** is an operational, multi nodeal energy system model, written in Julia.
The model is based on the [`JuMP`](https://jump.dev/JuMP.jl/stable/) optimization framework.
It is a multi carrier energy model, where the definition of the resources are fully up to the user of the model.
One of the primary design goals was to develop a model that can eaily be extended with new functionality without the need to understand and remember every variable and constraint in the model.

For running and visualizing a basic energy system model, only the base technology package
[`EnergyModelsBase.jl`](https://github.com/EnergyModelsX/EnergyModelsBase.jl.git),
[`EnergyModelsGUI.jl`](https://clean_export.pages.sintef.no/energymodelsgui.jl/)
and the time structure package
[`TimeStruct.jl`](https://github.com/sintefore/TimeStruct.jl/releases)
are needed.

The EnergyModelsGUI package also provides visualization utilities for the following packages

- [`EnergyModelsGeography.jl`](https://github.com/EnergyModelsX/EnergyModelsGeography.jl):
   this package makes it possible to easily extend your energy model with different
   geographic areas, where transmission can be set to allow for the transport of
   resources between the different areas.
- [`EnergyModelsInvestments.jl`](https://github.com/EnergyModelsX/EnergyModelsInvestments.jl):
   this package implements functionality for investments, where the length of the
   investment periods are fully flexible and is decided by setting the time
   structure.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/simple-example.md",
    "manual/NEWS.md",
]
Depth = 1
```

## How to guides

```@contents
Pages = [
    "how-to/save-design.md",
    "how-to/export-results.md",
    "how-to/customize-colors.md",
    "how-to/customize-icons.md",
]
Depth = 1
```

## Library outline

```@contents
Pages = [
    "library/public.md",
    "library/internals/reference.md",
]
Depth = 1
```
