"""
Main module for `EnergyModelsGUI.jl`.

This module provides the graphical user interface for EnergyModelsX packages.
"""
module EnergyModelsGUI

using Pkg                   # Used to check for icons in other EMX repositories
using YAML                  # Needed for reading descriptive names (for variable names: "Available data"). Also used for colors.yml and writing coordinates to file
using FileIO                # Needed for loading images (as icons)
using TimeStruct
using EnergyModelsBase
using Colors                # Needed to visualize using the colors in the colors.yml file
using GLMakie               # Library to create figure
using Dates                 # Needed for double clicking
using JuMP                  # Needed for the type JuMP.Model

using EnergyModelsGeography
using GeoMakie, GeoJSON     # Needed for plottig geographical map
using HTTP                  # Needed to download the .json file for geographical coastlines

using PrettyTables
using CairoMakie            # Required to export to vector graphics
using ImageMagick           # Needed to export to pdf-files and jpeg-files
using XLSX                  # Needed for exporting xlsx-files

const TS = TimeStruct
const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography

include("datastructures.jl")
include("utils.jl")
include("setupTopology.jl")
include("GUIutils.jl")
include("setupGUI.jl")

# Export types
export GUI
export EnergySystemDesign

# Export functions
export set_colors
export set_icons
export update!

end # module
