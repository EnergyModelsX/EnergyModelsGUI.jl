"""Struct to provides a flexible data structure for modeling and working with complex energy system designs in Julia.

# Fields
- **`parent::Union{Symbol, Nothing}`** is the parent reference or indicator.
- **`system::Dict`** is the data related to the system, stored as key-value pairs.
- **`components::Vector{EnergySystemDesign}`** is the components of the system, stored as an array of EnergySystemDesign objects.
- **`connections::Vector{Tuple{EnergySystemDesign, EnergySystemDesign, Dict}}`** is the connections between system parts, each represented as a tuple with two EnergySystemDesign objects and a dictionary for associated properties.
- **`xy::Observable{Tuple{Real,Real}}`** is the coordinate of the system, observed for changes.
- **`icon::String`** is the optional (path to) icon associated with the system, stored as a string.
- **`color::Observable{Symbol}`** is the color of the system, observed for changes and represented as a Symbol. The color is toggled to highlight system activation.
- **`wall::Observable{Symbol}`** represents an aspect of the system's state, observed for changes and represented as a Symbol.
- **`file::String`** is the filename or path associated with the EnergySystemDesign.
"""
mutable struct EnergySystemDesign
    parent::Union{Symbol,Nothing}
    system::Dict
    idToColorMap::Dict{Any,Any}
    idToIconMap::Dict{Any,Any}
    components::Vector{EnergySystemDesign}
    connections::Vector{Tuple{EnergySystemDesign, EnergySystemDesign, Dict}}
    xy::Observable{Tuple{Real,Real}}
    icon::String
    color::Observable{Symbol}
    wall::Observable{Symbol}
    file::String
    plotObj::Vector{Any}
end

"""The main struct for the GUI

# Fields
- **`fig::Figure`** is the figure handle to the main figure (window).\n
- **`axes::Dict{Symbol,Axis}`** is a collection of axes: :topo (axis for visualizing the topology), :results (axis for plotting operation analaysis), :info (axis for displaying information).\n
- **`buttons::Dict{Symbol,Makie.Button}`** is a dictionary of the GLMakie buttons linked to the gui.axes[:topo] object.\n
- **`menus::Dict{Symbol,Makie.Menu}`** is a dictionary of the GLMakie menus linked to the gui.axes[:results] object.\n
- **`toggles::Dict{Symbol,Makie.Toggle}`** is a dictionary of the GLMakie toggles linked to the gui.axes[:results] object.\n
- **`root_design::EnergySystemDesign`** is the data structure used for the root topology.\n
- **`design::EnergySystemDesign`** is the data structure used for visualizing the topology.\n
- **`model::Model`** contains the optimization results.
- **`vars::Dict{Symbol,Any}`** is a dictionary of miscellaneous variables and parameters.\n
"""
mutable struct GUI 
    fig::Figure
    axes::Dict{Symbol, Makie.Block}
    buttons::Dict{Symbol, Makie.Button}
    menus::Dict{Symbol, Makie.Menu}
    toggles::Dict{Symbol, Makie.Toggle}
    root_design::EnergySystemDesign
    design::EnergySystemDesign
    model::Model
    vars::Dict{Symbol, Any}
end

"""
    show(io::IO, obj::EnergySystemDesign)

Print a simplified overview of the fields of an EnergySystemDesign struct
"""
function Base.show(io::IO, obj::EnergySystemDesign)
    indent_str::String = "  "
    println(io, "EnergySystemDesign with fields:")
    println(io, "  parent (Union{Symbol,Nothing}): ", obj.parent)
    println(io, "  system (Dict): ")
    for (key, value) ∈ obj.system
        println(io, indent_str, "  ", key, ": ", value)
    end
    println(io, "  idToColorMap (Dict{Any,Any}): ", obj.idToColorMap)
    println(io, "  idToIconMap (Dict{Any,Any}): ", obj.idToIconMap)
    println(io, "  components (Vector{EnergySystemDesign}): ")
    for (index,comp) ∈ enumerate(obj.components)
        if haskey(comp.system, :node)
            println(io, "    [", index, "] ", comp.system[:node])
        end
    end
    println(io, "  connections (Vector{Tuple{EnergySystemDesign, EnergySystemDesign, Dict}}): ")
    for (index,conn) ∈ enumerate(obj.connections)
        println(io, "    [", index, "] ", conn[1].system[:node], " - ", conn[2].system[:node])
    end

    println(io, "  xy (Observable{Tuple{Real,Real}}): ", obj.xy)
    println(io, "  icon (Union{String,Nothing}): ", obj.icon)
    println(io, "  color (Observable{Symbol}): ", obj.color)
    println(io, "  wall (Observable{Symbol}): ", obj.wall)

    println(io, "  file (String): ", obj.file)
    println(io, "  plotObj (Vector{Any}): ", obj.plotObj)
end

"""
    show(io::IO, obj::GUI)

Print a simplified overview of the fields of an EnergySystemDesign struct
"""
function Base.show(io::IO, gui::GUI)
    dump(io, gui, maxdepth=1)
end

"""
    Base.copy(x::EnergySystemDesign)

Make a copy of a EnergySystemDesign struct overloading the copy function that is part of the Base module in Julia.
"""
Base.copy(x::EnergySystemDesign) = EnergySystemDesign(
    x.parent,
    x.system,
    copy.(x.idToColorMap), # create deep copy of array or collection contained within EnergySystemDesign object. 
    copy.(x.idToIconMap),
    copy.(x.components), # create deep copy of array or collection contained within EnergySystemDesign object. 
    copy.(x.connections),
    Observable(x.xy[]),
    x.icon,
    Observable(x.system_color),
    Observable(x.wall[]),
    x.file,
    x.plotObj,
)

"""
    Base.copy(x::Tuple{EnergySystemDesign,EnergySystemDesign})

Copy a tuple of EnergySystemDesign structs
"""
Base.copy(x::Tuple{EnergySystemDesign,EnergySystemDesign}) = (copy(x[1]), copy(x[2])) 



