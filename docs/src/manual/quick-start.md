# Quick Start

>  1. Install the most recent version of [Julia], preferably using the Juliaup version multiplexer (https://github.com/JuliaLang/juliaup)
>  2. Install the package [`EnergyModelsGUI`](https://energymodelsx.github.io/EnergyModelsGUI.jl/) by running:
>     ```
>     ] add EnergyModelsGUI
>     ```

!!! note
    Utilizing `EnergyModelsGUI` requires the declaration of cases in `EnergyModelsX`.
    To this end, you also have to add the packages [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/stable/) and potentially [`EnergyModelsGeography`](https://energymodelsx.github.io/EnergyModelsGeography.jl/stable/) and [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) to create your energy model cases first.

If you already have constructed a `case` in EMX you can view this case with

```julia
using EnergyModelsGUI

GUI(case)
```
