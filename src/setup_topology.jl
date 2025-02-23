"""
    EnergySystemDesign(system::AbstractSystem)

Create and initialize an instance of the `EnergySystemDesign` struct, representing energy
system designs. If the argument is a `Case` instance, the function converts the case to a
dictionary, and initializes the `EnergySystemDesign`. If the argument is a `AbstractSystem`,
the function initializes the `EnergySystemDesign`.

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
    system::AbstractSystem;
    design_path::String = "",
    id_to_color_map::Dict = Dict(),
    id_to_icon_map::Dict = Dict(),
    x::Real = 0.0,
    y::Real = 0.0,
    icon::String = "",
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
    if !(length(get_products(system)) == length(id_to_color_map))
        id_to_color_map = set_colors(get_products(system), id_to_color_map)
    end

    # Initialize components and connections
    components::Vector{EnergySystemDesign} = EnergySystemDesign[]
    connections::Vector{Connection} = Connection[]

    # Create an observable for the coordinate xy that can be inherited as the coordinate
    # parent_xy
    xy::Observable{Tuple{Real,Real}} = Observable((x, y))

    # Create an iterator for the current system
    elements = get_children(system)
    parent_x, parent_y = xy[] # extract parent coordinates

    # If system contains any components (i.e. !isnothing(elements)) add all components
    # (constructed as an EnergySystemDesign) to `components`
    if !isnothing(elements)
        current_node::Int64 = 1
        nodes_count::Int64 = length(get_children(system))

        # Loop through all components of `system`
        for element ∈ elements
            # Extract available information from file (stored in the `design_dict` variable)
            key::String = string(element)
            system_info::Dict = haskey(design_dict, key) ? design_dict[key] : Dict()

            # Extract x and y coordinates from file, or from structure or add defaults
            if haskey(system_info, "x") && haskey(system_info, "y")
                x = system_info["x"]
                y = system_info["y"]
            elseif isa(element, Area)
                if hasproperty(element, :lon) && hasproperty(element, :lat)
                    # assigning longitude and latitude
                    x = element.lon
                    y = element.lat
                else
                    @error "Missing lon and/or lat coordinates"
                end
            else
                if element == get_ref_element(system)
                    x = parent_x
                    y = parent_y
                    nodes_count -= 1
                else # place nodes in a circle around the parents availability node
                    x, y = place_nodes_in_circle(
                        nodes_count, current_node, 1, parent_x, parent_y,
                    )
                    current_node += 1
                end
            end

            # Construct the system dict for the current system
            this_sys = if isa(system, SystemGeo)
                area_an::EMB.Node = availability_node(element)

                # Allocate redundantly large vector (for efficiency) to collect all links and nodes
                links::Vector{Link} = get_links(system)
                area_links::Vector{Link} = Vector{Link}(undef, length(links))
                area_nodes::Vector{EMB.Node} = Vector{EMB.Node}(
                    undef, length(get_nodes(system)),
                )

                area_nodes[1] = area_an

                # Create counting indices for area_links and area_nodes respectively
                indices::Vector{Int} = [1, 2]

                get_linked_nodes!(area_an, links, area_links, area_nodes, indices)
                resize!(area_links, indices[1] - 1)
                resize!(area_nodes, indices[2] - 1)
                System(
                    get_time_struct(system),
                    get_products(system),
                    get_elements_vec(system),
                    area_nodes,
                    area_links,
                    element,
                    area_an,
                )
            else
                System(
                    get_time_struct(system),
                    get_products(system),
                    get_elements_vec(system),
                    EMB.Node[],
                    Link[],
                    element,
                    element,
                )
            end

            # Add child to `components`
            push!(
                components,
                EnergySystemDesign(
                    this_sys;
                    design_path,
                    id_to_color_map,
                    id_to_icon_map,
                    x,
                    y,
                    icon = find_icon(this_sys, id_to_icon_map),
                ),
            )
        end
    end

    # Add  `Transmission`s and `Link`s to `connections` as a `Connection`
    elements = get_transmissions(system)
    if !isnothing(elements)
        for element ∈ elements
            # Find the EnergySystemDesign corresponding to element.from.node
            from = getfirst(x -> get_element(x) == element.from, components)

            # Find the EnergySystemDesign corresponding to element.to.node
            to = getfirst(x -> get_element(x) == element.to, components)

            # If `EnergySystemDesign`s found, create a new `Connection`
            if !isnothing(from) && !isnothing(to)
                push!(connections, Connection(from, to, element, id_to_color_map))
            end
        end
    end

    return EnergySystemDesign(
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
function EnergySystemDesign(case::Case; kwargs...)
    return EnergySystemDesign(parse_case(case); kwargs...)
end

"""
    includes_area(case::Case)

Check if the case includes elements from the EnergyModelsGeography package.
"""
function includes_area(case::Case)
    return if @isdefined(Area)
        area = filter(el -> isa(el, Vector{<:Area}), get_elements_vec(case))
        !isempty(area)
    else
        false
    end
end

"""
    parse_case(case::Case)

Parse the case and return a `AbstractSystem` instance.
"""
function parse_case(case::Case)
    return includes_area(case) ? SystemGeo(case) : System(case)
end
