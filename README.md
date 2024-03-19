# EnergyModelsGUI
[![Pipeline: passing](https://gitlab.sintef.no/clean_export/energymodelsgui.jl/badges/main/pipeline.svg)](https://gitlab.sintef.no/clean_export/energymodelsgui.jl/-/jobs)
[![Docs: in development](https://img.shields.io/badge/docs-in%20development-ff69b4.svg)](https://clean_export.pages.sintef.no/energymodelsgui.jl)

EnergyModelsGUI enables a graphical user interface for the [EnergyModelsBase](https://gitlab.sintef.no/clean_export/energymodelsbase.jl) package and other packages building upon this package (like [EnergyModelsInvestments](https://gitlab.sintef.no/clean_export/energymodelsinvestments.jl) and [EnergyModelsGeography](https://gitlab.sintef.no/clean_export/energymodelsgeography.jl)). It is designed to give a simple visualization of the topology of the model and enable the user to interactively navigate through the different layers of the model design. Visualization of the results after simulations will be added at a later stage.

The EnergyModelsGUI package has taken inspiration from the source code of [ModelingToolkitDesigner](https://github.com/bradcarman/ModelingToolkitDesigner.jl) as a starting point for development.

> **Note**
> This is an internal pre-release not intended for distribution outside SINTEF. 

## Usage

The [documentation](https://clean_export.pages.sintef.no/energymodelsgui.jl/) for `EnergyModelsGUI` is in development.

See examples of usage of the package and a simple guide for running them in the folder [`examples`](examples).

I.e. running the example [`EMI_geography`](examples/EMI_geography.jl) will result in a view like the following:

![Example image for EMI_geography](docs/src/figures/EMI_geography.png)

Opening the Oslo area will display that sub system:

![Example image for EMI_geography](docs/src/figures/EMI_geography_Oslo.png)

## Project Funding

EnergyModelsGUI was funded by [FLEX4FACT](https://flex4fact.eu/). FLEX4FACT is receiving funding from the European Union’s Horizon Europe research and innovation programme under grant agreement [101058657](https://doi.org/10.3030/101058657).
