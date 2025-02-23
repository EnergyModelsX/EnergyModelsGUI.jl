"""
Main module for `EnergyModelsGUI.jl`.

This module provides the graphical user interface for EnergyModelsX packages.
"""
module EnergyModelsGUI

# Use Pkg to check for icons in other EMX repositories
using Pkg

# YAML is needed for reading descriptive names (for variable names: "Available data").
# Also used for colors.yml and writing coordinates to file
using YAML

# FileIO is needed for loading images (as icons)
using FileIO
using TimeStruct
using EnergyModelsBase
import EnergyModelsBase: get_elements_vec, get_nodes

# To format numbers with @sprintf
using Printf

# Use GLMakie front end to visualize the GUI figure
using GLMakie

# Use Dates to enable double clicking (time 500ms between clicks)
using Dates

# Import JuMP types
using JuMP

# SparseVariables.IndexedVarArray types
using SparseVariables

using EnergyModelsGeography
using EnergyModelsInvestments

# Needed for plottig geographical map (note that GeoMakie reexports Colors)
using GeoMakie, GeoJSON

# Needed to download the .json file for geographical coastlines
using HTTP

# Use PrettyTables to enable printing data to the REPL
using PrettyTables

# Required to export to vector graphics
using CairoMakie

# Needed to export to pdf-files and jpeg-files
using ImageMagick

# Needed for exporting xlsx-files
using XLSX

const TS = TimeStruct
const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography
const EMI = EnergyModelsInvestments

include("datastructures.jl")
include("utils_gen/utils.jl")
include("utils_gen/structures_utils.jl")
include("utils_gen/topo_utils.jl")
include("utils_gen/export_utils.jl")
include("setup_topology.jl")
include("utils_GUI/GUI_utils.jl")
include("utils_GUI/topo_axis_utils.jl")
include("utils_GUI/info_axis_utils.jl")
include("utils_GUI/results_axis_utils.jl")
include("utils_GUI/event_functions.jl")
include("setup_GUI.jl")

# Export types
export GUI
export EnergySystemDesign

# Export functions
export set_colors
export set_icons

end # module
