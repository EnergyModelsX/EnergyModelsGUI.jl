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
- **`xy_parent::Point2f=Point2f(0.0f0, 0.0f0)`** is the parent coordinate of the system.
- **`icon::String=""`** is the optional (path to) icons associated with the system, stored as
  a string.
- **`parent::AbstractGUIObj=NothingDesign()`** is a parent EnergySystemDesign object.
- **`level::Int64=0`** indicates the hierarchical level of the design in the system.

The function reads system configuration data from a TOML file specified by `design_path`
(if it exists), initializes various internal fields, and processes connections and wall values.

It constructs and returns an `EnergySystemDesign` instance.
"""
function EnergySystemDesign(
    system::AbstractSystem;
    design_path::String = "",
    id_to_color_map::Dict = Dict(),
    id_to_icon_map::Dict = Dict(),
    xy_parent::Point2f = Point2f(0.0f0, 0.0f0),
    icon::String = "",
    parent::AbstractGUIObj = NothingDesign(),
    level::Int64 = 0,
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
    if !issubset(get_products(system), keys(id_to_color_map))
        id_to_color_map = set_colors(get_products(system), id_to_color_map)
    end

    # Initialize components and connections
    components = EnergySystemDesign[]
    connections = Connection[]

    # Create an iterator for the current system
    elements = get_children(system)

    visible::Observable{Bool} = Observable(level <= 1)

    design = EnergySystemDesign(
        system,
        id_to_color_map,
        id_to_icon_map,
        components,
        connections,
        parent,
        Observable(xy_parent),
        icon,
        Observable(BLACK),
        Observable(:E),
        file,
        visible,
    )

    # If system contains any components (i.e. !isnothing(elements)) add all components
    # (constructed as an EnergySystemDesign) to `components`
    if !isnothing(elements)
        current_node::Int64 = 1
        nodes_count = length(get_children(system))

        # Loop through all components of `system`
        for element ∈ elements
            # Extract available information from file (stored in the `design_dict` variable)
            key::String = string(element)
            system_info::Dict = haskey(design_dict, key) ? design_dict[key] : Dict()

            # Extract x and y coordinates from file, or from structure or add defaults
            if haskey(system_info, "x") && haskey(system_info, "y")
                xy = Point2f(system_info["x"], system_info["y"])
            elseif isa(system, SystemGeo)
                if hasproperty(element, :lon) && hasproperty(element, :lat)
                    # assigning longitude and latitude
                    xy = Point2f(element.lon, element.lat)
                else
                    @error "Missing lon and/or lat coordinates"
                end
            else
                if element == get_ref_element(system)
                    xy = xy_parent
                else # place nodes in a circle around the parents availability node
                    xy = place_nodes_in_circle(
                        nodes_count, current_node, 1.0f0, xy_parent,
                    )
                    current_node += 1
                end
            end

            # Construct the system dict for the current system
            this_sys = sub_system(system, element)

            # Add child to `components`
            push!(
                design.components,
                EnergySystemDesign(
                    this_sys;
                    design_path,
                    id_to_color_map,
                    id_to_icon_map,
                    xy_parent = xy,
                    icon = find_icon(this_sys, id_to_icon_map),
                    parent = design,
                    level = level + 1,
                ),
            )
        end
    end

    # Add `Transmission`s and `Link`s to `connections` as a `Connection`
    elements = get_connections(system)
    if !isnothing(elements)
        for element ∈ elements
            # Find the EnergySystemDesign corresponding to element.from.node
            from = getfirst(x -> get_element(x) == element.from, components)

            # Find the EnergySystemDesign corresponding to element.to.node
            to = getfirst(x -> get_element(x) == element.to, components)

            # If `EnergySystemDesign`s found, create a new `Connection`
            if !isnothing(from) && !isnothing(to)
                push!(
                    design.connections,
                    Connection(from, to, element, id_to_color_map, Observable(level == 0)),
                )
            end
        end
    end

    return design
end
function EnergySystemDesign(case::Case; kwargs...)
    return EnergySystemDesign(parse_case(case); kwargs...)
end

"""
    sub_system(system::SystemGeo, element::AbstractElement)

Create a sub-system of `system` with the `element` as the reference node.
"""
function sub_system(system::System, element::AbstractElement)
    return System(
        get_time_struct(system),
        get_products(system),
        get_elements_vec(system),
        EMB.Node[],
        Link[],
        element,
        element,
    )
end

"""
    includes_area(case::Case)

Check if the case includes elements from the EnergyModelsGeography package.
"""
function includes_area(case::Case)
    for elements ∈ reverse(get_elements_vec(case))
        for element ∈ elements
            if issubset((:lon, :lat, :node), propertynames(element))
                return true
            end
        end
    end
    return false
end

"""
    parse_case(case::Case)

Parse the case and return a `AbstractSystem` instance.
"""
function parse_case(case::Case)
    return includes_area(case) ? SystemGeo(case) : System(case)
end
