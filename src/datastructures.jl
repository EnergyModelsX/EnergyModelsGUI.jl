"""
    AbstractGUIObj

Supertype for EnergyModelsGUI objects representing `Node`s/`Link`s/`Area`s/`Transmission`s.
"""
abstract type AbstractGUIObj end

"""
    ProcInvData

Type for storing processed investment data.

# Fields

- **`inv_times::Vector{String}`** is a vector of formatted strings for added investments.
- **`capex::Vector{Number}`** contains the capex of all times with added investments.
- **`invested::Bool`** indicates if the element has been invested in.
"""
struct ProcInvData{T<:Number}
    inv_times::Vector{String}
    capex::Vector{T}
    invested::Bool
end
function ProcInvData()
    return ProcInvData(String[], Vector{Number}(), false)
end

"""
    EnergySystemDesign <: AbstractGUIObj

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
- **`invest_data::ProcInvData`** stores processed investment data.
"""
mutable struct EnergySystemDesign <: AbstractGUIObj
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
    inv_data::ProcInvData
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
        ProcInvData(),
        Any[],
    )
end

"""
    Connection <: AbstractGUIObj

Mutable type for providing a flexible data structure for connections between
`EnergySystemDesign`s.

# Fields

- **`from::EnergySystemDesign`** is the `EnergySystemDesign` from which the connection
  originates.
- **`to::EnergySystemDesign`** is the `EnergySystemDesign` to which the connection is
  linked to.
- **`connection::Union{Link,Transmission}`** is the EMX connection structure.
- **`colors::Vector{RGB}`** is the associated colors of the connection.
- **`plots::Vector{Any}`** is a vector with all Makie object associated with this object.
- **`invest_data::ProcInvData`** stores processed investment data.
"""
mutable struct Connection <: AbstractGUIObj
    from::EnergySystemDesign
    to::EnergySystemDesign
    connection::Union{Link,Transmission}
    colors::Vector{RGB}
    inv_data::ProcInvData
    plots::Vector{Any}
end
function Connection(
    from::EnergySystemDesign,
    to::EnergySystemDesign,
    connection::Union{Link,Transmission},
    id_to_color_map::Dict{Any,Any},
)
    colors::Vector{RGB} = get_resource_colors(connection, id_to_color_map)
    return Connection(from, to, connection, colors, ProcInvData(), Any[])
end

"""
    EnergySystemIterator

Type for iterating over nested `EnergySystemDesign` structures, enabling
recursion through `AbstractGUIObj`s.

# Fields

- **`stack::Vector{<:AbstractGUIObj}`** is the stack used to manage the iteration
  through the nested `EnergySystemDesign` components (and its connections).
  It starts with the initial `EnergySystemDesign` object and progressively includes its
  subcomponents as the iteration proceeds.
"""
struct EnergySystemIterator
    stack::Vector{AbstractGUIObj}
end

"""
    GUI

The main type for the realization of the GUI.

# Fields

- **`fig::Figure`** is the figure handle to the main figure (window).
- **`axes::Dict{Symbol,Axis}`** is a collection of axes: :topo (axis for visualizing
  the topology), :results (axis for plotting results), and :info (axis for
  displaying information).
- **`legends::Dict{Symbol,Legend}`** is a collection of legends: :topo (legend for
  the topology), :results (legend for plotting results).
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
    legends::Dict{Symbol,Union{Makie.Legend,Nothing}}
    buttons::Dict{Symbol,Makie.Button}
    menus::Dict{Symbol,Makie.Menu}
    toggles::Dict{Symbol,Makie.Toggle}
    root_design::EnergySystemDesign
    design::EnergySystemDesign
    model::Model
    vars::Dict{Symbol,Any}
end

function Base.show(io::IO, obj::AbstractGUIObj)
    return dump(io, obj; maxdepth = 1)
end

function Base.show(io::IO, obj::ProcInvData)
    return dump(io, obj; maxdepth = 1)
end

function Base.show(io::IO, gui::GUI)
    return dump(io, gui; maxdepth = 1)
end

function EnergySystemIterator(design::EnergySystemDesign)
    vector = AbstractGUIObj[]
    push!(vector, design.components...)  # Add the components to the stack
    push!(vector, design.connections...)  # Add the connections to the stack
    for des ∈ design.components
        _get_components(des, vector)
    end
    return EnergySystemIterator(vector)
end

function _get_components(design::EnergySystemDesign, vector)
    push!(vector, design.components...)  # Add the components to the stack
    push!(vector, design.connections...)  # Add the connections to the stack
    for des ∈ design.components
        _get_components(des, vector)
    end
end

"""
    iterate(itr::EnergySystemIterator)

Initialize the iteration over an `EnergySystemIterator`, returning the first `EnergySystemDesign` object
in the stack and the iterator itself. If the stack is empty, return `nothing`.
"""
function Base.iterate(itr::EnergySystemIterator, state = nothing)
    idx = isnothing(state) ? 1 : state + 1
    idx === length(itr) + 1 && return nothing
    return itr.stack[idx], idx
end
Base.length(itr::EnergySystemIterator) = length(itr.stack)
Base.length(design::EnergySystemDesign) = length(EnergySystemIterator(design))

function Base.iterate(design::EnergySystemDesign, state = (nothing, nothing))
    itr = isnothing(state[2]) ? EnergySystemIterator(design) : state[2]
    state[1] === length(itr) && return nothing
    next = isnothing(state[1]) ? iterate(itr) : iterate(itr, state[1])
    return next[1], (next[2], itr)
end

"""
    get_parent(design::EnergySystemDesign)

Returns the `parent` field of a `EnergySystemDesign` `design`.
"""
get_parent(design::EnergySystemDesign) = design.parent

"""
    get_system(design::EnergySystemDesign)

Returns the `system` field of a `EnergySystemDesign` `design`.
"""
get_system(design::EnergySystemDesign) = design.system

"""
    get_element(design::EnergySystemDesign)

Returns the system node (i.e. availability node for areas) of a `EnergySystemDesign` `design`.
"""
function get_element(design::EnergySystemDesign)
    if !isnothing(design.parent)
        return design.system[:node]
    end
end

"""
    get_components(design::EnergySystemDesign)

Returns the `components` field of a `EnergySystemDesign` `design`.
"""
get_components(design::EnergySystemDesign) = design.components

"""
    get_connections(design::EnergySystemDesign)

Returns the `connections` field of a `EnergySystemDesign` `design`.
"""
get_connections(design::EnergySystemDesign) = design.connections

"""
    get_xy(design::EnergySystemDesign)

Returns the `xy` field of a `EnergySystemDesign` `design`.
"""
get_xy(design::EnergySystemDesign) = design.xy

"""
    get_icon(design::EnergySystemDesign)

Returns the `icon` field of a `EnergySystemDesign` `design`.
"""
get_icon(design::EnergySystemDesign) = design.icon

"""
    get_color(design::EnergySystemDesign)

Returns the `color` field of a `EnergySystemDesign` `design`.
"""
get_color(design::EnergySystemDesign) = design.color

"""
    get_wall(design::EnergySystemDesign)

Returns the `wall` field of a `EnergySystemDesign` `design`.
"""
get_wall(design::EnergySystemDesign) = design.wall

"""
    get_file(design::EnergySystemDesign)

Returns the `file` field of a `EnergySystemDesign` `design`.
"""
get_file(design::EnergySystemDesign) = design.file

"""
    get_inv_data(design::EnergySystemDesign)

Returns the `inv_data` field of a `EnergySystemDesign` `design`.
"""
get_inv_data(design::EnergySystemDesign) = design.inv_data

"""
    get_plots(design::EnergySystemDesign)

Returns the `plots` field of a `EnergySystemDesign` `design`.
"""
get_plots(design::EnergySystemDesign) = design.plots

"""
    get_from(conn::Connection)

Returns the `from` field of a `Connection` `conn`.
"""
get_from(conn::Connection) = conn.from

"""
    get_to(conn::Connection)

Returns the `to` field of a `Connection` `conn`.
"""
get_to(conn::Connection) = conn.to

"""
    get_element(conn::Connection)

Returns the assosiated `Transmission`/`Link` of conn
"""
get_element(conn::Connection) = conn.connection

"""
    get_colors(conn::Connection)

Returns the `colors` field of a `Connection` `conn`.
"""
get_colors(conn::Connection) = conn.colors

"""
    get_inv_data(design::Connection)

Returns the `inv_data` field of a `Connection` `design`.
"""
get_inv_data(design::Connection) = design.inv_data

"""
    get_plots(conn::Connection)

Returns the `plots` field of a `Connection` `conn`.
"""
get_plots(conn::Connection) = conn.plots

"""
    get_inv_times(data::ProcInvData)
    get_inv_times(design::AbstractGUIObj)

Returns the `inv_times` field of a `ProcInvData`/`AbstractGUIObj` object `data`.
"""
get_inv_times(data::ProcInvData) = data.inv_times
get_inv_times(design::AbstractGUIObj) = get_inv_times(get_inv_data(design))

"""
    get_capex(data::ProcInvData)
    get_capex(design::AbstractGUIObj)

Returns the `capex` of the investments of a `ProcInvData`/`AbstractGUIObj` object `data`.
"""
get_capex(data::ProcInvData) = data.capex
get_capex(design::AbstractGUIObj) = get_capex(get_inv_data(design))

"""
    has_invested(data::ProcInvData)
    has_invested(data::AbstractGUIObj)

Returns a boolean indicator if investment has occured.
"""
has_invested(data::ProcInvData) = data.invested
has_invested(design::AbstractGUIObj) = has_invested(get_inv_data(design))

"""
    get_fig(gui::GUI)

Returns the `fig` field of a `GUI` `gui`.
"""
get_fig(gui::GUI) = gui.fig

"""
    get_axes(gui::GUI)

Returns the `axes` field of a `GUI` `gui`.
"""
get_axes(gui::GUI) = gui.axes

"""
    get_ax(gui::GUI, ax_name::Symbol)

Returns the `ax` object with name `ax_name` of a `GUI` `gui`.
"""
get_ax(gui::GUI, ax_name) = gui.axes[ax_name]

"""
    get_legend(gui::GUI, key::Symbol)

Returns the `legend` object `key` of a `GUI` `gui`.
"""
get_legend(gui::GUI, key::Symbol) = gui.legends[key]

"""
    get_button(gui::GUI, button_name::Symbol)

Returns the `button` with name `button_name` of a `GUI` `gui`.
"""
get_button(gui::GUI, button_name::Symbol) = gui.buttons[button_name]

"""
    get_menus(gui::GUI)

Returns the `menus` field of a `GUI` `gui`.
"""
get_menus(gui::GUI) = gui.menus

"""
    get_menu(gui::GUI, menu_name::Symbol)

Returns the `menu` with name `menu_name` of a `GUI` `gui`.
"""
get_menu(gui::GUI, menu_name::Symbol) = gui.menus[menu_name]

"""
    get_toggles(gui::GUI, toggle_name::Symbol)

Returns the `toggle` with name `toggle_name` of a `GUI` `gui`.
"""
get_toggle(gui::GUI, toggle_name::Symbol) = gui.toggles[toggle_name]

"""
    get_root_design(gui::GUI)

Returns the `root_design` field of a `GUI` `gui`.
"""
get_root_design(gui::GUI) = gui.root_design

"""
    get_design(gui::GUI)

Returns the `design` field of a `GUI` `gui`.
"""
get_design(gui::GUI) = gui.design

"""
    get_model(gui::GUI)

Returns the `model` field of a `GUI` `gui`.
"""
get_model(gui::GUI) = gui.model

"""
    get_vars(gui::GUI)

Returns the `vars` field of a `GUI` `gui`.
"""
get_vars(gui::GUI) = gui.vars

"""
    get_var(gui::GUI, key::Symbol)

Returns the `vars` field at `key` of a `GUI` `gui`.
"""
get_var(gui::GUI, key::Symbol) = gui.vars[key]

"""
    get_selected_systems(gui::GUI)

Get the selected systems from the `gui`.
"""
get_selected_systems(gui::GUI) = get_var(gui, :selected_systems)

"""
    get_selected_plots(gui::GUI, time_axis::Symbol)

Get the selected plots from the `gui` in the category `time_axis`.
"""
get_selected_plots(gui::GUI, time_axis::Symbol) =
    [x for x ∈ get_var(gui, :plotted_data) if x[:selected] && x[:time_axis] == time_axis]

"""
    get_plotted_data(gui::GUI)

Get the plots from the `gui`.
"""
get_plotted_data(gui::GUI) = get_var(gui, :plotted_data)

"""
    get_visible_data(gui::GUI, time_axis::Symbol)

Get the visible plots from the `gui` in the category `time_axis`.
"""
get_visible_data(gui::GUI, time_axis::Symbol) =
    [x for x ∈ get_var(gui, :plotted_data) if x[:visible] && x[:time_axis] == time_axis]

"""
    get_topo_legend(gui::GUI)

Get the legend from the topology axis from the `gui`.
"""
get_topo_legend(gui::GUI) = get_legend(gui, :topo)

"""
    get_results_legend(gui::GUI)

Get the legend from the current visible time axis from the `gui`.
"""
get_results_legend(gui::GUI) = get_legend(gui, :results)

"""
    get_available_data(gui::GUI)

Get the vector of containers for the available data from the `gui`.
"""
get_available_data(gui::GUI) = get_var(gui, :available_data)

"""
    get_selection_color(gui::GUI)

Get the selection color for the `gui`.
"""
get_selection_color(gui::GUI) = get_var(gui, :selection_color)
