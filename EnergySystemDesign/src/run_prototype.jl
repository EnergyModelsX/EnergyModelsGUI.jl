using DataFrames
#To test this script:
#1: generate a CE model that is loaded into memory.


include("prototype.jl")


path = joinpath(@__DIR__, "design") # folder where visualization info is saved and retrieved
design = EnergySystemDesign(case, path);
#design = EnergySystemDesign
view(design)

DataFrame(name=[fieldnames(typeof(case[:nodes]))...], type=[fieldtypes(typeof(case[:nodes]))...])
