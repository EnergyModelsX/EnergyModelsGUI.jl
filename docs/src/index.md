# EnergyModelsGUI.jl

```@docs
EnergyModelsGUI
```

**EnergyModelsX** is an operational, multi nodeal energy system model, written in Julia.
The model is based on the [`JuMP`](https://jump.dev/JuMP.jl/stable/) optimization framework.
It is a multi carrier energy model, where the definition of the resources are fully up to the user of the model.
One of the primary design goals was to develop a model that can eaily be extended with new functionality without the need to understand and remember every variable and constraint in the model.

For running and visualizing a basic energy system model, only the base technology package
[`EnergyModelsBase.jl`](https://clean_export.pages.sintef.no/energymodelsbase.jl/),
[`EnergyModelsGUI.jl`](https://clean_export.pages.sintef.no/energymodelsgui.jl/)
and the time structure package
[`TimeStruct.jl`](https://gitlab.sintef.no/julia-one-sintef/timestruct.jl)
is needed.

The EnergyModelsGUI package also provides visualization utilities for the following packages

- [`EnergyModelsGeography.jl`](https://clean_export.pages.sintef.no/energymodelsgeography.jl/):
   this package makes it possible to easily extend your energy model different
   geographic areas, where transmission can be set to allow for the transport of
   resources between the different areas.
- [`EnergyModelsInvestments.jl`](https://clean_export.pages.sintef.no/energymodelsinvestments.jl/):
   this package implements functionality for investments, where the length of the
   investment periods are fully flexible and is decided by setting the time
   structure.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/philosophy.md",
    "manual/simple-example.md",
]
```