##########################################################################
## For development run the following
#example_dir = dirname(@__FILE__)
#if !isempty(example_dir) # the script is run in its entirety (otherwise, make sure to navigate to the examples folder in the REPL to run the following commands)
#    cd(example_dir) # Navigate to the examples folder
#end
#using Pkg
#Pkg.activate("..")
#Pkg.resolve()
#Pkg.instantiate()
#
##########################################################################
#using EnergyModelsGUI

#1: load the functions and data definitions:
include(joinpath(@__DIR__,"..","src", "EnergyModelsGUI.jl"))

idToColorsMap::Dict{Any,Any} = Dict{Any, Any}() # Initialize dictionary for colors map
idToIconsMap::Dict{Any,Any} = Dict{Any, Any}() # Initialize dictionary for icons map


#2: generate a CE model that is loaded into memory as "case".
#include("generate_EMB.jl")
#include("generate_EMB_sink_source.jl")
#include("generate_EMG.jl")
include("generate_EMI.jl")

#3: Specify path for design information:
path = joinpath(@__DIR__, "..", "design") # folder where visualization info is saved and retrieved

#4: Generate the system topology:
design = EnergyModelsGUI.EnergySystemDesign(case, path; idToColorsMap, idToIconsMap)

#5: Plot the topology:
EnergyModelsGUI.view(design)
