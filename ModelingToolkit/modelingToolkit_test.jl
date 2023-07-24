using ModelingToolkit
using ModelingToolkitDesigner
using GLMakie
using DataFrames
import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B


@parameters t

@component function system(; name)

    pars = []

    systems = @named begin
        stp = B.Step(;height = 10e5, start_time = 0.005)
        src = IC.InputSource(;p_int=0)
        vol = IC.FixedVolume(;p_int=0, vol=10.0)
        res = IC.Pipe(5; p_int=0, area=0.01, length=500.0)
    end
   
    eqs = Equation[]
    
    ODESystem(eqs, t, [], pars; name, systems)
end

@named sys = system()

path = joinpath(@__DIR__, "design") # folder where visualization info is saved and retrieved
design = ODESystemDesign(sys, path);
ModelingToolkitDesigner.view(design)

DataFrame(name=[fieldnames(typeof(design))...], type=[fieldtypes(typeof(design))...])
design.components
design.components