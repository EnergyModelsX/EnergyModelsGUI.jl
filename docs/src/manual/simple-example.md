# Examples

For the content of the individual examples, see the [examples](https://gitlab.sintef.no/clean_export/energymodelsgui.jl/-/tree/main/examples) directory in the project repository.

## The package is installed with `] add`

First, add the [*Clean Export* Julia packages repository](https://gitlab.sintef.no/clean_export/registrycleanexport). Then run

```
~/some/directory/ $ julia   # Starts the Julia REPL
julia> ]                    # Enter Pkg mode
pkg> add EnergyModelsGUI    # Install the package EnergyModelsBase to the current environment.
```

From the Julia REPL (*i.e*, command-line in julia; `julia> `), run

```julia
# Starts the Julia REPL
using Pkg
using EnergyModelsGUI

# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsGUI), "examples")

# Activate project for the examples in the EnergyModelsGUI repository
Pkg.activate(exdir)
Pkg.instantiate()

# Include the code into the Julia REPL to run the following example
include(joinpath(exdir, "EMI_geography.jl"))
```

You should then get the following GUI:
![Example image for GUI](../figures/example.png)

To the left you here get a visualization of the topology. This window provide the following functionality:

1. You can move a `Node`/`Area` by holding down the left mouse button and dragging to the desired location (at which you then release the left mouse button). The `Links`/`Transmissions` to this `Node`/`Area` will be updated as well.
2. Selecting a `Node`/`Area`/`link`/`Transmission` (by left-clicking) will print information about this object in the box on the top right. The selected object will have a green line style.
3. You can select multiple nodes/areas by holding down `ctrl` and left-clicking.
4. You can change the focus area (pan) of the window by holding down the right mouse button and dragging.
5. You can zoome in and out by using the scroll wheel on the mouse.
6. Hovering a component will show the type of this component.

The toolbar on top provides the following functionality:

1. `back`: If you are using the `EnergyModelsGeography` package as in this example, you can here navigate back to the `Top level` if you are currently in an area (opened by the `open` button, see below). This button has the keyboard shortcut `MouseButton4` (or `Esc`).
2. `open`: If you are using the `EnergyModelsGeography` package as in this example, you can open an area by first selecting the area to open and then clicking this button. This button has the keyboard shortcut `space`. Opening an area can also be accomplished by double clicking this area icon.
3. `align horz.`: This enables you to align selected nodes/areas horizontally.
4. `align vert.`: This enables you to align selected nodes/areas vertically.
5. `save`: This button saves the coordinates of the `Node`s/`Area`s to file (files if there are multiple areas; a single file for each area in addition to a file for the `Top level`). The location of these files can be assigned through the `design_path` input parameter to the `GUI` function.
6. `reset view`: Resets the view to the optimal view based on the current system if the view has been altered.
7. `Exapnd all`: You can toggle this on to show all components of all `Area`s
8. `Period`: Use this menu to choose a `StrategicPeriod` of your case
9. `Scenario`: Use this menu to choose a `Scenario` of your case
10. `Representative period`: Use this menu to choose a `RepresentativePeriod` of your case
11. `Data`: Use this menu to select the available data to be visualized in the plot area to the bottom right (if a component is selected, the menu will update to contain the available data for this component).

An additional toolbar on the bottom right is related to the plot area above and has the following functionality:

1. `Plot`: This menu enables activation of one of the three available plots one for `StrategicPeriod`, one for `RepresentativePeriod` and one for `OperationalPeriod`.
2. `pin current data`: Clicking this button pins the lastly plotted data which enables comparing with other data in the same time type
3. `remove selected data`: A plot can be selected by left-click and can then be removed by clicking this button
4. `Export`: Choose if you want to export all data (or entire window) in the option `All` or the current active plots (`Plots`).
5. This menu enables you to choose the format of the export (you can also print the data to the REPL by using the `REPL` option here).
6. `export`: This button finally exports the data using the setup in the previous two menus.
