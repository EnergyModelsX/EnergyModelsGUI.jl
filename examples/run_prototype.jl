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

# Compile EnergyModelsGUI (alternatively, fetch from registry: using EnergyModelsGUI)
include(joinpath(@__DIR__,"..","src", "EnergyModelsGUI.jl"))

# Generate a CE model that is loaded into memory as "case".
runOptimization::Bool = true # Set runOptimization boolean to run optimization or not

#include("generate_Case1.jl")
#include("generate_Case2.jl")
include("generate_EMB.jl")
#include("generate_EMB_sink_source.jl")
#include("generate_EMG.jl")
#include("generate_EMI.jl")


# Run the GUI
gui = EnergyModelsGUI.GUI(case; design_path, idToColorMap, idToIconMap, model = m)

