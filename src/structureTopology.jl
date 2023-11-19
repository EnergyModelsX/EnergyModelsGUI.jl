# This module is to create a constructor that create new objects of type EnergySystemDesign. 
#Module for visualization of Clean export models
using Observables
using FilterHelpers
using FileIO
using TOML
Δh = 0.05
#const dragging = Ref(false)

"""
    Fields:
    - `parent::Union{Symbol, Nothing}`: Parent reference or indicator.
    - `system::Dict`: Data related to the system, stored as key-value pairs.
    - `system_color::Symbol`: The color of the system represented as a Symbol.
    - `components::Vector{EnergySystemDesign}`: Components of the system, stored as an array of EnergySystemDesign objects.
    - `connectors::Vector{EnergySystemDesign}`: Connectors between different systems, stored as an array of EnergySystemDesign objects.
    - `connections::Vector{Tuple{EnergySystemDesign, EnergySystemDesign, Dict}}`: Connections between system parts, each represented as a tuple with two EnergySystemDesign objects and a dictionary for associated properties.
    - `xy::Observable{Tuple{Real,Real}}`: Coordinates of the system, observed for changes.
    - `icon::Union{String, Nothing}`: Optional icon associated with the system, stored as a string or Nothing.
    - `color::Observable{Symbol}`: Color of the system, observed for changes and represented as a Symbol.
    - `wall::Observable{Symbol}`: Represents an aspect of the system's state, observed for changes and represented as a Symbol.
    - `file::String`: Filename or path associated with the EnergySystemDesign.

    This struct provides a flexible data structure for modeling and working with complex energy system designs in Julia.

"""

mutable struct EnergySystemDesign
    # parameters::Vector{Parameter}
    # states::Vector{State}

    parent::Union{Symbol,Nothing}
    system::Dict
    system_color::Symbol
    components::Vector{EnergySystemDesign}
    connectors::Vector{EnergySystemDesign}
    connections::Vector{Tuple{EnergySystemDesign, EnergySystemDesign, Dict}}

    xy::Observable{Tuple{Real,Real}} #coordinates 
    icon::Union{String,Nothing}
    color::Observable{Symbol}
    wall::Observable{Symbol}

    file::String
end


# Define a copy function that is part of the Base module in Julia which contain fundamental functions and types. .copy to customize the behaviour for specific types
Base.copy(x::Tuple{EnergySystemDesign,EnergySystemDesign}) = (copy(x[1]), copy(x[2])) 

# Method to make a deep copy of an 'EnergySystemDesign' object
Base.copy(x::EnergySystemDesign) = EnergySystemDesign(
    x.parent,
    x.system,
    x.system_color,
    copy.(x.components), # create deep copy of array or collection contained within EnergySystemDesign object. 
    copy.(x.connectors),
    copy.(x.connections),
    Observable(x.xy[]),
    x.icon,
    Observable(x.system_color),
    Observable(x.wall[]),
    x.file,
)

"""
    This function creates and initializes instances of the `EnergySystemDesign` struct, representing energy system designs.

    Parameters:
    - `system::Dict`: A dictionary containing system-related data stored as key-value pairs.
    - `design_path::String`: A file path or identifier related to the design.
    - `x::Real = 0.0`: Initial x-coordinate of the system (default: 0.0).
    - `y::Real = 0.0`: Initial y-coordinate of the system (default: 0.0).
    - `icon::Union{String, Nothing} = nothing`: An icon associated with the system (default: nothing).
    - `wall::Symbol = :E`: An initial wall value (default: :E).
    - `parent::Union{Symbol, Nothing} = nothing`: An parent reference or indicator (default: nothing).
    - `kwargs...`: Additional keyword arguments.

    The function reads system configuration data from a TOML file specified by `design_path` (if it exists), initializes various internal fields,
    and processes connections and wall values. It constructs and returns an `EnergySystemDesign` instance.

"""

function EnergySystemDesign(
    system::Dict,
    design_path::String;
    x::Real = 0.0,
    y::Real = 0.0,
    icon = nothing,
    wall = :E,
    parent = nothing,
    kwargs...,
)
    file = design_file(system, design_path)
    design_dict = if isfile(file)
        TOML.parsefile(file)
    else
        Dict()
    end

    #systems = filter(x -> typeof(x) == ODESystem, ModelingToolkit.get_systems(system))
    #systems = system
    components = EnergySystemDesign[]
    connectors = EnergySystemDesign[]
    connections = Tuple{EnergySystemDesign,EnergySystemDesign,Dict}[]
    if haskey(system,:areas)
        parent_arg = Symbol("Toplevel")
    elseif haskey(system,:node)
        parent_arg = Symbol(system[:node])
    else
        parent_arg = Symbol("ParentNotFound")
    end
    xy = Observable((x, y)) #extracting coordinates
    if !isempty(system)

        process_children!(
            components,
            system,
            design_dict,
            design_path,
            parent_arg,
            xy,
            false;
            kwargs...,
        )
        process_children!(
            connectors,
            system,
            design_dict,
            design_path,
            parent_arg,
            xy,
            true;
            kwargs...,
        )
    end
    xy = Observable((x, y))
    color = :black
    for wall in [:E, :W, :N, :S]
        connectors_on_wall = filter(x -> get_wall(x) == wall, connectors)
        n = length(connectors_on_wall)
        if n > 1
            i = 0
            for conn in connectors_on_wall
                order = get_wall_order(conn)
                i = max(i, order) + 1
                if order == 0
                   conn.wall[] = Symbol(wall, i) 
                end
            end
        end
    end


    if haskey(system,:areas) && haskey(system,:transmission)
        connection_iterator =enumerate(system[:transmission])
        for (i, connection) in connection_iterator
            child_design_from = filtersingle(
                            x -> x.system[:node].An == system[:transmission][i].From.An,
                            components,
                        )
            if !isnothing(child_design_from)
                connector_design_from = filtersingle(
                    x -> x.system[:connector] == system[:transmission][i].From.An,
                    child_design_from.connectors,
                )
            end
            child_design_to = filtersingle(
                    x -> x.system[:node].An == system[:transmission][i].To.An,
                    components,
                )
            if !isnothing(child_design_to)
                connector_design_to = filtersingle(
                    x -> x.system[:connector] == system[:transmission][i].To.An,
                    child_design_to.connectors,
                )
            end
            connection_sys = Dict([(:connection, system[:transmission][i])])
            
            if !isnothing(connector_design_from) && !isnothing(connector_design_to)
                this_connection = (connector_design_from, connector_design_to,connection_sys)
                push!(connections, this_connection)
            end

            
        end
    elseif haskey(system,:nodes) && haskey(system,:links)
        connection_iterator =enumerate(system[:links])
        for (i, connection) in connection_iterator
            child_design_from = filtersingle(
                            x -> x.system[:node] == system[:links][i].from,
                            components,
                        )
            if !isnothing(child_design_from)
                connector_design_from = filtersingle(
                    x -> x.system[:connector] == system[:links][i].from,
                    child_design_from.connectors,
                )
            end
            child_design_to = filtersingle(
                    x -> x.system[:node] == system[:links][i].to,
                    components,
                )
            if !isnothing(child_design_to)
                connector_design_to = filtersingle(
                    x -> x.system[:connector] == system[:links][i].to,
                    child_design_to.connectors,
                )
            end
            connection_sys = Dict([(:connection, system[:links][i])])
            if !isnothing(connector_design_from) && !isnothing(connector_design_to)
                this_connection = (connector_design_from, connector_design_to,connection_sys)
                push!(connections, this_connection)
            end

            
        end
        
    end

    

    return EnergySystemDesign(
        parent,
        system,
        color,
        components,
        connectors,
        connections,
        xy,
        icon,
        Observable(color),
        Observable(wall),
        file,
    )
end

# Extracts the first character of the `wall` field as a `Symbol`.

get_wall(design::EnergySystemDesign) =  Symbol(string(design.wall[])[1])


"""
    This function extract and return the wall order from the `wall` field of an `EnergySystemDesign`.

    Parameters:
    - `design::EnergySystemDesign`: An instance of the `EnergySystemDesign` struct.

    Returns:
    An integer representing the wall order, or 0 if not found.
"""

function get_wall_order(design::EnergySystemDesign)

    wall = string(design.wall[])
    if length(wall) > 1
        order = tryparse(Int, wall[2:end])

        if isnothing(order)
            order = 1
        end

        return order
    else


        return 0

    end


end

function design_file(system::Dict, path::String)
    #@assert !isnothing(system.gui_metadata) "ODESystem must use @component: $(system.name)"

    # path = joinpath(@__DIR__, "designs")
    if !isdir(path)
        mkdir(path)
    end
    if !haskey(system,:node)
        systemName = "TopLevel"
    else
        systemName = string(system[:node])
    end
    #parts = split(string(system.gui_metadata.type), '.')
    #for part in parts[1:end-1]
    #    path = joinpath(path, part)
    #    if !isdir(path)
    #        mkdir(path)
    #    end
    #end
    file = joinpath(path, "$(systemName).toml")

    return file
end


"""
    Function to place nodes evenly in a circle
"""

function place_nodes_in_circle(total_nodes::Int, current_node::Int, distance::Real, start_x::Real, start_y::Real)
    angle = 2π * current_node / total_nodes
    x = start_x + distance * cos(angle)
    y = start_y + distance * sin(angle)
    return x, y
end

"""
    Generates a design path based on the type of the `system` field in an `EnergySystemDesign` instance.
"""
function get_design_path(design::EnergySystemDesign)
    type = string(typeof(design.system[:node]))
    parts = split(type, '.')
    path = joinpath(parts[1:end-1]..., "$(parts[end]).toml")
    return replace(design.file, path => "")
end

safe_connector_name(name::Symbol) = Symbol("_$name")


"""
    Function to find the icon associated with a given system's node type.
"""
function find_icon(system::Dict, design_path::String)
    icon_name = "NotFound"
    if haskey(system,:node)
        icon_name = string(typeof(system[:node]))
    end
    icon = joinpath(@__DIR__, "..", "icons", "$icon_name.png")
    isfile(icon) && return icon
    return joinpath(@__DIR__,"..", "icons", "NotFound.png")
end

find_icon(design::EnergySystemDesign) = find_icon(design.system, get_design_path(design))

"""
    Processes children or components within an energy system design and populates the `children` vector.

    Parameters:
    - `children::Vector{EnergySystemDesign}`: A vector to store child `EnergySystemDesign` instances.
    - `systems::Dict`: The system configuration data represented as a dictionary.
    - `design_dict::Dict`: A dictionary containing design-specific data.
    - `design_path::String`: A file path or identifier related to the design.
    - `parent::Symbol`: A symbol representing the parent of the children.
    - `parent_xy::Observable{Tuple{T,T}}`: An observable tuple holding the coordinates of the parent, where T is a subtype of Real.
    - `is_connector::Bool = false`: A boolean indicating whether the children are connectors (default: false).
    - `connectors...`: Additional keyword arguments.
"""

function process_children!(
    children::Vector{EnergySystemDesign},
    systems::Dict,
    design_dict::Dict,
    design_path::String,
    parent::Symbol,
    parent_xy::Observable{Tuple{T,T}},
    is_connector = false;
    connectors...,
) where T <: Real
    system_iterator = nothing
    if haskey(systems,:areas) && !is_connector
        system_iterator = enumerate(systems[:areas])
    elseif haskey(systems,:nodes) && !is_connector
        system_iterator = enumerate(systems[:nodes])
    elseif haskey(systems,:node) && is_connector
        system_iterator = enumerate([systems[:node]])
    end
    parent_x, parent_y = parent_xy[] # we get these from constructor
    if !isempty(systems) && !isnothing(system_iterator)
        current_node = 1
        for (i, system) in system_iterator
            
            key = string(typeof(system))
            kwargs = if haskey(design_dict, key)
                design_dict[key]
            else
                Dict()
            end
        
            kwargs_pair = Pair[]
        
            
            push!(kwargs_pair, :parent => parent)
        
            if !is_connector
                #if x and y are missing, add defaults
                if key == "RefArea"
                    if hasproperty(system,:Lon) && hasproperty(system,:Lat)
                        push!(kwargs_pair, :x => system.Lon) #assigning long and lat
                        push!(kwargs_pair, :y => system.Lat)
                    end
                elseif !haskey(kwargs, "x") & !haskey(kwargs, "y") & haskey(systems,:nodes)
                    nodes_count = length(systems[:nodes])
                    
                    if key == "GenAvailability" || key == "GeoAvailability" # second layer of topology, no need of coordinate inside the region, and make a circle
                        x=parent_x
                        y=parent_y
                    else
                        x,y = place_nodes_in_circle(nodes_count-1,current_node,1,parent_x,parent_y)
                        current_node +=1
                    end
                    push!(kwargs_pair, :x => x)
                    push!(kwargs_pair, :y => y)
                elseif !haskey(kwargs, "x") & !haskey(kwargs, "y") # x=0, y=0. Fallback condition
                    push!(kwargs_pair, :x => i * 3 * Δh)
                    push!(kwargs_pair, :y => i * Δh)
                end
        
                # r => wall for icon rotation
                if haskey(kwargs, "r")
                    push!(kwargs_pair, :wall => kwargs["r"])
                end
            elseif is_connector
                if hasproperty(system,:An)
                    if haskey(connectors, safe_connector_name(Symbol(system.An)))
                        push!(kwargs_pair, :wall => connectors[safe_connector_name(Symbol(system.An))])
                    end
                else
                    if haskey(connectors, safe_connector_name(Symbol(system)))
                        push!(kwargs_pair, :wall => connectors[safe_connector_name(Symbol(system))])
                    end
                end
                x=parent_x
                y=parent_y
                push!(kwargs_pair, :x => x)
                push!(kwargs_pair, :y => y)
            end
        
            for (key, value) in kwargs
                push!(kwargs_pair, Symbol(key) => value)
            end
            if haskey(systems,:areas) && !is_connector
                area_An = systems[:areas][i].An
                area_links = filter(item->getfield(item,:from) == area_An || getfield(item,:to) == area_An,systems[:links]) 
                area_nodes = filter(item -> any(link -> link.from == item || link.to == item, area_links),systems[:nodes])
                this_sys = Dict([(:node, system),(:links,area_links),(:nodes,area_nodes)])
            elseif !is_connector
                this_sys = Dict([(:node, system)])
            elseif is_connector && hasproperty(system,:An)
                this_sys = Dict([(:connector, system.An)])
            elseif is_connector
                this_sys = Dict([(:connector, system)])
            end
            push!(kwargs_pair, :icon => find_icon(this_sys, design_path))
        
            
            push!(
                children,
                EnergySystemDesign(this_sys, design_path; NamedTuple(kwargs_pair)...),
            )
        end
    end
end

