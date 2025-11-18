"""
    AbstractGUIObj

Supertype for EnergyModelsGUI objects representing `Node`s/`Link`s/`Area`s/`Transmission`s.
"""
abstract type AbstractGUIObj end

"""
    NothingDesign <: AbstractGUIObj

Type for representing a non-existent design.
"""
struct NothingDesign <: AbstractGUIObj end

"""
    AbstractSystem

Supertype for EnergyModelsGUI objects representing a sub system of a Case.
"""
abstract type AbstractSystem <: AbstractCase end

"""
    NothingElement <: AbstractElement

Type for representing an empty Element (the "nothing" element).
"""
struct NothingElement <: AbstractElement end

"""
    System

Type for storing processed system data from EnergyModelsBase.

# Fields
- **`T::TimeStructure`** is the time structure of the model.
- **`products::Vector{<:Resource}`** are the resources that should be incorporated into the
  model.
- **`elements::Vector{Vector}`** are the vectors of `AbstractElement`
  that should be included in the analysis.
- **`children::Vector{<:EMB.Node}`** are the children of the system.
- **`connections::Vector{<:Link}`** are the connections between system parts.
- **`parent::AbstractElement`** is the parent of the system (e.g., the `Area` node of the reference `GeoAvailability` node).
- **`ref_element::AbstractElement`** is the reference element of the system (first `Availability` node).
"""
struct System <: AbstractSystem
    T::TimeStructure
    products::Vector{<:Resource}
    elements::Vector{Vector}
    children::Vector{<:EMB.Node}
    connections::Vector{<:Link}
    parent::AbstractElement
    ref_element::AbstractElement
end
function System(case::Case)
    # Find the first availability node and set it as the parent if present
    first_av = getfirst(x -> isa(x, Availability), get_nodes(case))
    ref_element = isnothing(first_av) ? NothingElement() : first_av
    return System(
        get_time_struct(case),
        get_products(case),
        get_elements_vec(case),
        get_nodes(case),
        get_links(case),
        NothingElement(),
        ref_element,
    )
end

"""
    SystemGeo

Type for storing processed system data from EnergyModelsGeography.

# Fields
- **`T::TimeStructure`** is the time structure of the model.
- **`products::Vector{<:Resource}`** are the resources that should be incorporated into the
  model.
- **`elements::Vector{Vector}`** are the vectors of `AbstractElement`
  that should be included in the analysis.
- **`children::Vector{<:EMB.Node}`** are the children of the system.
- **`connections::Vector{<:Link}`** are the connections between system parts.
- **`parent::AbstractElement`** is the parent of the system.
- **`ref_element::AbstractElement`** is the reference element of the system.
"""
struct SystemGeo <: AbstractSystem
    T::TimeStructure
    products::Vector{<:Resource}
    elements::Vector{Vector}
    children::Vector{<:AbstractElement}
    connections::Vector{<:AbstractElement}
    parent::AbstractElement
    ref_element::AbstractElement
end

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

- **`system::AbstractSystem`** is the data related to the system.
- **`id_to_color_map::Dict`** is a dictionary of resources and their assigned colors.
- **`id_to_icon_map::Dict`** is a dictionary of nodes and their assigned icons.
- **`components::Vector{EnergySystemDesign}`** is the components of the system, stored
  as an array of EnergySystemDesign objects.
- **`connections::Vector{Connection}`** are the connections between system parts.
- **`parent::AbstractGUIObj`** is the parent of the system.
- **`xy::Observable{<:Point2f}`** is the coordinate of the system, observed for changes.
- **`icon::String`** is the optional (path to) icons associated with the system, stored as
  a string.
- **`color::Observable{RGBA{Float32}}`** is the color of the system, observed for changes. 
  The color is toggled to highlight system activation.
- **`wall::Observable{Symbol}`** represents an aspect of the system's state, observed
  for changes and represented as a Symbol.
- **`file::String`** is the filename or path associated with the `EnergySystemDesign`.
- **`plots::Vector{Any}`** is a vector with all Makie object associated with this object.
  The value does not have to be provided.
- **`invest_data::ProcInvData`** stores processed investment data.
"""
mutable struct EnergySystemDesign <: AbstractGUIObj
    system::AbstractSystem
    id_to_color_map::Dict
    id_to_icon_map::Dict
    components::Vector{EnergySystemDesign}
    connections::Vector
    parent::AbstractGUIObj
    xy::Observable{<:Point2f}
    icon::String
    color::Observable{RGBA{Float32}}
    wall::Observable{Symbol}
    file::String
    inv_data::ProcInvData
    plots::Vector{Any}
end
function EnergySystemDesign(
    system::AbstractSystem,
    id_to_color_map::Dict,
    id_to_icon_map::Dict,
    components::Vector{EnergySystemDesign},
    connections::Vector,
    parent::AbstractGUIObj,
    xy::Observable{<:Point2f},
    icon::String,
    color::Observable{RGBA{Float32}},
    wall::Observable{Symbol},
    file::String,
)
    return EnergySystemDesign(
        system,
        id_to_color_map,
        id_to_icon_map,
        components,
        connections,
        parent,
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
- **`connection::AbstractElement`** is the EMX connection structure.
- **`colors::Vector{RGBA{Float32}}`** is the associated colors of the connection.
- **`plots::Vector{Any}`** is a vector with all Makie object associated with this object.
- **`invest_data::ProcInvData`** stores processed investment data.
"""
mutable struct Connection <: AbstractGUIObj
    from::EnergySystemDesign
    to::EnergySystemDesign
    connection::AbstractElement
    colors::Vector{RGBA{Float32}}
    inv_data::ProcInvData
    plots::Vector{Any}
end
function Connection(
    from::EnergySystemDesign,
    to::EnergySystemDesign,
    connection::AbstractElement,
    id_to_color_map::Dict{Any,Any},
)
    colors::Vector{RGBA{Float32}} = get_resource_colors(connection, id_to_color_map)
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
- **`screen::GLMakie.Screen`** is the screen handle for displaying the figure.
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
- **`model::Union{Model, Dict}`** contains the optimization results.
- **`vars::Dict{Symbol,Any}`** is a dictionary of miscellaneous variables and parameters.
"""
mutable struct GUI
    fig::Figure
    screen::GLMakie.Screen
    axes::Dict{Symbol,Makie.Block}
    legends::Dict{Symbol,Union{Makie.Legend,Nothing}}
    buttons::Dict{Symbol,Makie.Button}
    menus::Dict{Symbol,Makie.Menu}
    toggles::Dict{Symbol,Makie.Toggle}
    root_design::EnergySystemDesign
    design::EnergySystemDesign
    model::Union{Model,Dict}
    vars::Dict{Symbol,Any}
end

"""
    PlotContainer{T}

Type for storing plot-related data available from the "Data" menu.

# Fields

- **`name::String`**: is the reference name for the data.
- **`selection::Vector`**: is the indices used to extract the data to be plotted.
- **`field_data::Any`**: is the data from which plots are extracted based on selection.
- **`description::String`**: is the description to be used for the legend.
"""
struct PlotContainer{T}
    name::String
    selection::Vector
    field_data::Any
    description::String
end

# Create aliases for different PlotContainer types
const JuMPContainer = PlotContainer{:JuMP}
const CaseDataContainer = PlotContainer{:CaseData}
const GlobalDataContainer = PlotContainer{:GlobalData}

# Define standard colours in EMGUI
const BLACK = RGBA{Float32}(0.0, 0.0, 0.0, 1.0)
const WHITE = RGBA{Float32}(1.0, 1.0, 1.0, 1.0)
const GREEN2 = RGBA{Float32}(0.0, 0.93333334, 0.0, 1.0)
const RED = RGBA{Float32}(1.0, 0.0, 0.0, 1.0)
const YELLOW = RGBA{Float32}(1.0, 1.0, 0.0, 1.0)
const MAGENTA = RGBA{Float32}(1.0, 0.0, 1.0, 1.0)
const CYAN = RGBA{Float32}(0.0, 1.0, 1.0, 1.0)

Base.show(io::IO, obj::AbstractGUIObj) = dump(io, obj; maxdepth = 1)
Base.show(::IO, ::NothingDesign) = ""
Base.show(io::IO, obj::ProcInvData) = dump(io, obj; maxdepth = 1)
Base.show(io::IO, system::AbstractSystem) = dump(io, system; maxdepth = 1)
Base.show(io::IO, gui::GUI) = dump(io, gui; maxdepth = 1)
Base.show(io::IO, ::NothingElement) = print(io, "top_level")

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
    EMB.get_time_struct(system::AbstractSystem)

Returns the time structure of the AbstractSystem `system`.
"""
EMB.get_time_struct(system::AbstractSystem) = system.T

"""
    EMB.get_products(system::AbstractSystem)

Returns the vector of products of the AbstractSystem `system`.
"""
EMB.get_products(system::AbstractSystem) = system.products

"""
    EMB.get_elements_vec(system::AbstractSystem)

Returns the vector of element-vectors of the AbstractSystem `system`.
"""
EMB.get_elements_vec(system::AbstractSystem) = system.elements

"""
    get_children(system::AbstractSystem)

Returns the `parent` field of a `AbstractSystem` `system`.
"""
get_children(system::AbstractSystem) = system.children

"""
    get_connections(system::AbstractSystem)

Returns the `connections` field of a `AbstractSystem` `system`.
"""
get_connections(system::AbstractSystem) = system.connections

"""
    get_parent(system::AbstractSystem)

Returns the `parent` field of a `AbstractSystem` `system`.
"""
get_parent(system::AbstractSystem) = system.parent

"""
    get_ref_element(system::AbstractSystem)

Returns the `ref_element` field of a `AbstractSystem` `system`.
"""
get_ref_element(system::AbstractSystem) = system.ref_element

"""
    EMB.get_links(system::AbstractSystem)

Returns the links of a `AbstractSystem` `system`.
"""
EMB.get_links(system::AbstractSystem) = get_connections(system)

"""
    EMB.get_nodes(system::AbstractSystem)

Returns the nodes of a `AbstractSystem` `system`.
"""
EMB.get_nodes(system::AbstractSystem) = get_children(system)

"""
    get_element(system::System)

Returns the `element` assosiated of a `System` `system`.
"""
get_element(system::System) = get_parent(system)

"""
    get_plotables(system::System)

Returns the `Node`s and `Link`s of a `System` `system`.
"""
get_plotables(system::System) = vcat(get_nodes(system), get_links(system))

"""
    get_system(design::EnergySystemDesign)

Returns the `system` field of a `EnergySystemDesign` `design`.
"""
get_system(design::EnergySystemDesign) = design.system

"""
    get_parent(design::EnergySystemDesign)

Returns the `parent` field of a `EnergySystemDesign` `design`.
"""
get_parent(design::EnergySystemDesign) = design.parent

"""
    get_element(design::EnergySystemDesign)

Returns the system node (*i.e.*, availability node for areas) of a `EnergySystemDesign` `design`.
"""
get_element(design::EnergySystemDesign) = get_element(get_system(design))

"""
    get_components(design::EnergySystemDesign)

Returns the `components` field of a `EnergySystemDesign` `design`.
"""
get_components(design::EnergySystemDesign) = design.components

"""
    get_component(designs::Vector{EnergySystemDesign}, id)
    get_component(designs::EnergySystemDesign, id)

Extract the component from a vector of `EnergySystemDesign`(s) that has a `parent` with 
the given `id`.
"""
function get_component(designs::Vector{EnergySystemDesign}, id)
    for design ∈ designs
        if get_parent(get_system(design)).id == id
            return design
        end
    end
end
get_component(designs::EnergySystemDesign, id) = get_component(get_components(designs), id)

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
    EMB.get_time_struct(design::EnergySystemDesign)

Returns the time structure of the EnergySystemDesign `design`.
"""
EMB.get_time_struct(design::EnergySystemDesign) = EMB.get_time_struct(get_system(design))

"""
    get_ref_element(design::EnergySystemDesign)

Returns the `ref_element` field of a `EnergySystemDesign` `design`.
"""
get_ref_element(design::EnergySystemDesign) = get_ref_element(get_system(design))

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
    get_inv_data(obj::AbstractGUIObj)

Returns the `inv_data` field of a `AbstractGUIObj` `obj`.
"""
get_inv_data(obj::AbstractGUIObj) = obj.inv_data

"""
    get_plots(obj::AbstractGUIObj)

Returns the `plots` field of a `AbstractGUIObj` `obj`.
"""
get_plots(obj::AbstractGUIObj) = obj.plots

"""
    get_fig(gui::GUI)

Returns the `fig` field of a `GUI` `gui`.
"""
get_fig(gui::GUI) = gui.fig

"""
    get_screen(gui::GUI)

Returns the `screen` field of a `GUI` `gui`.
"""
get_screen(gui::GUI) = gui.screen

"""
    close(gui::GUI)

Closes the GUI `gui`.
"""
close(gui::GUI) = GLMakie.close(get_screen(gui))

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

"""
    EMB.get_time_struct(gui::GUI)

Returns the time structure of the GUI `gui`.
"""
EMB.get_time_struct(gui::GUI) = EMB.get_time_struct(get_design(gui))

"""
    get_parent(gui::GUI)

Returns the `parent` field of a `GUI` `gui`.
"""
get_parent(gui::GUI) = get_parent(get_design(gui))

"""
    get_system(gui::GUI)

Returns the `system` field in the `design` field of a `GUI` `gui`.
"""
get_system(gui::GUI) = get_system(get_design(gui))

"""
    get_name(container::PlotContainer)

Returns the `name` field of a `PlotContainer` `container`.
"""
get_name(container::PlotContainer) = container.name

"""
    get_selection(container::PlotContainer)

Returns the `selection` field of a `PlotContainer` `container`.
"""
get_selection(container::PlotContainer) = container.selection

"""
    get_field_data(container::PlotContainer)

Returns the `field_data` field of a `PlotContainer` `container`.
"""
get_field_data(container::PlotContainer) = container.field_data

"""
    get_description(container::PlotContainer)

Returns the `description` field of a `PlotContainer` `container`.
"""
get_description(container::PlotContainer) = container.description
