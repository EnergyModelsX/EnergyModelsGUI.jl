"""
    function installed()

Get a list of installed packages (from the depricated Pkg.installed())
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
    place_nodes_in_circle(total_nodes::Int, current_node::Int, r::Real, xₒ::Real, yₒ::Real)

Return coordinate for point number `i` of a total of `n` points evenly distributed around
a circle of radius `r` centered at (xₒ, yₒ) from -π/4 to 5π/4.
"""
function place_nodes_in_circle(n::Int, i::Int, r::Real, xₒ::Real, yₒ::Real)
    θ::Float64 = n == 1 ? π : -π / 4 + 3π / 2 * (1 - (i - 1) / (n - 1))
    x::Float64 = xₒ + r * cos(θ)
    y::Float64 = yₒ + r * sin(θ)
    return x, y
end

"""
    set_colors(id_to_color_map::Dict{Any,Any}, products::Vector{S}, products_colors::Vector{T})

Returns a dictionary that completes the dictionary `id_to_color_map` with default color values
for standard names (like Power, NG, Coal, CO2) collected from `src/colors.yml`.

Color can be represented as a hex (_i.e._, #a4220b2) or a symbol (_i.e_. :green), but also a
string of the identifier for default colors in the `src/colors.yml` file.
"""
function set_colors(products::Vector{S}, id_to_color_map::Dict) where {S<:EMB.Resource}
    complete_id_to_color_map::Dict = Dict()
    default_colors::Dict = get_default_colors()
    for product ∈ products
        if haskey(default_colors, product.id)
            complete_id_to_color_map[product.id] = default_colors[product.id]
        end
    end
    for (key, val) ∈ id_to_color_map
        complete_id_to_color_map[string(key)] = val
    end
    seed::Vector{RGB} = [
        parse(Colorant, hex_color) for hex_color ∈ values(complete_id_to_color_map)
    ]
    products_colors::Vector{RGB} = distinguishable_colors(
        length(products), seed; dropseed=false
    )
    for product ∈ products
        if !haskey(complete_id_to_color_map, product.id)
            complete_id_to_color_map[product.id] = products_colors[length(complete_id_to_color_map) + 1]
        end
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
            pkg -> occursin(r"EnergyModels", pkg), keys(installed_packages)
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
    design_file(system::Dict, path::String)

Construct the path for the .yml file for `system` in the folder `path`.
"""
function design_file(system::Dict, path::String)
    if isempty(path)
        return ""
    end
    if !isdir(path)
        mkpath(path)
    end
    system_name::String = if !haskey(system, :node)
        "top_level"
    else
        string(system[:node])
    end
    file::String = joinpath(path, "$(system_name).yml")

    return file
end

"""
    find_icon(system::Dict, id_to_icon_map::Dict)

Find the icon associated with a given `system`'s node id utilizing the mapping provided
through `id_to_icon_map`.
"""
function find_icon(system::Dict, id_to_icon_map::Dict)
    icon::String = ""
    if haskey(system, :node) && !isempty(id_to_icon_map)
        supertype::DataType = find_type_field(id_to_icon_map, system[:node])
        if haskey(id_to_icon_map, system[:node].id)
            icon = id_to_icon_map[system[:node].id]
        elseif supertype != Nothing
            icon = id_to_icon_map[supertype]
        else
            @warn("Could not find $(system[:node].id) in id_to_icon_map \
                  nor the type $(typeof(system[:node])). Using default setup instead")
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

    for component ∈ design.components
        # Extract x,y-coordinates
        x, y = component.xy[]

        design_dict[string(component.system[:node])] = Dict(
            :x => round(x; digits=5), :y => round(y; digits=5)
        )

        # Also save the coordinates from sub designs
        if !isempty(component.components)
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
    return YAML.write_file(file, design_dict)
end

"""
    get_linked_nodes!(node::EMB.Node,
        system::Dict{Symbol, Any},
        links::Vector{EMB.Link},
        nodes::Vector{EMB.Node},
        indices::Vector{Int})

Recursively find all nodes connected (directly or indirectly) to `node` in a system `system`
and store the found links in `links` and nodes in `nodes`.

Here, `indices` contains the indices where the next link and node is to be stored,
respectively.
"""
function get_linked_nodes!(
    node::EMB.Node,
    system::Dict{Symbol,Any},
    links::Vector{EMB.Link},
    nodes::Vector{EMB.Node},
    indices::Vector{Int},
)
    for link ∈ system[:links]
        if node ∈ [link.from, link.to] &&
            (indices[1] == 1 || !(link ∈ links[1:(indices[1] - 1)]))
            links[indices[1]] = link
            indices[1] += 1

            new_node_added::Bool = false
            if node == link.from && !(link.to ∈ nodes[1:(indices[2] - 1)])
                nodes[indices[2]] = link.to
                new_node_added = true
            elseif node == link.to && !(link.from ∈ nodes[1:(indices[2] - 1)])
                nodes[indices[2]] = link.from
                new_node_added = true
            end

            # Recursively add other nodes
            if new_node_added
                indices[2] += 1
                get_linked_nodes!(nodes[indices[2] - 1], system, links, nodes, indices)
            end
        end
    end
end

"""
    get_resource_colors(resources::Vector{EMB.Resource}, id_to_color_map::Dict{Any,Any})

Get the colors linked the the resources in `resources` based on the mapping `id_to_color_map`.
"""
function get_resource_colors(
    resources::Vector{T}, id_to_color_map::Dict{Any,Any}
) where {T<:EMB.Resource}
    hexColors::Vector{Any} = [id_to_color_map[resource.id] for resource ∈ resources]
    return [parse(Colorant, hex_color) for hex_color ∈ hexColors]
end

"""
    get_resource_colors(l::Vector{EMB.Link}, id_to_color_map::Dict{Any,Any})

Get the colors linked to the resources in the link `l` based on the mapping `id_to_color_map`.
"""
function get_resource_colors(l::EMB.Link, id_to_color_map::Dict{Any,Any})
    resources::Vector{EMB.Resource} = EMB.link_res(l)
    return get_resource_colors(resources, id_to_color_map)
end

"""
    get_resource_colors(l::Vector{EMG.Transmission}, id_to_color_map::Dict{Any,Any})

Get the colors linked to the resources in the transmission `l` (from modes(Transmission))
based on the mapping `id_to_color_map`
"""
function get_resource_colors(l::EMG.Transmission, id_to_color_map::Dict{Any,Any})
    resources::Vector{EMB.Resource} = [map_trans_resource(mode) for mode ∈ l.modes]
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
