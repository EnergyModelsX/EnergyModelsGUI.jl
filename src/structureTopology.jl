"""
Struct to provides a flexible data structure for modeling and working with complex energy system designs in Julia.

# Fields:
- `parent::Union{Symbol, Nothing}`: Parent reference or indicator.
- `system::Dict`: Data related to the system, stored as key-value pairs.
- `system_color::Symbol`: The color of the system represented as a Symbol.
- `components::Vector{EnergySystemDesign}`: Components of the system, stored as an array of EnergySystemDesign objects.
- `connections::Vector{Tuple{EnergySystemDesign, EnergySystemDesign, Dict}}`: Connections between system parts, each represented as a tuple with two EnergySystemDesign objects and a dictionary for associated properties.
- `xy::Observable{Tuple{Real,Real}}`: Coordinates of the system, observed for changes.
- `icon::Union{String, Nothing}`: Optional icon associated with the system, stored as a string or Nothing.
- `color::Observable{Symbol}`: Color of the system, observed for changes and represented as a Symbol.
- `wall::Observable{Symbol}`: Represents an aspect of the system's state, observed for changes and represented as a Symbol.
- `file::String`: Filename or path associated with the EnergySystemDesign.
"""
mutable struct EnergySystemDesign
    parent::Union{Symbol,Nothing}
    system::Dict
    idToColorsMap::Dict{Any,Any}
    idToIconsMap::Dict{Any,Any}
    system_color::Symbol
    components::Vector{EnergySystemDesign}
    connections::Vector{Tuple{EnergySystemDesign, EnergySystemDesign, Dict}}
    xy::Observable{Tuple{Real,Real}} #coordinates 
    icon::Union{String,Nothing}
    color::Observable{Symbol}
    wall::Observable{Symbol}
    file::String
    plotObj::Vector{Any}
end

"""
    show(io::IO, obj::EnergySystemDesign)

Print a simplified overview of the fields of an EnergySystemDesign struct
"""
function Base.show(io::IO, obj::EnergySystemDesign)
    indent = 1
    indent_str = "  " ^ indent
    println(io, "EnergySystemDesign with fields:")
    println(io, "  parent (Union{Symbol,Nothing}): ", obj.parent)
    println(io, "  system (Dict): ")
    for (key, value) ∈ obj.system
        println(io, indent_str, "  ", key, ": ", value)
    end
    println(io, "  idToColorsMap (Dict{Any,Any}): ", obj.idToColorsMap)
    println(io, "  idToIconsMap (Dict{Any,Any}): ", obj.idToIconsMap)
    println(io, "  system_color (Symbol): ", obj.system_color)
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
    Base.copy(x::EnergySystemDesign)

Make a copy of a EnergySystemDesign struct overloading the copy function that is part of the Base module in Julia.
"""
Base.copy(x::EnergySystemDesign) = EnergySystemDesign(
    x.parent,
    x.system,
    x.system_color,
    copy.(x.idToColorsMap), # create deep copy of array or collection contained within EnergySystemDesign object. 
    copy.(x.idToIconsMap),
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

"""
Create and initialize an instance of the `EnergySystemDesign` struct, representing energy system designs.

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
    idToColorsMap::Dict{Any,Any} = Dict{Any, Any}(),
    idToIconsMap::Dict{Any,Any} = Dict{Any, Any}(),
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

    components = EnergySystemDesign[]
    connections = Tuple{EnergySystemDesign,EnergySystemDesign,Dict}[]
    if haskey(system,:areas)
        parent_arg = Symbol("Toplevel")
    elseif haskey(system,:node)
        parent_arg = Symbol(system[:node])
    else
        parent_arg = Symbol("ParentNotFound")
    end
    xy = Observable((x, y)) #extracting coordinates
    plotObj = []
    if !isempty(system)

        process_children!(
            components,
            system,
            design_dict,
            design_path,
            idToColorsMap,
            idToIconsMap,
            parent_arg,
            xy,
            plotObj,
        )
    end
    xy = Observable((x, y))
    color = :black


    if haskey(system,:areas) && haskey(system,:transmission)
        connection_iterator =enumerate(system[:transmission])
        for (i, connection) in connection_iterator
            connector_design_from = filtersingle(
                            x -> x.system[:node].An == system[:transmission][i].From.An,
                            components,
                        )
            connector_design_to = filtersingle(
                    x -> x.system[:node].An == system[:transmission][i].To.An,
                    components,
                )
            
            if !isnothing(connector_design_from) && !isnothing(connector_design_to)
                hex_colors = [haskey(idToColorsMap, mode.Resource.id) ? idToColorsMap[mode.Resource.id] : missingColor for mode ∈ system[:transmission][i].Modes]
                colors = [parse(Colorant, hex_color) for hex_color ∈ hex_colors]
                connection_sys = Dict(:connection => system[:transmission][i], :colors => colors)
                this_connection = (connector_design_from, connector_design_to,connection_sys)
                push!(connections, this_connection)
            end
        end
    elseif haskey(system,:nodes) && haskey(system,:links)
        connection_iterator =enumerate(system[:links])
        for (i, connection) in connection_iterator
            connector_design_from = filtersingle(
                            x -> x.system[:node] == system[:links][i].from,
                            components,
                        )
            connector_design_to = filtersingle(
                    x -> x.system[:node] == system[:links][i].to,
                    components,
                )
            if !isnothing(connector_design_from) && !isnothing(connector_design_to)
                resourcesOutput = keys(system[:links][i].from.Output)
                resourcesInput = keys(system[:links][i].to.Input)
                hex_colors = [haskey(idToColorsMap,resource.id) ? idToColorsMap[resource.id] : missingColor for resource ∈ resourcesOutput if resource ∈ resourcesInput]
                colors = [parse(Colorant, hex_color) for hex_color ∈ hex_colors]
                connection_sys = Dict(:connection => system[:links][i], :colors => colors)
                this_connection = (connector_design_from, connector_design_to,connection_sys)
                push!(connections, this_connection)
            end
        end
    end

    return EnergySystemDesign(
        parent,
        system,
        idToColorsMap,
        idToIconsMap,
        color,
        components,
        connections,
        xy,
        icon,
        Observable(color),
        Observable(wall),
        file,
        plotObj,
    )
end

"""
    setColors!(idToColorMap::Dict{Any,Any}, products::Vector{S}, productsColors::Vector{T})

Populate idToColorsMap with id from products and colors from productColors (which is a vector of any combinations of String and Symbol).
Color can be represented as a hex (i.e. #a4220b2) or a symbol (i.e. :green), but also a string of the identifier for default colors in the src/colors.toml file
"""
function setColors!(idToColorMap::Dict{Any,Any}, products::Vector{S}, productsColors::Vector{T}) where {S <: Resource, T <: Any}
    colorsFile = joinpath(@__DIR__,"..","src", "colors.toml")
    resourceColors = TOML.parsefile(colorsFile)["Resource"]
    for (i, product) ∈ enumerate(products)
        if productsColors[i] isa Symbol || productsColors[i][1] == '#'
            idToColorMap[product.id] = productsColors[i] 
        else
            try
                idToColorMap[product.id] = resourceColors[productsColors[i]]
            catch
                @warn("Color identifier $(productsColors[i]) is not represented in the colors file $colorsFile. " 
                      *"Using :black instead for \"$(product.id)\".")
                idToColorMap[product.id] = "#000000" 
            end
        end
    end
end

function design_file(system::Dict, path::String)
    if !isdir(path)
        mkdir(path)
    end
    if !haskey(system,:node)
        systemName = "TopLevel"
    else
        systemName = string(system[:node])
    end
    file = joinpath(path, "$(systemName).toml")

    return file
end


"""
    Function to place nodes evenly on a semicircle
"""
function place_nodes_in_semicircle(total_nodes::Int, current_node::Int, r::Real, xₒ::Real, yₒ::Real)
    if total_nodes == 1
        θ = π
    else
        θ = π * (1 - (current_node-1)/(total_nodes-1))
    end
    x = xₒ + r * cos(θ)
    y = yₒ + r * sin(θ)
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

"""
    Function to find the icon associated with a given system's node type.
"""
function find_icon(system::Dict, idToIconsMap::Dict{Any,Any})
    icon = nothing
    if haskey(system,:node) && !isempty(idToIconsMap)
        try
            icon_name = idToIconsMap[system[:node].id]
            icon = joinpath(@__DIR__, "..", "icons", "$icon_name.png")
        catch
            @warn("Could not find $(system[:node].id) in idToIconsMap")
        end
    end
    return icon
end

find_icon(design::EnergySystemDesign,idToIconsMap::Dict{Any,Any}) = find_icon(design.system,idToIconsMap)

"""
    Processes children or components within an energy system design and populates the `children` vector.

    Parameters:
    - `children::Vector{EnergySystemDesign}`: A vector to store child `EnergySystemDesign` instances.
    - `systems::Dict`: The system configuration data represented as a dictionary.
    - `design_dict::Dict`: A dictionary containing design-specific data.
    - `design_path::String`: A file path or identifier related to the design.
    - `parent::Symbol`: A symbol representing the parent of the children.
    - `parent_xy::Observable{Tuple{T,T}}`: An observable tuple holding the coordinates of the parent, where T is a subtype of Real.
    - `kwargs...`: Additional keyword arguments.
"""
function process_children!(
    children::Vector{EnergySystemDesign},
    systems::Dict,
    design_dict::Dict,
    design_path::String,
    idToColorsMap::Dict{Any,Any},
    idToIconsMap::Dict{Any,Any},
    parent::Symbol,
    parent_xy::Observable{Tuple{T,T}},
    plotObj::Vector{Any},
) where T <: Real
    system_iterator = nothing
    if haskey(systems,:areas)
        system_iterator = enumerate(systems[:areas])
    elseif haskey(systems,:nodes)
        system_iterator = enumerate(systems[:nodes])
    end
    parent_x, parent_y = parent_xy[] # we get these from constructor
    if !isempty(systems) && !isnothing(system_iterator)
        current_node = 1
        if haskey(systems,:nodes)
            nodes_count = length(systems[:nodes])
        end
        for (i, system) in system_iterator
            
            system_type = typeof(system)
            key = string(system_type)
            kwargs = if haskey(design_dict, key)
                design_dict[key]
            else
                Dict()
            end
        
            kwargs_pair = Pair[]
        
            
            push!(kwargs_pair, :idToColorsMap => idToColorsMap)
            push!(kwargs_pair, :idToIconsMap => idToIconsMap)
            push!(kwargs_pair, :parent => parent)
        
            #if x and y are missing, add defaults
            if key == "RefArea"
                if hasproperty(system,:Lon) && hasproperty(system,:Lat)
                    push!(kwargs_pair, :x => system.Lon) #assigning long and lat
                    push!(kwargs_pair, :y => system.Lat)
                end
            elseif !haskey(kwargs, "x") && !haskey(kwargs, "y") && haskey(systems,:nodes)
                
                if system isa EnergyModelsBase.Availability || supertype(system_type) == EnergyModelsBase.Availability # second layer of topology, no need of coordinate inside the region, and make a circle
                    x = parent_x
                    y = parent_y
                    nodes_count -= 1
                else
                    x,y = place_nodes_in_semicircle(nodes_count,current_node,1,parent_x,parent_y)
                    current_node += 1
                end
                push!(kwargs_pair, :x => x)
                push!(kwargs_pair, :y => y)
            elseif !haskey(kwargs, "x") && !haskey(kwargs, "y") # x=0, y=0. Fallback condition
                push!(kwargs_pair, :x => i * 3)
                push!(kwargs_pair, :y => i)
            end
    
            # r => wall for icon rotation
            if haskey(kwargs, "r")
                push!(kwargs_pair, :wall => kwargs["r"])
            end

            for (key, value) in kwargs
                push!(kwargs_pair, Symbol(key) => value)
            end
            if haskey(systems,:areas)
                area_An = systems[:areas][i].An
                area_links = filter(item->getfield(item,:from) == area_An || getfield(item,:to) == area_An,systems[:links]) 
                area_nodes = filter(item -> any(link -> link.from == item || link.to == item, area_links),systems[:nodes])
                this_sys = Dict([(:node, system),(:links,area_links),(:nodes,area_nodes)])
            else
                this_sys = Dict([(:node, system)])
            end
            push!(kwargs_pair, :icon => find_icon(this_sys, idToIconsMap))
            push!(kwargs_pair, :plotObj => plotObj)
        
            
            push!(
                children,
                EnergySystemDesign(this_sys, design_path; NamedTuple(kwargs_pair)...),
            )
        end
    end
end


function save_design(design::EnergySystemDesign)

    design_dict = Dict()

    for component in design.components

        x, y = component.xy[]

        pairs = Pair{Symbol,Any}[
            :x => round(x; digits = 5)
            :y => round(y; digits = 5)
        ]

        design_dict[string(component.system[:node])] = Dict(pairs)
    end

    save_design(design_dict, design.file)
end

function save_design(design_dict::Dict, file::String)
    open(file, "w") do io
        TOML.print(io, design_dict) do val
            if val isa Symbol
                return string(val)
            end
        end
    end
end