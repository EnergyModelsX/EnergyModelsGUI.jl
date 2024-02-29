# Release notes

Version 0.3.4 (2024-02-29)
--------------------------
### Adjustment
* Alter description on how examples should be run (use a seperate Project.toml file from the examples folder instead of the test folder)

### Bugfix
* Fixed bug for investments in transition cables not being dashed"

### Enhancement
* Improved component movements responsitivity
* Added internal types and methods to the documentation

Version 0.3.3 (2024-02-26)
--------------------------
### Adjustment
* The labels now only show the node `id` and only used the Base.show function if `id` is a `Number`. Moreover, the type (in parantheses) was removed (this info is now shown on hovering)

### Bugfix
* Fixed legends not properly updating (old legend was not deleted) for `gui.axes[:results]`

### Enhancement
* Support for RepresentativePeriods added
* Support for Scenarios added
* Added Makie inspector functionality such that hovering results axis displays coordinate and hovering topology shows type information

Version 0.3.2 (2024-02-23)
--------------------------
### Adjustment
* Changed the routine for finding the icons (icons in other EMX-packages are now expected to be found in ext/EnergyModelsGUI/icons). All EMX-packages are assumed to have name starting with EnergyModels.
* Hide Investment plan, segment and scenarios menus until they are implemented
* If `idToColorMap` is not provided, a set of colors is created from the default colors to be as distinct as possible

### Bugfix
* Fixed a bug related to showing results for a Transmission
* Fixed a bug when dragging a node outside the `gui.axes[:topo]` area

### Enhancement
* Input data from the case can now be plotted
* Code readibility was improved for setupGUI.jl
* The tests now loop through all nodes/areas and their available data to check for errors
* Improved structure of the examples

Version 0.3.1 (2024-02-14)
--------------------------
### Bugfix
* Fix CI malfunction resulting from LocalRegistry added in CI. LocalRegistry is now part of test project instead.

Version 0.3.0 (2024-02-14)
--------------------------
### Adjustment
* The interactive option in the view() function has been removed due to lacking usage and maintenance
* Improved visualization of connections

### Bugfix
* Fix selection such that clicking on icons images results in node selection
* Fix bug when selecting a node not having parent that is :Toplevel
* Fix connection lines to be exactly at box boundary
* Fix bug that assumes that all nodes are connected to an availability node for a `RefArea`
* Fixed issue relating to reading x and y coordinates from toml file
* Enabled visualization of sink/source to have more than one input/output

### Enhancement
* Created a new structure for the GUI that simplifies construction and enables better control of the GUI
* Open sub system in same axis (not open in a new window) and store plot objects for efficiency
* Added axis to plot results and provided optional argument for passing the optimization results from JuMP
* Added text area to show information on the selected object
* Improved handling of colors and icons (direct path to icons can be provided, or alternatively names of the .png files which will then have to exist in the icons folder of any of the EMX packages)
* Added tests that checks if the example files runs without errors

Version 0.2.0 (2024-01-10)
--------------------------
### Adjustment
Adjusted to changes in `EnergyModelsBase` v0.6.
These changes are mainly:

* All fields of composite types are now lower case.

### Bugfix
* Fix selection such that clicking on icons images results in node selection
* Fix bug when selecting a node not having parent that is :Toplevel

Version 0.1.1 (2024-01-09)
--------------------------
### Adjustment
* Make default icon be based on colors instead of icons based on node types

### Bugfix
* Zooming error due to GeoMakie resolved by deactivating zoom to area action
* Update xy location of sub-systems when changing location of parent system
* Removed requirement for an Availability node
* Fixed bug that prevented more than two nodes to be selected

### Enhancement
* Improved color handling by having a default behaviour based on the colors provided in the idToColorsMap dictionary
* Improved icon handling by having a default behaviour based on the colors provided. Enhancing users capability to add user defined icons in the idToIconsMap dictionary
* Created a field in EnergySystemDesign named plotObj to store all plotted objects associated with a given design object. This enabled more precise selection of nodes.
* Parameterized many parameters including selection color and scaling of boxes w.r.t. parent nodes
* Adjust limits of the axis to be consistent with a fixed aspect ratio (currently chosen to be 1:1)

### Feature
* An example without an Availability node added (based on the source-sink example in EnergyModelsBase)
* Provide legends for the available resources for the current system in the upper left corner
* Added new icons
* Connections now starts and ends at boundaries of boxes such that every line with arrows ends at the point of an arrow
* By default, if colors are provided, and if no icons are provided, the "icons" will be represented by geometric shapes based on type and colored by the given resources; Sources has a square shape colored by its resource, Sinks has a circle colored by its resource and Network nodes has a cake diagram structure, where the left cake pieces are colored by the input colors and the right cake pieces are colored by the output colors of the Network node.
* Whenever the root system does not use :areas, use standard coordinates (instead of GeoMakie coordinates)

Version 0.1.0 (2023-12-08)
--------------------------
* Initial version