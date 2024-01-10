"""
Main module for `EnergyModelsGUI.jl`.

This module provides the graphical user interface for EnergyModelsX packages.
"""
module EnergyModelsGUI

using FileIO
using TOML
using FilterHelpers
using Observables
using EnergyModelsBase
using EnergyModelsGeography
using Colors
using GeoMakie, GeoJSON
using GLMakie, GeometryBasics
using CairoMakie

missingColor = :black # Default color when color is not provided
include("structureTopology.jl")
include("viewTopology.jl")


export EnergySystemDesign
export setColors!

end # module
