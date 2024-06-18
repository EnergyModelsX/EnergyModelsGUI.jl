# Philosophy

## General design philosophy

One key aim in the development of `EnergyModelsGUI` was to create a graphical user interface that

1. visualizes the topology and result from `EnergyModelsX`,
2. draws inspiration from the [integrate](https://www.sintef.no/programvare/integrate/) framework for visualization of energy systems, and
3. has a simple architecture that minimizes dependencies on major packages.

`EnergyModelsGUI` is hence focusing of providing the user with a simple interface to both visualize the created energy system and the results, if a `JuMP.model` is added.
Its aim is not to provide the user with an input processing routine or a method for generating figures that can be directly used in publications.

## Incorporation of `EnergyModelsGUI` to your `EMX` extension package

`EnergyModelsGUI` should by default be able to work with potential extension packages as it is only dependent on the case dictionary description and the variable names.
However, you can provide an extension to `EnergyModelsGUI` in your `EMX` package with, *e.g.*, specific icons for the developed nodes.
In addition, if your package introduces new variables, you can provide a description of the variables in your package.

!!! warning
    Providing new names to the variables in its current form is a bit complicated.
    You have to provide a file `descriptive_names.yml` for including descriptive names for both parameters of composite types and variables.
    This file should include all existing names as it is only read one.

    We aim in a future version to utilize a different approach in which the both the fields of types and introduced variables are provided as entries to a dictionary.
    In this situation, it is no longer necessary to copy the existing file.
