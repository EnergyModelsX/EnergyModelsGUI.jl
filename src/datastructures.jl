"""
Mutable type for providing a flexible data structure for modeling and working with complex
energy system designs in Julia.

# Fields

- **`parent::Union{Symbol, Nothing}`** is the parent reference or indicator.
- **`system::Dict`** is the data related to the system, stored as key-value pairs.
- **`id_to_color_map::Dict`** is a dictionary of resources and their assigned colors.
- **`id_to_icon_map::Dict`** is a dictionary of nodes and their assigned icons.
- **`components::Vector{EnergySystemDesign}`** is the components of the system, stored
  as an array of EnergySystemDesign objects.
- **`connections::Vector{Connection}`** are the connections between system parts.
- **`xy::Observable{Tuple{Real,Real}}`** are the coordinates of the system, observed for
  changes.
- **`icon::String`** is the optional (path to) icons associated with the system, stored as
  a string.
- **`color::Observable{Symbol}`** is the color of the system, observed for changes and
  represented as a Symbol. The color is toggled to highlight system activation.
- **`wall::Observable{Symbol}`** represents an aspect of the system's state, observed
  for changes and represented as a Symbol.
- **`file::String`** is the filename or path associated with the `EnergySystemDesign`.
- **`plots::Vector{Any}`** is a vector with all Makie object associated with this object.
  The value does not have to be provided.
"""
mutable struct EnergySystemDesign
    parent::Union{Symbol,Nothing}
    system::Dict
    id_to_color_map::Dict
    id_to_icon_map::Dict
    components::Vector{EnergySystemDesign}
    connections::Vector
    xy::Observable{Tuple{Real,Real}}
    icon::String
    color::Observable{Symbol}
    wall::Observable{Symbol}
    file::String
    plots::Vector{Any}
end
function EnergySystemDesign(
    parent::Union{Symbol,Nothing},
    system::Dict,
    id_to_color_map::Dict,
    id_to_icon_map::Dict,
    components::Vector{EnergySystemDesign},
    connections::Vector,
    xy::Observable{Tuple{Real,Real}},
    icon::String,
    color::Observable{Symbol},
    wall::Observable{Symbol},
    file::String,
)
    return EnergySystemDesign(
        parent,
        system,
        id_to_color_map,
        id_to_icon_map,
        components,
        connections,
        xy,
        icon,
        color,
        wall,
        file,
        Any[],
    )
end

"""
Mutable type for providing a flexible data structure for connections between
`EnergySystemDesign`s.

# Fields

- **`from::EnergySystemDesign`** is the `EnergySystemDesign` from which the connection
  originates.
- **`to::EnergySystemDesign`** is the `EnergySystemDesign` to which the connection is
  linked to.
- **`connection::Union{EMB.Link,EMG.Transmission}`** is the EMX connection structure.
- **`colors::Vector{RGB}`** is the associated colors of the connection
- **`plots::Vector{Any}`** is a vector with all Makie object associated with this object
"""
mutable struct Connection
    from::EnergySystemDesign
    to::EnergySystemDesign
    connection::Union{EMB.Link,EMG.Transmission}
    colors::Vector{RGB}
    plots::Vector{Any}
end
function Connection(
    from::EnergySystemDesign,
    to::EnergySystemDesign,
    connection::Union{EMB.Link,EMG.Transmission},
    id_to_color_map::Dict{Any,Any},
)
    colors::Vector{RGB} = get_resource_colors(connection, id_to_color_map)
    return Connection(from, to, connection, colors, Any[])
end

"""
The main type for the realization of the GUI.

# Fields

- **`fig::Figure`** is the figure handle to the main figure (window).
- **`axes::Dict{Symbol,Axis}`** is a collection of axes: :topo (axis for visualizing
  the topology), :results (axis for plotting operation analaysis), and :info (axis for
  displaying information).
- **`buttons::Dict{Symbol,Makie.Button}`** is a dictionary of the GLMakie buttons linked
  to the gui.axes[:topo] object.
- **`menus::Dict{Symbol,Makie.Menu}`** is a dictionary of the GLMakie menus linked to the
  gui.axes[:results] object.
- **`toggles::Dict{Symbol,Makie.Toggle}`** is a dictionary of the GLMakie toggles linked
  to the gui.axes[:results] object.
- **`root_design::EnergySystemDesign`** is the data structure used for the root topology.
- **`design::EnergySystemDesign`** is the data structure used for visualizing the topology.
- **`model::Model`** contains the optimization results.
- **`vars::Dict{Symbol,Any}`** is a dictionary of miscellaneous variables and parameters.
"""
mutable struct GUI
    fig::Figure
    axes::Dict{Symbol,Makie.Block}
    buttons::Dict{Symbol,Makie.Button}
    menus::Dict{Symbol,Makie.Menu}
    toggles::Dict{Symbol,Makie.Toggle}
    root_design::EnergySystemDesign
    design::EnergySystemDesign
    model::Model
    vars::Dict{Symbol,Any}
end

"""
    show(io::IO, obj::EnergySystemDesign)

Print a simplified overview of the fields of an EnergySystemDesign `obj`.
"""
function Base.show(io::IO, obj::EnergySystemDesign)
    indent_str::String = "  "
    println(io, "EnergySystemDesign with fields:")
    println(io, "  parent (Union{Symbol,Nothing}): ", obj.parent)
    println(io, "  system (Dict): ")
    for (key, value) ∈ obj.system
        println(io, indent_str, "  ", key, ": ", value)
    end
    println(io, "  id_to_color_map (Dict{Any,Any}): ", obj.id_to_color_map)
    println(io, "  id_to_icon_map (Dict{Any,Any}): ", obj.id_to_icon_map)
    println(io, "  components (Vector{EnergySystemDesign}): ")
    for (index, comp) ∈ enumerate(obj.components)
        if haskey(comp.system, :node)
            println(io, "    [", index, "] ", comp.system[:node])
        end
    end
    println(
        io, "  connections (Vector{Tuple{EnergySystemDesign, EnergySystemDesign, Dict}}): "
    )
    for (index, conn) ∈ enumerate(obj.connections)
        println(
            io, "    [", index, "] ", conn.from.system[:node], " - ", conn.to.system[:node]
        )
    end

    println(io, "  xy (Observable{Tuple{Real,Real}}): ", obj.xy)
    println(io, "  icon (Union{String,Nothing}): ", obj.icon)
    println(io, "  color (Observable{Symbol}): ", obj.color)
    println(io, "  wall (Observable{Symbol}): ", obj.wall)

    println(io, "  file (String): ", obj.file)
    return println(io, "  plots (Vector{Any}): ", obj.plots)
end

"""
    show(io::IO, con::Connection)

Print a simplified overview of the fields of a Connection `obj`.
"""
function Base.show(io::IO, con::Connection)
    return dump(io, con; maxdepth=2)
end

"""
    show(io::IO, obj::GUI)

Print a simplified overview of the fields of a GUI `gui`.
"""
function Base.show(io::IO, gui::GUI)
    return dump(io, gui; maxdepth=1)
end
