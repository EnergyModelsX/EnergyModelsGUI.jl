"""
Create and initialize an instance of the `EnergySystemDesign` struct, representing energy
system designs.

# Arguments:

- **`system::Dict`** is a dictionary containing system-related data stored as key-value pairs.

# Keyword arguments:

- **`design_path::String=""`** is a file path or identifier related to the design.
- **`id_to_color_map::Dict`** is a dictionary of resources and their assigned colors.
- **`id_to_icon_map::Dict`** is a dictionary of nodes and their assigned icons.
- **`x::Real=0.0`** is the initial x-coordinate of the system.
- **`y::Real=0.0`** is the initial y-coordinate of the system.
- **`icon::String=""`** is the optional (path to) icons associated with the system, stored as
  a string.
- **`parent::Union{Symbol, Nothing}=nothing`** is a parent reference or indicator.

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
    parent::Union{Symbol,Nothing}=nothing,
)
    # Create the path to the file where existing design is stored (if any)
    file::String = design_file(system, design_path)

    # Extract stored design from file
    design_dict::Dict = if isfile(file)
        YAML.load_file(file)
    else
        Dict()
    end

    # Complete the `id_to_color_map` if some products are lacking (this is done by choosing
    # colors for the lacking `Resource`s that are most distinct to the existing set of colors)
    if haskey(system, :products) && !(length(system[:products]) == length(id_to_color_map))
        id_to_color_map = set_colors(system[:products], id_to_color_map)
    end

    # Initialize components and connections
    components::Vector{EnergySystemDesign} = EnergySystemDesign[]
    connections::Vector{Connection} = Connection[]

    # Create the name for the parent system
    parent_arg::Symbol = if haskey(system, :areas)
        :top_level
    elseif haskey(system, :node)
        Symbol(system[:node])
    else
        :parent_not_found
    end

    # Create an observable for the coordinate xy that can be inherited as the coordinate
    # parent_xy
    xy::Observable{Tuple{Real,Real}} = Observable((x, y))
    if !isempty(system)
        process_children!(
            components,
            system,
            design_dict,
            design_path,
            id_to_color_map,
            id_to_icon_map,
            parent_arg,
            xy[],
        )
    end

    # Add  `Transmission`s and `Link`s to `connections` as a `Connection`
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
        Observable(:black),
        Observable(:E),
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
- **`id_to_color_map::Dict`** is a dictionary of resources and their assigned colors.
- **`id_to_icon_map::Dict`** is a dictionary of nodes and their assigned icons.
- **`parent::Symbol`** is a symbol representing the parent of the children.
- **`parent_xy::Tuple{T,T}`** is a tuple holding the coordinates of the parent,
  where `T` is a subtype of Real.
"""
function process_children!(
    children::Vector{EnergySystemDesign},
    systems::Dict,
    design_dict::Dict,
    design_path::String,
    id_to_color_map::Dict,
    id_to_icon_map::Dict,
    parent::Symbol,
    parent_xy::Tuple{T,T},
) where {T<:Real}
    # Create an iterator for the current systems
    systems_iterator::Union{
        Iterators.Enumerate{Vector{EMB.Node}},Iterators.Enumerate{Vector{Area}},Nothing
    } = if haskey(systems, :areas)
        enumerate(systems[:areas])
    elseif haskey(systems, :nodes)
        enumerate(systems[:nodes])
    end
    parent_x, parent_y = parent_xy # extract parent coordinates

    # If system contains any children (i.e. !isempty(system)) add all childrens (constructed
    # as an EnergySystemDesign) to `children`
    if !isempty(systems) && !isnothing(systems_iterator)
        current_node::Int64 = 1
        if haskey(systems, :nodes)
            nodes_count::Int64 = length(systems[:nodes])
        end
        parent_node_found::Bool = false

        # Loop through all childrens of `systems`
        for (i, system) ∈ systems_iterator
            # Extract available information from file (stored in the `design_dict` variable)
            key::String = string(system)
            system_info::Dict = if haskey(design_dict, key)
                design_dict[key]
            else
                Dict()
            end

            # Extract x and y coordinates from file, or from structure or add defaults
            if haskey(system_info, "x") && haskey(system_info, "y")
                x = system_info["x"]
                y = system_info["y"]
            elseif isa(system, Area)
                if hasproperty(system, :lon) && hasproperty(system, :lat)
                    # assigning longitude and latitude
                    x = system.lon
                    y = system.lat
                else
                    @error "Missing lon and/or lat coordinates"
                end
            elseif !haskey(system_info, "x") &&
                !haskey(system_info, "y") &&
                haskey(systems, :nodes)
                if !parent_node_found && (
                    (haskey(systems, :node) && system == systems[:node].node) ||
                    (parent == :parent_not_found && typeof(system) <: Availability)
                )  # use the parent coordinate for the RefArea node or the first Availability node found
                    x = parent_x
                    y = parent_y
                    nodes_count -= 1
                    parent_node_found = true
                else # place nodes in a circle around the parents availability node
                    x, y = place_nodes_in_circle(
                        nodes_count, current_node, 1, parent_x, parent_y
                    )
                    current_node += 1
                end
            end

            # Construct the system dict for the current system
            this_sys::Dict{Symbol,Any} = Dict()
            if haskey(systems, :areas)
                area_an::EMB.Node = availability_node(systems[:areas][i])

                # Allocate redundantly large vector (for efficiency) to collect all links and nodes
                area_links::Vector{Link} = Vector{Link}(undef, length(systems[:links]))
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

            # Add child to `children`
            push!(
                children,
                EnergySystemDesign(
                    this_sys;
                    design_path,
                    id_to_color_map,
                    id_to_icon_map,
                    x,
                    y,
                    icon=find_icon(this_sys, id_to_icon_map),
                    parent=parent,
                ),
            )
        end
    end
end
