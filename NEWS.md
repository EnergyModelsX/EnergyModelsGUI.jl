# Release notes

Version 0.1.1 (2024-01-09)
--------------------------
### Enhancement
* Improved color handling by having a default behaviour based on the colors provided in the idToColorsMap dictionary
* Improved icon handling by having a default behaviour based on the colors provided. Enhancing users capability to add user defined icons in the idToIconsMap dictionary
* Created a field in EnergySystemDesign named plotObj to store all plotted objects associated with a given design object. This enabled more precise selection of nodes.
* Parameterized many parameters including selection color and scaling of boxes w.r.t. parent nodes
* Adjust limits of the axis to be consistent with a fixed aspect ratio (currently chosen to be 1:1)

### Bugfix
* Zooming error due to GeoMakie resolved by deactivating zoom to area action
* Update xy location of sub-systems when changing location of parent system
* Removed requirement for an Availability node
* Fixed bug that prevented more than two nodes to be selected

### Adjustment
* Make default icon be based on colors instead of icons based on node types

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