"""
Main module for `EnergyModelsGUI.jl`.

This module provides the graphical user interface for EnergyModelsX packages.
"""
module EnergyModelsGUI

using FileIO
using TOML
using FilterHelpers
using TimeStruct
using EnergyModelsBase
using EnergyModelsGeography
using Colors
using GeoMakie, GeoJSON
using GLMakie
using JuMP
using HTTP # Needed for downloading the geojson file used for high resolution world map
using Pkg # Used to check for icons in other EMX repositories

const TS = TimeStruct
const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography

include("datastructures.jl")
include("utils.jl")
include("setupTopology.jl")
include("setupGUI.jl")


export GUI
export EnergySystemDesign
export setColors
export setIcons
export update!

end # module
