# [Philosophy](@id man-phil)

## [General design philosophy](@id man-phil-gen)

One key aim in the development of `EnergyModelsGUI` was to create a graphical user interface that

1. visualizes the topology and result from `EnergyModelsX`,
2. draws inspiration from the *[Integrate](https://www.sintef.no/programvare/integrate/)* framework for visualization of energy systems, and
3. has a simple architecture that minimizes dependencies on major packages.

`EnergyModelsGUI` is hence focusing of providing the user with a simple interface to both visualize the created energy system and the results, if a `JuMP.model` is added.
Its aim is not to provide the user with an input processing routine or a method for generating figures that can be directly used in publications.

## [Incorporation of `EnergyModelsGUI` to your `EMX` extension package](@id man-phil-ext)

`EnergyModelsGUI` should by default be able to work with potential extension packages as it is only dependent on the case dictionary description and the variable names.
However, you can provide an extension to `EnergyModelsGUI` in your `EMX` package with, *e.g.*, specific icons for the developed nodes.
In addition, if your package introduces new variables, you can provide a description of the variables in your package.
