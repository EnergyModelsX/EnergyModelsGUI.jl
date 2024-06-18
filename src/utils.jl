# Define a type for sparse variables to simplify code
const SparseVars = Union{JuMP.Containers.SparseAxisArray,SparseVariables.IndexedVarArray}

# Create a type for all Clickable objects in the gui.axes[:topo]
const Plotable = Union{
    Nothing,EMB.Node,EMB.Link,EMG.Area,EMG.Transmission,EMG.TransmissionMode
} # Types that can trigger an update in the gui.axes[:results] plot
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
    get_representative_period_indices(T::TS.TimeStructure, sp::Int64)

Return indices in the time structure `T` of the representative periods for strategic
period `sp`.
"""
function get_representative_period_indices(T::TS.TimeStructure, sp::Int64)
    return if eltype(T.operational) <: TS.RepresentativePeriods
        (1:(T.operational[sp].len))
    else
        [1]
    end
end

"""
    get_scenario_indices(T::TS.TimeStructure, sp::Int64, rp::Int64)

Return indices of the scenarios in the time structure `T` for strategic period number `sp`
and representative period `rp`
"""
function get_scenario_indices(T::TS.TimeStructure, sp::Int64, rp::Int64)
    if eltype(T.operational) <: TS.RepresentativePeriods
        if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
            return (1:(T.operational[sp].rep_periods[rp].len))
        else
            return (1:(T.operational[sp].len))
        end
    elseif eltype(T.operational) <: TS.RepresentativePeriods
        return (1:(T.operational[sp].len))
    else
        return [1]
    end
end

"""
    square_intersection(
        c::Vector{Tc}, x::Vector{Tx},
        θ::Tθ, Δ::TΔ
    ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}

Calculate the intersection point between a line starting at `x` and direction described by
`θ` and a square with half side lengths `Δ` centered at center `c`.
"""
function square_intersection(
    c::Vector{Tc}, x::Vector{Tx}, θ::Tθ, Δ::TΔ
) where {Tc<:Real,Tx<:Real,Tθ<:Real,TΔ<:Real}
    # Ensure that -π ≤ θ ≤ π
    θ = θ > π ? θ - 2π : θ
    θ = θ < -π ? θ + 2π : θ

    # Calculate angles at the corers of the square with respect to the point x
    θ_se::Tθ = atan(c[2] - x[2] - Δ, c[1] - x[1] + Δ)
    θ_ne::Tθ = atan(c[2] - x[2] + Δ, c[1] - x[1] + Δ)
    θ_nw::Tθ = atan(c[2] - x[2] + Δ, c[1] - x[1] - Δ)
    θ_sw::Tθ = atan(c[2] - x[2] - Δ, c[1] - x[1] - Δ)

    # Return the intersection point
    if θ_se <= θ && θ < θ_ne # Facing walls are (:E, :W)
        return [c[1] + Δ, x[2] + (c[1] + Δ - x[1]) * tan(θ)]
    elseif θ_ne <= θ && θ < θ_nw # Facing walls are (:N, :S)
        return [x[1] + (c[2] + Δ - x[2]) / tan(θ), c[2] + Δ]
    elseif θ_sw <= θ && θ < θ_se # Facing walls are (:S, :N)
        return [x[1] + (c[2] - Δ - x[2]) / tan(θ), c[2] - Δ]
    else # Facing walls are (:W, :E)
        return [c[1] - Δ, x[2] + (c[1] - Δ - x[1]) * tan(θ)]
    end
end

"""
    square_intersection(
        c::Tuple{Tc, Tc},
        θ::Tθ, Δ::TΔ
    ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}

Calculate the intersection point between a line starting at `c` and direction described
by `θ` and a square with half side lengths `Δ` centered at center `c`.
"""
function square_intersection(
    c::Tuple{Tc,Tc}, θ::Tθ, Δ::TΔ
) where {Tc<:Real,Tθ<:Real,TΔ<:Real}
    return square_intersection(collect(c), collect(c), θ, Δ)
end

"""
    norm(x::Vector{T}) where T<:Real

Compute the l2-norm of a vector.
"""
function norm(x::Vector{T}) where {T<:Real}
    return sqrt(sum(x .^ 2))
end

"""
    find_min_max_coordinates(
        design::EnergySystemDesign,
        min_x::Number,
        max_x::Number,
        min_y::Number,
        max_y::Number
    )

Find the minimum and maximum coordinates of the components of `EnergySystemDesign` design
given the minimum and maximum coordinates `min_x`, `min_y`, `max_x`, and `max_y`.
"""
function find_min_max_coordinates(
    design::EnergySystemDesign, min_x::Number, max_x::Number, min_y::Number, max_y::Number
)
    if design.xy !== nothing && haskey(design.system, :node)
        x, y = design.xy[]
        min_x = min(min_x, x)
        max_x = max(max_x, x)
        min_y = min(min_y, y)
        max_y = max(max_y, y)
    end

    for child ∈ design.components
        min_x, max_x, min_y, max_y = find_min_max_coordinates(
            child, min_x, max_x, min_y, max_y
        )
    end

    return min_x, max_x, min_y, max_y
end

"""
    find_min_max_coordinates(design::EnergySystemDesign)

Find the minimum and maximum coordinates of the components of EnergySystemDesign `design`.
"""
function find_min_max_coordinates(design::EnergySystemDesign)
    return find_min_max_coordinates(design, Inf, -Inf, Inf, -Inf)
end

"""
    angle(node_1::EnergySystemDesign, node_2::EnergySystemDesign)

Based on the location of `node_1` and `node_2`, return the angle between the x-axis and
`node_2` with `node_1` being the origin.
"""
function angle(node_1::EnergySystemDesign, node_2::EnergySystemDesign)
    return atan(node_2.xy[][2] - node_1.xy[][2], node_2.xy[][1] - node_1.xy[][1])
end

"""
    angle_difference(angle1, angle2)

Compute the difference between two angles.
"""
function angle_difference(angle1, angle2)
    diff = abs(angle1 - angle2) % (2π)
    return min(diff, 2π - diff)
end

"""
    get_text_alignment(wall::Symbol)

Get the text alignment for a label attached to a wall
"""
get_text_alignment(wall::Symbol) = get_text_alignment(Val(wall))
get_text_alignment(::Val{:E}) = (:left, :center)
get_text_alignment(::Val{:W}) = (:right, :center)
get_text_alignment(::Val{:S}) = (:center, :top)
get_text_alignment(::Val{:N}) = (:center, :bottom)

"""
    function box(x, y, Δ)

Get the coordinates of a box with half side lengths `Δ` and centered at (`x`,`y`) starting
at the upper right corner.
"""
function box(x::Real, y::Real, Δ::Real)
    xs::Vector{Real} = [x + Δ, x - Δ, x - Δ, x + Δ, x + Δ]
    ys::Vector{Real} = [y + Δ, y + Δ, y - Δ, y - Δ, y + Δ]

    return xs, ys
end

"""
    stepify(x::Vector{S},
        y::Vector{T};
        start_at_zero::Bool = true
    ) where {S <: Number, T <: Number}

For a data set (`x`,`y`) add intermediate points to obtain a stepwise function and add a
point at zero if `start_at_zero = true`
"""
function stepify(
    x::Vector{S}, y::Vector{T}; start_at_zero::Bool=true
) where {S<:Number,T<:Number}
    return if start_at_zero
        (vcat(0, repeat(x[1:(end - 1)]; inner=2), x[end]), repeat(y; inner=2))
    else
        (vcat(repeat(x; inner=2), x[end]), vcat(y[1], repeat(y[2:end]; inner=2)))
    end
end

"""
    extract_combinations!(
        gui::GUI,
        available_data::Vector{Dict},
        dict::Symbol,
        model
    )

Extract all available resources in `model[dict]`
"""
function extract_combinations!(gui::GUI, available_data::Vector{Dict}, dict::Symbol, model)
    resources::Vector{Resource} = unique([key[2] for key ∈ keys(model[dict].data)])
    for res ∈ resources
        dict_str = string(dict)
        container = Dict(:name => dict_str, :is_jump_data => true, :selection => [res])
        add_description!(available_data, container, gui, "variables.$dict_str")
    end
end

"""
    extract_combinations!(available_data::Vector{Dict}, dict::Symbol, node::Plotable, model)

Extract all available resources in `model[dict]` for a given `node`.
"""
function extract_combinations!(
    gui::GUI, available_data::Vector{Dict}, dict::Symbol, node::Plotable, model
)
    if isa(model[dict], SparseVariables.IndexedVarArray)
        dict_str = string(dict)
        container = Dict(:name => dict_str, :is_jump_data => true, :selection => [node])
        add_description!(available_data, container, gui, "variables.$dict_str")
    else
        resources = unique([key[2] for key ∈ keys(model[dict][node, :, :].data)])
        for res ∈ resources
            dict_str = string(dict)
            container = Dict(
                :name => dict_str, :is_jump_data => true, :selection => [node, res]
            )
            add_description!(available_data, container, gui, "variables.$dict_str")
        end
    end
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
    return YAML.load_file(joinpath(@__DIR__, "..", "src", "colors.yml"))
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
    elseif isfile(joinpath(@__DIR__, "..", "icons", icon * ".png"))
        icon_path = joinpath(@__DIR__, "..", "icons", icon * ".png")
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
    update_sub_system_locations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})

Update the coordinates of a subsystem of design based on the movement of EnergySystemDesign
`design`.
"""
function update_sub_system_locations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})
    for component ∈ design.components
        component.xy[] = component.xy[] .+ Δ
    end
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
    get_supertypes(x::Any)

Return the vector of the supertypes of `x`.
"""
function get_supertypes(x::Any)
    T = typeof(x)
    supertypes = [T]
    while T != Any
        T = supertype(T)
        push!(supertypes, T)
    end
    return supertypes
end

"""
    find_type_field(dict::Dict, x::Any)

Return closest supertype of a key being of same type as `x`.
"""
function find_type_field(dict::Dict, x::Any)
    for supertype ∈ get_supertypes(x)
        if haskey(dict, supertype)
            return supertype
        end
    end
    return Nothing
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
    get_sector_points(;
        center::Tuple{Real,Real} = (0.0, 0.0),
        Δ::Real = 1.0,
        θ₁::Real = 0,
        θ₂::Real = π/4,
        steps::Int=200,
        type::Symbol = :circle)

Get points for the boundary of a sector defined by the center `c`, radius/halfsidelength `Δ`,
and angles `θ₁` and `θ₂` for a square (type = :rect), a circle (type = :circle), or a
triangle (type = :triangle).
"""
function get_sector_points(;
    c::Tuple{Real,Real}=(0.0, 0.0),
    Δ::Real=1.0,
    θ₁::Real=0.0,
    θ₂::Real=π / 4,
    steps::Int=200,
    type::Symbol=:circle,
)
    if type == :circle
        θ::Vector{Float64} = LinRange(θ₁, θ₂, Int(round(steps * (θ₂ - θ₁) / (2π))))
        x_coords::Vector{Float64} = Δ * cos.(θ) .+ c[1]
        y_coords::Vector{Float64} = Δ * sin.(θ) .+ c[2]

        # Include the center and close the polygon
        return [c; collect(zip(x_coords, y_coords)); c]
    elseif type == :rect
        if θ₁ == 0 && θ₂ ≈ 2π
            x_coords, y_coords = box(c[1], c[2], Δ)
            return collect(zip(x_coords, y_coords))
        else
            xy1 = square_intersection(c, θ₁, Δ)
            xy2 = square_intersection(c, θ₂, Δ)
            vertices = [c; Tuple(xy1)]
            xsign = [1, -1, -1, 1]
            ysign = [1, 1, -1, -1]
            for (i, corner_angle) ∈ enumerate([π / 4, 3π / 4, 5π / 4, 7π / 4])
                if θ₁ < corner_angle && θ₂ > corner_angle
                    push!(vertices, c .+ (Δ * xsign[i], Δ * ysign[i]))
                end
            end
            push!(vertices, Tuple(xy2))
            push!(vertices, c)
            return vertices
        end
    elseif type == :triangle
        input::Bool = θ₂ > π / 2
        if input                        # input resources on a triangle to the left
            f = θ -> -2Δ * θ / π + 2Δ
        else                          # output resources on a triangle to the right
            f = θ -> 2Δ * θ / π
        end
        d::Float64 = Δ / 2
        x::Tuple{Float64,Float64} = input ? c .- (d / 2, 0) : c .+ (d / 2, 0)
        x_side::Float64 = input ? -Δ : Δ
        xy1 = c .+ (x_side, f(θ₁))
        xy2 = c .+ (x_side, f(θ₂))
        return [x; xy1; xy2; x]
    else
        @error "Type $type is not implemented."
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
    toggle_inspector!(p::Makie.AbstractPlot, toggle::Bool)

Toggle the inspector of a Makie plot `p` using the boolean `toggle`.
"""
function toggle_inspector!(p::Makie.AbstractPlot, toggle::Bool)
    for p_sub ∈ p.plots
        if :plots ∈ fieldnames(typeof(p_sub))
            toggle_inspector!(p_sub, toggle)
        end
        p_sub.inspectable[] = toggle
    end
end

"""
    add_inspector_to_poly!(p::Makie.AbstractPlot, inspector_label::Function)

Add `inspector_label` for Poly and Mesh plots in plot `p`.
"""
function add_inspector_to_poly!(p::Makie.AbstractPlot, inspector_label::Function)
    for p_sub ∈ p.plots
        if :plots ∈ fieldnames(typeof(p_sub))
            add_inspector_to_poly!(p_sub, inspector_label)
        end
        p_sub.inspector_label = inspector_label
        p_sub.inspectable[] = true
    end
end

"""
    showdecorations!(ax)

Show all decorations of `ax`.
"""
showdecorations!(ax) = begin
    ax.xlabelvisible = true
    ax.ylabelvisible = true
    ax.xticklabelsvisible = true
    ax.yticklabelsvisible = true
    ax.xticksvisible = true
    ax.yticksvisible = true
    ax.yticklabelsvisible = true
    ax.yticklabelsvisible = true
end

"""
    showspines!(ax)

Show all four spines (frame) of `ax`.
"""
showspines!(ax) = begin
    ax.topspinevisible = true
    ax.bottomspinevisible = true
    ax.leftspinevisible = true
    ax.rightspinevisible = true
end

"""
    hidesplots!(plots::Vector)

Hide all plots in `plots`.
"""
hideplots!(plots::Vector) = begin
    for plot ∈ values(plots)
        plot.visible = false
    end
end

"""
    showplots!(plots::Vector)

Show all plots in `plots`.
"""
showplots!(plots::Vector) = begin
    for plot ∈ values(plots)
        plot.visible = true
    end
end

"""
    getfirst(f::Function, a::Vector)

Return the first element of Vector `a` satisfying the requirement of Function `f`.
"""
function getfirst(f::Function, a::Vector)
    index = findfirst(f, a)
    return isnothing(index) ? nothing : a[index]
end

"""
    export_svg(ax::Makie.Block, filename::String)

Export the `ax` to a .svg file with path given by `filename`.
"""
function export_svg(ax::Makie.Block, filename::String)
    bb = ax.layoutobservables.suggestedbbox[]
    protrusions = ax.layoutobservables.reporteddimensions[].outer

    axis_bb = Rect2f(
        bb.origin .- (protrusions.left, protrusions.bottom),
        bb.widths .+
        (protrusions.left + protrusions.right, protrusions.bottom + protrusions.top),
    )

    pad = 0

    axis_bb_pt = axis_bb * 0.75
    ws = axis_bb_pt.widths
    o = axis_bb_pt.origin
    width = "$(ws[1] + 2 * pad)pt"
    height = "$(ws[2] + 2 * pad)pt"
    viewBox = "$(o[1] - pad) $(o[2] + ws[2] - pad) $(ws[1] + 2 * pad) $(ws[2] + 2 * pad)"

    svgstring = repr(MIME"image/svg+xml"(), ax.blockscene)

    svgstring = replace(svgstring, r"""(?<=width=")[^"]*(?=")""" => width; count=1)
    svgstring = replace(svgstring, r"""(?<=height=")[^"]*(?=")""" => height; count=1)
    svgstring = replace(svgstring, r"""(?<=viewBox=")[^"]*(?=")""" => viewBox; count=1)
    open(filename, "w") do io
        print(io, svgstring)
    end
    return 0
end

"""
    export_xlsx(plots::Vector, filename::String, xlabel::Symbol)

Export the `plots` to a .xlsx file with path given by `filename` and top header `xlabel`.
"""
function export_xlsx(plots::Vector, filename::String, xlabel::Symbol)
    if isempty(plots)
        @warn "No data to be exported"
        return 1
    end
    # Create a new Excel file and write data
    XLSX.openxlsx(filename; mode="w") do xf
        sheet = xf[1] # Access the first sheet

        no_columns = length(plots) + 1
        data = Vector{Any}(undef, no_columns)
        data[1] = string.(plots[1][:t])
        for (i, plot) ∈ enumerate(plots)
            data[i + 1] = plot[:y]
        end
        labels::Vector{String} = [plot[:name] for plot ∈ plots]

        headers::Vector{Any} = vcat(xlabel, labels)

        #XLSX.rename!(sheet, "My Data Sheet")
        XLSX.writetable!(sheet, data, headers)
    end
    return 0
end

"""
    export_xlsx(plots::Makie.AbstractPlot, filename::String)

Export the plot `plots` to an xlsx file with path given by `filename`.
"""
function export_xlsx(model::JuMP.Model, filename::String)
    if isempty(model)
        @warn "No data to be exported"
        return 1
    end
    # Create a new Excel file and write data
    XLSX.openxlsx(filename; mode="w") do xf
        first_sheet::Bool = true
        for (i, dict) ∈ enumerate(collect(keys(object_dictionary(model))))
            container = model[dict]
            if isempty(container)
                continue
            end
            if first_sheet
                sheet = xf[1]
                XLSX.rename!(sheet, string(dict))
                first_sheet = false
            else
                sheet = XLSX.addsheet!(xf, string(dict))
            end
            if typeof(container) <: JuMP.Containers.DenseAxisArray
                axisTypes = nameof.([eltype(a) for a ∈ axes(model[dict])])
            elseif typeof(container) <: SparseVars
                axisTypes = collect(nameof.(typeof.(first(keys(container.data)))))
            else
                @info "dict = $dict, container = $container, typeof(container) = $(typeof(container))"
            end
            header = vcat(axisTypes, [:value])
            data_jump = JuMP.Containers.rowtable(value, container; header=header)
            no_columns = length(fieldnames(eltype(data_jump)))
            num_tuples = length(data_jump)
            data = [Vector{Any}(undef, num_tuples) for i ∈ range(1, no_columns)]
            for (i, nt) ∈ enumerate(data_jump)
                for (j, field) ∈ enumerate(fieldnames(typeof(nt)))
                    data[j][i] = string(getfield(nt, field))
                end
            end

            XLSX.writetable!(sheet, data, header)
        end
    end
    return 0
end

"""
    export_to_file(gui::GUI)

Export results based on the state of `gui`.
"""
function export_to_file(gui::GUI)
    path = gui.vars[:path_to_results]
    if isempty(path)
        @error "Path not specified for exporting results; use GUI(case; path_to_results = \
                \"<path to exporting folder>\")"
        return nothing
    end
    if !isdir(path)
        mkpath(path)
    end
    axes_str::String = gui.menus[:axes].selection[]
    time = string(gui.menus[:time].selection[])
    file_ending = gui.menus[:export_type].selection[]
    filename::String = joinpath(path, axes_str * "_" * time * "." * file_ending)
    if file_ending ∈ ["bmp", "tiff", "tif", "jpg", "jpeg", "svg", "png"]
        CairoMakie.activate!() # Set CairoMakie as backend for proper export quality
        cairo_makie_activated = true
    else
        cairo_makie_activated = false
    end
    if axes_str == "All"
        filename = joinpath(path, axes_str * "." * file_ending)
        if file_ending ∈ ["bmp", "tiff", "tif", "jpg", "jpeg"]
            @warn "Exporting the entire figure to an $file_ending file is not implemented"
            flag = 1
        elseif file_ending == "xlsx"
            flag = export_xlsx(gui.model, filename)
        elseif file_ending == "lp" || file_ending == "mps"
            try
                write_to_file(gui.model, filename)
                flag = 0
            catch
                flag = 2
            end
        else
            try
                save(filename, gui.fig)
                flag = 0
            catch
                flag = 2
            end
        end
    else
        axis_time_type = gui.menus[:time].selection[]
        if file_ending == "svg"
            flag = export_svg(gui.axes[axis_time_type], filename)
        elseif file_ending == "xlsx"
            if axis_time_type == :topo
                @warn "Exporting the topology to an xlsx file is not implemented"
                flag = 1
            else
                plots = gui.vars[:visible_plots][axis_time_type]
                flag = export_xlsx(plots, filename, axis_time_type)
            end
        elseif file_ending == "lp" || file_ending == "mps"
            try
                write_to_file(gui.model, filename)
                flag = 0
            catch
                flag = 2
            end
        else
            try
                save(filename, colorbuffer(gui.axes[axis_time_type]))
                flag = 0
            catch
                flag = 2
            end
        end
    end
    if cairo_makie_activated
        GLMakie.activate!() # Return to GLMakie as a backend
    end
    if flag == 0
        @info "Exported results to $filename"
    elseif flag == 2
        @info "An error occured, no file exported"
    end
    return flag
end

"""
    get_op(tp::TS.TimePeriod)

Get the operational period of TimePeriod `tp`.
"""
function get_op(tp::TS.TimePeriod)
    if :period in fieldnames(typeof(tp))
        return get_op(tp.period)
    else
        return tp.op
    end
end

"""
    get_nested_value(dict::Dict, keys_str::String)

Get value of a `nested` dict based on keys in the string `key_str` separated by periods.
"""
function get_nested_value(dict::Dict, keys_str::String)
    keys = split(keys_str, ".")
    current_value = dict
    for key ∈ keys
        if haskey(current_value, Symbol(key))
            current_value = current_value[Symbol(key)]
        end
    end
    return current_value
end

"""
    get_nth_field(s::String, delimiter::Char, n::Int)

Get `n`'th value of a string `s` separated by the character `delimiter`.
"""
function get_nth_field(s::String, delimiter::Char, n::Int)
    fields = split(s, delimiter)
    return length(fields) >= n ? fields[n] : ""
end

"""
    exists(data::JuMP.Containers.DenseAxisArray, node::Plotable)

Check if `node` exist in the `data` structure.
"""
function exists(data::JuMP.Containers.DenseAxisArray, node::Plotable)
    if isnothing(node)
        return false
    end
    for axis ∈ axes(data), entry ∈ axis
        if entry == node
            return true
        end
    end
    return false
end

"""
    exists(data::SparseVars, node::Plotable)

Check if `node` exist in the `data` structure.
"""
function exists(data::SparseVars, node::Plotable)
    if isnothing(node)
        return false
    end
    for key ∈ keys(data.data), entry ∈ key
        if entry == node
            return true
        end
    end
    return false
end
