"""
Create and initialize an instance of the `EnergySystemDesign` struct, representing energy
system designs.

# Arguments:

- **`system::Dict`** is a dictionary containing system-related data stored as key-value pairs.

# Keyword arguments:

- **`design_path::String=""`** is a file path or identifier related to the design.
- **`x::Real=0.0`** is the initial x-coordinate of the system.
- **`y::Real=0.0`** is the initial y-coordinate of the system.
- **`icon::String=""`** is the optional (path to) icons associated with the system, stored as
  a string.
- **`wall::Symbol=:E`** is an initial wall value.
- **`parent::Union{Symbol, Nothing}=nothing`** is a parent reference or indicator.
- **`kwargs...`** are additional keyword arguments that can be provided.

The function reads system configuration data from a TOML file specified by `design_path`
(if it exists), initializes various internal fields, and processes connections and wall values.

It constructs and returns an `EnergySystemDesign` instance.
"""
function EnergySystemDesign(
    system::Dict;
    design_path::String="",
    id_to_color_map::Dict=Dict(),
    id_to_icon_map::Dict=Dict(),
    x::Real=0.0,
    y::Real=0.0,
    icon::String="",
    wall::Symbol=:E,
    parent::Union{Symbol,Nothing}=nothing,
    kwargs...,
)
    file::String = design_file(system, design_path)
    design_dict::Dict = if isfile(file)
        YAML.load_file(file)
    else
        Dict()
    end
    if haskey(system, :products) && !(length(system[:products]) == length(id_to_color_map))
        id_to_color_map = set_colors(system[:products], id_to_color_map)
    end

    # Initialize components and connections
    components::Vector{EnergySystemDesign} = EnergySystemDesign[]
    connections::Vector{Connection} = Connection[]

    parent_arg::Symbol = if haskey(system, :areas)
        :top_level
    elseif haskey(system, :node)
        Symbol(system[:node])
    else
        :parent_not_found
    end
    xy::Observable{Tuple{Real,Real}} = Observable((x, y)) # extracting coordinates
    if !isempty(system)
        process_children!(
            components,
            system,
            design_dict,
            design_path,
            id_to_color_map,
            id_to_icon_map,
            parent_arg,
            xy,
        )
    end
    color::Symbol = :black

    if haskey(system, :areas) && haskey(system, :transmission)
        for transmission ∈ system[:transmission]
            from = getfirst(x -> x.system[:node].node == transmission.from.node, components)
            to = getfirst(x -> x.system[:node].node == transmission.to.node, components)

            if !isnothing(from) && !isnothing(to)
                push!(connections, Connection(from, to, transmission, id_to_color_map))
            end
        end
    elseif haskey(system, :nodes) && haskey(system, :links)
        for link ∈ system[:links]
            from = getfirst(x -> x.system[:node] == link.from, components)
            to = getfirst(x -> x.system[:node] == link.to, components)
            if !isnothing(from) && !isnothing(to)
                push!(connections, Connection(from, to, link, id_to_color_map))
            end
        end
    end

    return EnergySystemDesign(
        parent,
        system,
        id_to_color_map,
        id_to_icon_map,
        components,
        connections,
        xy,
        icon,
        Observable(color),
        Observable(wall),
        file,
    )
end

"""
    process_children!(...)

Processes children or components within an energy system design and populates the `children` vector.

# Arguments:

- **`children::Vector{EnergySystemDesign}`** is a vector to store child `EnergySystemDesign`
  instances.
- **`systems::Dict`** is the system configuration data represented as a dictionary.
- **`design_dict::Dict`** is a dictionary containing design-specific data.
- **`design_path::String`** is a file path or identifier related to the design.
- **`parent::Symbol`** is a symbol representing the parent of the children.
- **`parent_xy::Observable{Tuple{T,T}}`** is an observable tuple holding the coordinates of
  the parent, where `T` is a subtype of Real.
- **`kwargs...`**: Additional keyword arguments.
"""
function process_children!(
    children::Vector{EnergySystemDesign},
    systems::Dict,
    design_dict::Dict,
    design_path::String,
    id_to_color_map::Dict,
    id_to_icon_map::Dict,
    parent::Symbol,
    parent_xy::Observable{Tuple{T,T}},
) where {T<:Real}
    system_iterator::Union{
        Iterators.Enumerate{Vector{EMB.Node}},Iterators.Enumerate{Vector{EMG.Area}},Nothing
    } = if haskey(systems, :areas)
        enumerate(systems[:areas])
    elseif haskey(systems, :nodes)
        enumerate(systems[:nodes])
    end
    parent_x, parent_y = parent_xy[] # we get these from constructor
    if !isempty(systems) && !isnothing(system_iterator)
        current_node::Int64 = 1
        if haskey(systems, :nodes)
            nodes_count::Int64 = length(systems[:nodes])
        end
        parent_node_found::Bool = false
        for (i, system) ∈ system_iterator
            key::String = string(system)
            kwargs::Dict = if haskey(design_dict, key)
                design_dict[key]
            else
                Dict()
            end

            kwargs_pair::Vector{Pair} = Pair[]

            push!(kwargs_pair, :id_to_color_map => id_to_color_map)
            push!(kwargs_pair, :id_to_icon_map => id_to_icon_map)
            push!(kwargs_pair, :parent => parent)

            # if x and y are missing, add defaults
            if isa(system, EMG.Area)
                if hasproperty(system, :lon) && hasproperty(system, :lat)
                    push!(kwargs_pair, :x => system.lon) # assigning longitude and latitude
                    push!(kwargs_pair, :y => system.lat)
                end
            elseif !haskey(kwargs, "x") && !haskey(kwargs, "y") && haskey(systems, :nodes)
                if !parent_node_found && (
                    (haskey(systems, :node) && system == systems[:node].node) ||
                    (parent == :parent_not_found && typeof(system) <: EMB.Availability)
                )  # use the parent coordinate for the RefArea node or an availability node
                    x::Real = parent_x
                    y::Real = parent_y
                    nodes_count -= 1
                    parent_node_found = true
                else
                    x, y = place_nodes_in_circle(
                        nodes_count, current_node, 1, parent_x, parent_y
                    )
                    current_node += 1
                end
                push!(kwargs_pair, :x => x)
                push!(kwargs_pair, :y => y)
            end

            # r => wall for icon rotation
            if haskey(kwargs, "r")
                push!(kwargs_pair, :wall => kwargs["r"])
            end

            for (key, value) ∈ kwargs
                push!(kwargs_pair, Symbol(key) => value)
            end
            this_sys::Dict{Symbol,Any} = Dict()
            if haskey(systems, :areas)
                area_an::EMB.Node = availability_node(systems[:areas][i])

                # Allocate redundantly large vector (for efficiency) to collect all links and nodes
                area_links::Vector{EMB.Link} = Vector{EMB.Link}(
                    undef, length(systems[:links])
                )
                area_nodes::Vector{EMB.Node} = Vector{EMB.Node}(
                    undef, length(systems[:nodes])
                )

                area_nodes[1] = area_an

                # Create counting indices for area_links and area_nodes respectively
                indices::Vector{Int} = [1, 2]

                get_linked_nodes!(area_an, systems, area_links, area_nodes, indices)
                resize!(area_links, indices[1] - 1)
                resize!(area_nodes, indices[2] - 1)
                this_sys = Dict(:node => system, :links => area_links, :nodes => area_nodes)
            else
                this_sys = Dict(:node => system)
            end
            push!(kwargs_pair, :icon => find_icon(this_sys, id_to_icon_map))

            push!(
                children,
                EnergySystemDesign(this_sys; design_path, NamedTuple(kwargs_pair)...),
            )
        end
    end
end
