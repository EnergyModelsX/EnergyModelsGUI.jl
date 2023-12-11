# Quick Start

>  1. Install the most recent version of [Julia], preferably using the Juliaup version multiplexer (https://github.com/JuliaLang/juliaup)
>  2. Add the [CleanExport internal Julia registry](https://gitlab.sintef.no/clean_export/registrycleanexport):
>     ```
>     ] registry add git@gitlab.sintef.no:clean_export/registrycleanexport.git
>     ```
>  3. Add the [SINTEF internal Julia registry](https://gitlab.sintef.no/julia-one-sintef/onesintef):
>     ```
>     ] registry add git@gitlab.sintef.no:julia-one-sintef/onesintef.git
>     ```
>  4. Install the base package [`EnergyModelsGUI.jl`](https://clean_export.pages.sintef.no/energymodelsgui.jl/) by running:
>     ```
>     ] add EnergyModelsGUI
>     ```
>     This will fetch the packages from the CleanExport package and OneSINTEF registries.