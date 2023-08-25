#To test this prototype package:
#1: generate a CE model that is loaded into memory as "case".
#include("generate_EMG.jl")
#include("generate_EMB.jl")
include("generate_EMI.jl")

#2: load the functions and data definitions:
include(joinpath(@__DIR__,"..","src", "EnergyModelsGUI.jl"))

#3: Specify path for design information:
path = joinpath(@__DIR__, "..", "design") # folder where visualization info is saved and retrieved

#4: Generate the system topology:
design=nothing
design = EnergyModelsGUI.EnergySystemDesign(case, path);

#5: Plot the topology:
EnergyModelsGUI.view(design)
