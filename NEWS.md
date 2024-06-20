# Release notes

## Unversioned

* Redirect stdout to avoid redundant printouts during testing

## Version 0.5.0 (2024-04-19)

### Adjustment

* Adjusted default colors (for resources) to be that of `Matplotlib`.
* Removed empty and/or redundant sheets from excel exports.
* Renamed the `navigate up` button to `back` and moved it to the far left (to get a browser feel). The `open` button was moved correspondingly.
* Plot comonents and lines in layers such that components are uniquely layered on top of each other and always above any line.
* Use dashed linestyle for area components that has nodes with investment.
* For transmissions, only use dashed linestyle if the transmission itself has investments.
* Updated to `EnergyModelsBase`@0.7.0, `EnergyModelsGeography`@0.9.0, `EnergyModelsInvestments`@0.6.0 and `TimeStruct`@0.8.0.
* Restructured how descriptive names are read from the `descriptive_names.yml` file.
* Added the type `Connection` to replace the type `Tuple{EnergySystemDesign,EnergySystemDesign,Dict}`.
* Removed redundant functions, use the `plots` variable naming convention instead of `plot_objs`.

### Bugfix

* Fixed issue of non-updating doges for barplots when removing bars.
* Fixed bug of Wireframes being included in `gui.vars[:visiblePlots]`.
* Fix bug when exporting barplot data to the REPL PrettyTables.
* Fix error when exporting plots to excel files.
* Resolve bug when two components are close together which resulted in singular behaviour.
* Fixed bug for default icon setup for Source with multiple `Resource`s.
* Fixed bug when trying to read model results with `termination_status(gui.model) != MOI.OPTIMAL`.
* Fixed bug that for multiple selected plots did not go back to its original colors when deselected.

### Enhancement

* Code has been formatted using `JuliaFormatter` (with `style = "blue"`).
* Converted variable names form lower camelCase to snake_case (breaking).
* Divided the GUI() function into smaller functions.
* Improved the documentation to include explanation of the functionality of the GUI.
* Added a new example, `case7`, that show case more features of EMX and the GUI.
* Added more tests that focuses on specific GUI functionalities (currently 91.15 % coverage).
* Added .lp and .mps file export options.
* Add `clear all` (button) functionality.

### Feature

* The GUI window can now be closed with the shortcut `ctrl+w`.
* Add functionality to provide own descriptions and extended descriptions to the EnergyModelsRenewableProducers and EnergyModelsHydrogen packages.

## Version 0.4.2 (2024-03-19)

### Bugfix

* Fix issue when aligning selections of node including links/transmissions.
* Fix issue for plotting the topology having `Area`s with only the availability node present.

### Enhancement

* Improved documentation of the `GUI` constructor and provided more optional arguments.
* Improved performance be precomputing the available data for all objects such that choosing from the `Data` menu now performs better.

### Feature

* The fontsize can now be adjusted as an input argument to the `GUI` constructor.

## Version 0.4.1 (2024-03-15)

### Adjustment

* The `print table` functionality is now available through the `export` button with the `REPL` option.
* The `Save` functionality also loops through sub-systems (since changing coordinates of sub-components is enabled through the `Expand all` toggle).

### Bugfix

* Fixed issue with pinned and visible plots not being properly overwritten.
* Fixed issue with setting `expandAll = true` in the input argument for `GUI`.
* Fix issuewith non-existing export folder.

### Feature

* Added functionality to export all JuMP variables to an excel file.
* Added functionality to export all JuMP variables to the REPL using PrettyTables.

## Version 0.4.0 (2024-03-12)

### Adjustment

* For `StrategicPeriods` and `RepresentativePeriods`, plot the object string from the `Base.Show()` function instead of the corresponding integers.
* Removed redundant dependencies in the `Project.toml` file.
* One can now hide decorations (gridlines and ticks) in `axes[:topo]` by using the `GUI` input argument `hideTopoAxDecorations` (default is set to true).
* Use two triangles connected by a juncture for `NetworkNode`s to make the shape different from the circle used for `Sink`s. The left triangle represent input `Resource`s and the right triangle represents output `Resource`s.
* Breaking: Avoided CamelCase naming convention for function to be more alligned with the EMX naming convention.
* Plots are no longer auto selected (user must manually pick from `Available data`) to improve performance.
* Adjusted the tags `Electricity` and `Gas` to be `Power` and `NG` in the `colors.toml` file to be more in line with the EMX exampels..
* Added option to use coarse coastlines (the `coarseCoastlines` is by default set to `true`) for performance.

### Bugfix

* Fix zooming bug in `gui.axes[:info]`.
* Fix issue plotting results over `RepresentativePeriods`.
* Fix bug for modes of type `PipeSimple`.
* Fixed bug of collapsed lines when a connection is not twoWay.
* Fixed bug that did not toggle back highlighting of the "open" button after click.
* Corrected path to EMX packages for icon location (ext/EMGUIExt/icons).
* Fixed 404 issue for high resolution geographical land data.

### Enhancement

* Colors can now be provided as a dict for selected `Resource`s and if not provided the GUI will look through the colors.toml file for colors if same keys are used (otherwise an algorithm will fill in the missing colors based on the provided colors in order to be optimally distinct).
* By default, colors are now extracted automatically from the `src/colors.toml` file based on the `id` of the Resource (effectively removing the need of providing the `idToColorMap` input argument to get decent colors for most examples).
* Icons can now be provided in the form of a `Dict` that enables the user to only provide icons for a selected number of nodes. Moreover, the user can provide links for types (like `Sink` or `NetworkNode`). An example of this is provided in `examples/EMB_network.jl`.
* Documentation on how to customize icons and colors was added.

### Feature

* You can now use Button4 (used in i.e. browsers to go back to previous page) to go back to the `TopLevel` of the design (as an alternative to the `Esc` button).
* Double-clicking a node now opens its sub-system.
* Customized labels can now be provided for the different time structures.
* Plot data can now be exported to bit-map formats and to vector formats (.svg and .pdf).
* For `Area`s, an "Expand all" toggle functionality has been added to visualize all sub-systems. All of the topology are drawn in the initializing process of the GUI which optimizes the performance in runtime.
* Added the file `descriptiveNames.yml` which provides more descriptive names for the variables (used in the `ylabel`, `legend` and the Data menu).
* Added functionality to print plotted values to a table in the REPL using the package `PrettyTables`.

## Version 0.3.4 (2024-02-29)

### Adjustment

* Alter description on how examples should be run (use a seperate Project.toml file from the examples folder instead of the test folder).

### Bugfix

* Fixed bug for investments in transition cables not being dashed".

### Enhancement

* Improved component movements responsitivity.
* Added internal types and methods to the documentation.

## Version 0.3.3 (2024-02-26)

### Adjustment

* The labels now only show the node `id` and only used the Base.show function if `id` is a `Number`. Moreover, the type (in parantheses) was removed (this info is now shown on hovering).

### Bugfix

* Fixed legends not properly updating (old legend was not deleted) for `gui.axes[:results]`.

### Enhancement

* Support for RepresentativePeriods added.
* Support for Scenarios added.
* Added Makie inspector functionality such that hovering results axis displays coordinate and hovering topology shows type information.

## Version 0.3.2 (2024-02-23)

### Adjustment

* Changed the routine for finding the icons (icons in other EMX-packages are now expected to be found in ext/EMGUIExt/icons). All EMX-packages are assumed to have name starting with EnergyModels.
* Hide Investment plan, segment and scenarios menus until they are implemented.
* If `idToColorMap` is not provided, a set of colors is created from the default colors to be as distinct as possible.

### Bugfix

* Fixed a bug related to showing results for a Transmission.
* Fixed a bug when dragging a node outside the `gui.axes[:topo]` area.

### Enhancement

* Input data from the case can now be plotted.
* Code readibility was improved for `setupGUI.jl`.
* The tests now loop through all nodes/areas and their available data to check for errors.
* Improved structure of the examples.

## Version 0.3.1 (2024-02-14)

### Bugfix

* Fix CI malfunction resulting from LocalRegistry added in CI. LocalRegistry is now part of test project instead.

## Version 0.3.0 (2024-02-14)

### Adjustment

* The interactive option in the `view()` function has been removed due to lacking usage and maintenance.
* Improved visualization of connections.

### Bugfix

* Fix selection such that clicking on icons images results in node selection.
* Fix bug when selecting a node not having parent that is `:Toplevel`.
* Fix connection lines to be exactly at box boundary.
* Fix bug that assumes that all nodes are connected to an availability node for a `RefArea`.
* Fixed issue relating to reading x and y coordinates from toml file.
* Enabled visualization of sink/source to have more than one input/output.

### Enhancement

* Created a new structure for the GUI that simplifies construction and enables better control of the GUI.
* Open sub system in same axis (not open in a new window) and store plot objects for efficiency.
* Added axis to plot results and provided optional argument for passing the optimization results from `JuMP`
* Added text area to show information on the selected object.
* Improved handling of colors and icons (direct path to icons can be provided, or alternatively names of the .png files which will then have to exist in the icons folder of any of the EMX packages).
* Added tests that checks if the example files runs without errors.

## Version 0.2.0 (2024-01-10)

### Adjustment

Adjusted to changes in `EnergyModelsBase` v0.6.
These changes are mainly:

* All fields of composite types are now lower case.

### Bugfix

* Fix selection such that clicking on icons images results in node selection.
* Fix bug when selecting a node not having parent that is `:Toplevel`.

## Version 0.1.1 (2024-01-09)

### Adjustment

* Make default icon be based on colors instead of icons based on node types.

### Bugfix

* Zooming error due to GeoMakie resolved by deactivating zoom to area action.
* Update xy location of sub-systems when changing location of parent system.
* Removed requirement for an Availability node.
* Fixed bug that prevented more than two nodes to be selected.

### Enhancement

* Improved color handling by having a default behaviour based on the colors provided in the idToColorsMap dictionary
* Improved icon handling by having a default behaviour based on the colors provided. Enhancing users capability to add user defined icons in the idToIconsMap dictionary
* Created a field in EnergySystemDesign named plotObj to store all plotted objects associated with a given design object. This enabled more precise selection of nodes.
* Parameterized many parameters including selection color and scaling of boxes w.r.t. parent nodes
* Adjust limits of the axis to be consistent with a fixed aspect ratio (currently chosen to be 1:1)

### Feature

* An example without an `Availability` node added (based on the source-sink example in `EnergyModelsBase`).
* Provide legends for the available resources for the current system in the upper left corner.
* Added new icons.
* Connections now starts and ends at boundaries of boxes such that every line with arrows ends at the point of an arrow.
* By default, if colors are provided, and if no icons are provided, the "icons" will be represented by geometric shapes based on type and colored by the given resources; Sources has a square shape colored by its resource, Sinks has a circle colored by its resource and Network nodes has a cake diagram structure, where the left cake pieces are colored by the input colors and the right cake pieces are colored by the output colors of the Network node..
* Whenever the root system does not use :areas, use standard coordinates (instead of GeoMakie coordinates).

## Version 0.1.0 (2023-12-08)

* Initial version.
