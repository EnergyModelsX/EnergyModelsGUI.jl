"""
    function installed()

Get a list of installed packages (from the depricated Pkg.installed()).
"""
function installed()
    deps = Pkg.dependencies()
    installs = Dict{String,VersionNumber}()
    for (uuid, dep) ∈ deps
        dep.is_direct_dep || continue
        dep.version === nothing && continue
        installs[dep.name] = dep.version::VersionNumber
    end
    return installs
end

"""
    function loaded()

Get a list of loaded packages.
"""
loaded() = filter((x) -> typeof(eval(x)) <: Module, names(Main, imported = true))

"""
    place_nodes_in_circle(total_nodes::Int64, current_node::Int64, r::Float32, xₒ::Float32, yₒ::Float32)

Return coordinate for point number `i` of a total of `n` points evenly distributed around
a circle of radius `r` centered at (xₒ, yₒ) from -π/4 to 5π/4.
"""
function place_nodes_in_circle(n::Int64, i::Int64, r::Float32, xₒ::Float32, yₒ::Float32)
    θ::Float32 = n == 1 ? π : -π / 4 + 3π / 2 * (1 - (i - 1) / (n - 1))
    x::Float32 = xₒ + r * cos(θ)
    y::Float32 = yₒ + r * sin(θ)
    return x, y
end

"""
    set_colors(products::Vector{<:Resource}, id_to_color_map::Dict)

Returns a dictionary that completes the dictionary `id_to_color_map` with default color values
for standard names (like Power, NG, Coal, CO2) collected from `src/colors.yml`.

Color can be represented as a hex (*i.e.*, #a4220b2) or a symbol (*i.e.*, :green), but also a
string of the identifier for default colors in the `src/colors.yml` file.
"""
function set_colors(products::Vector{<:Resource}, id_to_color_map::Dict)
    complete_id_to_color_map::Dict = Dict()

    # Get the default colors
    default_colors::Dict = get_default_colors()

    # Add default colors to the complete_id_to_color_map
    for product ∈ products
        if haskey(default_colors, product.id)
            complete_id_to_color_map[product.id] = default_colors[product.id]
        end
    end

    # Add the colors from the id_to_color_map (also overwrites default colors)
    for (key, val) ∈ id_to_color_map
        complete_id_to_color_map[string(key)] = val
    end

    # Add missing colors and make these most distinguishable to the existing ones
    # Find the resources that are missing colors
    missing_product_colors::Vector{Resource} = filter(
        product -> !haskey(complete_id_to_color_map, product.id), products,
    )

    # Create a seed based on the existing colors
    seed::Vector{RGB} = [
        parse(Colorant, hex_color) for hex_color ∈ values(complete_id_to_color_map)
    ]

    # Add non-desired colors to the seed
    foul_colors = [
        "#FFFF00", # Yellow
        "#FF00FF", # Magenta
        "#00FFFF", # Cyan
        "#00FF00", # Green
        "#000000", # Black
        "#FFFFFF", # White
    ]
    for color ∈ values(foul_colors)
        push!(seed, parse(Colorant, color))
    end

    # Create new colors for the missing resources
    products_colors::Vector{RGB} = distinguishable_colors(
        length(missing_product_colors), seed; dropseed = true,
    )

    # Set the new colors for the missing resources
    for (product, color) ∈ zip(missing_product_colors, products_colors)
        complete_id_to_color_map[product.id] = color
    end

    return complete_id_to_color_map
end

"""
    get_default_colors()

Get the default colors in the EnergyModelsGUI repository at `src/colors.yml`.
"""
function get_default_colors()
    return YAML.load_file(joinpath(@__DIR__, "..", "colors.yml"))
end

"""
    set_icons(id_to_icon_map::Dict)

Return a dictionary `id_to_icon_map` with id from nodes and icon paths based on provided
paths (or name of .png icon file which will be found in the icons folder of any of the
EMX packages).

The icon images are assumed to be in .png format, and the strings should not contain this
file ending.
"""
function set_icons(id_to_icon_map::Dict)
    if isempty(id_to_icon_map)
        return id_to_icon_map
    end
    for (key, val) ∈ id_to_icon_map
        id_to_icon_map[key] = find_icon_path(val)
    end
    return id_to_icon_map
end

"""
    function find_icon_path(icon::String)

Search for path to icon based on icon name `icon`.
"""

function find_icon_path(icon::String)
    icon_path = "" # in case not found
    if isfile(icon)
        icon_path = icon * ".png"
    elseif isfile(joinpath(@__DIR__, "..", "..", "icons", icon * ".png"))
        icon_path = joinpath(@__DIR__, "..", "..", "icons", icon * ".png")
    else
        # Get a dictionary of installed packages
        installed_packages = installed()

        # Filter packages with names matching the pattern "EnergyModels*"
        emx_packages = filter(
            pkg -> occursin(r"EnergyModels", pkg), keys(installed_packages),
        )

        # Search through EMX packages if icons are available there
        for package ∈ emx_packages
            package_path::Union{String,Nothing} = Base.find_package(package)
            if !isnothing(package_path)
                icons_file::String =
                    joinpath(package_path, "ext", "EMGUIExt", "icons", icon) * ".png"
                if isfile(icons_file)
                    icon_path = icons_file
                    break
                end
            end
        end
    end
    return icon_path
end

"""
    design_file(system::AbstractSystem, path::String)

Construct the path for the .yml file for `system` in the folder `path`.
"""
function design_file(system::AbstractSystem, path::String)
    if isempty(path)
        return ""
    end
    return joinpath(path, "$(get_parent(system)).yml")
end

"""
    find_icon(system::AbstractSystem, id_to_icon_map::Dict)

Find the icon associated with a given `system`'s node id utilizing the mapping provided
through `id_to_icon_map`.
"""
function find_icon(system::AbstractSystem, id_to_icon_map::Dict)
    icon::String = ""
    if !isempty(id_to_icon_map)
        supertype::DataType = find_type_field(id_to_icon_map, get_parent(system))
        if haskey(id_to_icon_map, get_parent(system).id)
            icon = id_to_icon_map[get_parent(system).id]
        elseif supertype != Nothing
            icon = id_to_icon_map[supertype]
        else
            @warn("Could not find $(get_parent(system).id) in id_to_icon_map \
                  nor the type $(typeof(get_parent(system))). Using default setup instead")
        end
    end
    return icon
end

"""
    save_design(design::EnergySystemDesign)

Save the x,y-coordinates of EnergySystemDesign `design` to a .yml file specifield in the
field `file` of `design`.
"""
function save_design(design::EnergySystemDesign)
    if isempty(design.file)
        @error "Path not specified for saving; use GUI(case; design_path)"
        return nothing
    end

    design_dict::Dict = Dict()

    for component ∈ get_components(design)
        # Extract x,y-coordinates
        x, y = component.xy[]

        design_dict[string(get_parent(get_system(component)))] = Dict(
            :x => round(x; digits = 5), :y => round(y; digits = 5),
        )

        # Also save the coordinates from sub designs
        if !isempty(get_components(component))
            save_design(component)
        end
    end

    @info "Saving design coordinates to file $(design.file)"
    return save_design(design_dict, design.file)
end

"""
    save_design(design::EnergySystemDesign, file::String)

Save the x,y-coordinates of `design_dict` to a .yml file at location and filename given by
`file`.
"""
function save_design(design_dict::Dict, file::String)
    design_dir = dirname(file)
    if !isdir(design_dir)
        mkpath(design_dir)
    end
    return YAML.write_file(file, design_dict)
end

"""
    get_linked_nodes!(
        node::EMB.Node,
        links::Vector{Link},
        area_links::Vector{Link},
        area_nodes::Vector{EMB.Node},
        indices::Vector{Int},
    )

Recursively find all nodes connected (directly or indirectly) to `node` in a system of `links`
and store the found links in `area_links` and nodes in `area_nodes`.

Here, `indices` contains the indices where the next link and node is to be stored,
respectively.
"""
function get_linked_nodes!(
    node::EMB.Node,
    links::Vector{Link},
    area_links::Vector{Link},
    area_nodes::Vector{EMB.Node},
    indices::Vector{Int},
)
    for link ∈ links
        if node ∈ [link.from, link.to] &&
           (indices[1] == 1 || !(link ∈ area_links[1:(indices[1]-1)]))
            area_links[indices[1]] = link
            indices[1] += 1

            new_node_added::Bool = false
            if node == link.from && !(link.to ∈ area_nodes[1:(indices[2]-1)])
                area_nodes[indices[2]] = link.to
                new_node_added = true
            elseif node == link.to && !(link.from ∈ area_nodes[1:(indices[2]-1)])
                area_nodes[indices[2]] = link.from
                new_node_added = true
            end

            # Recursively add other nodes
            if new_node_added
                indices[2] += 1
                get_linked_nodes!(
                    area_nodes[indices[2]-1],
                    links,
                    area_links,
                    area_nodes,
                    indices,
                )
            end
        end
    end
end

"""
    get_resource_colors(resources::Vector{Resource}, id_to_color_map::Dict{Any,Any})

Get the colors linked the the resources in `resources` based on the mapping `id_to_color_map`.
"""
function get_resource_colors(resources::Vector{<:Resource}, id_to_color_map::Dict{Any,Any})
    hexColors::Vector{Any} = [id_to_color_map[resource.id] for resource ∈ resources]
    return [parse(Colorant, hex_color) for hex_color ∈ hexColors]
end

"""
    get_resource_colors(l::Vector{Link}, id_to_color_map::Dict{Any,Any})

Get the colors linked to the resources in the link `l` based on the mapping `id_to_color_map`.
"""
function get_resource_colors(l::Link, id_to_color_map::Dict{Any,Any})
    resources::Vector{Resource} = EMB.link_res(l)
    return get_resource_colors(resources, id_to_color_map)
end

"""
    get_resource_colors(::Vector{Any}, ::Dict{Any,Any})

Return empty RGB vector for empty input.
"""
function get_resource_colors(::Vector{Any}, ::Dict{Any,Any})
    return Vector{RGB}(undef, 0)
end

"""
    getfirst(f::Function, a::Vector)

Return the first element of Vector `a` satisfying the requirement of Function `f`.
"""
function getfirst(f::Function, a::Vector)
    index = findfirst(f, a)
    return isnothing(index) ? nothing : a[index]
end
