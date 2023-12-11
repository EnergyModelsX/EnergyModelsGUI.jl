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
using Colors
using GeoMakie, GeoJSON
using GLMakie, GeometryBasics
using CairoMakie

include("structureTopology.jl")
include("viewTopology.jl")


export EnergySystemDesign

end # module
