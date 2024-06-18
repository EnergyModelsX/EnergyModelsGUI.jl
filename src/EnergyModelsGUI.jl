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

# Use Colors to visualize using the colors in the colors.yml file
using Colors

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

# Needed for plottig geographical map
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
include("utils.jl")
include("setup_topology.jl")
include("GUI_utils.jl")
include("setup_GUI.jl")

# Export types
export GUI
export EnergySystemDesign

# Export functions
export set_colors
export set_icons

end # module
