"""
    function installed()

Get a list of installed packages (from the depricated Pkg.installed())
"""
function installed()
    deps = Pkg.dependencies()
    installs = Dict{String, VersionNumber}()
    for (uuid, dep) in deps
        dep.is_direct_dep || continue
        dep.version === nothing && continue
        installs[dep.name] = dep.version::VersionNumber
    end
    return installs
end

"""
    get_representative_period_indices(T::TS.TimeStructure, sp::Int64, sc::Int64)

Return indices of the representative periods for strategic period number sp and scenario sc
"""
function get_representative_period_indices(T::TS.TimeStructure, sp::Int64, sc::Int64)
    if eltype(T.operational) <: TS.OperationalScenarios 
        if eltype(T.operational[sp].scenarios) <: TS.RepresentativePeriods 
            return (1:T.operational[sp].scenarios[sc].len)
        else
            return (1:T.operational[sp].len)
        end
    elseif eltype(T.operational) <: TS.RepresentativePeriods 
        return (1:T.operational[sp].len)
    else
        return [1]
    end
end

"""
    get_scenario_indices(T::TS.TimeStructure, sp::Int64)

Return indices of the scenarios for stratigic period number sp
"""
function get_scenario_indices(T::TS.TimeStructure, sp::Int64)
    return eltype(T.operational) <: TS.OperationalScenarios ? (1:T.operational[sp].len) : [1]
end

"""
    square_intersection(c::Vector{Tc}, x::Vector{Tx}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}

Calculate the intersection point between a line starting at `x` and direction described by `θ` and a square with half side lengths `Δ` centered at center `c`  	
"""
function square_intersection(c::Vector{Tc}, x::Vector{Tx}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}
    # Ensure that -π ≤ θ ≤ π
    θ = θ > π ? θ-2π : θ
    θ = θ < -π ? θ+2π : θ

    # Calculate angles at the corers of the square with respect to the point x
    θ_se::Tθ = atan(c[2] - x[2] - Δ, c[1] - x[1] + Δ)
    θ_ne::Tθ = atan(c[2] - x[2] + Δ, c[1] - x[1] + Δ)
    θ_nw::Tθ = atan(c[2] - x[2] + Δ, c[1] - x[1] - Δ)
    θ_sw::Tθ = atan(c[2] - x[2] - Δ, c[1] - x[1] - Δ)

    # Return the intersection point
    if θ_se <= θ && θ < θ_ne # Facing walls are (:E, :W)
        return [c[1]+Δ, x[2] + (c[1]+Δ-x[1])*tan(θ)]
    elseif θ_ne <= θ && θ < θ_nw # Facing walls are (:N, :S)
        return [x[1] + (c[2]+Δ-x[2])/tan(θ), c[2]+Δ]
    elseif θ_sw <= θ && θ < θ_se # Facing walls are (:S, :N)
        return [x[1] + (c[2]-Δ-x[2])/tan(θ), c[2]-Δ]
    else # Facing walls are (:W, :E)
        return [c[1]-Δ, x[2] + (c[1]-Δ-x[1])*tan(θ)]
    end
end

"""
    square_intersection(c::Tuple{Tc, Tc}, x::Tuple{Tx, Tx}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}

Calculate the intersection point between a line starting at `x` and direction described by `θ` and a square with half side lengths `Δ` centered at center `c`  	
"""
function square_intersection(c::Tuple{Tc, Tc}, x::Tuple{Tx, Tx}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}
    return square_intersection(collect(c), collect(x), θ, Δ)
end

"""
    square_intersection(c::Tuple{Tc, Tc}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}

Calculate the intersection point between a line starting at `c` and direction described by `θ` and a square with half side lengths `Δ` centered at center `c`  	
"""
function square_intersection(c::Tuple{Tc, Tc}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tθ<:Real, TΔ<:Real}
    return square_intersection(collect(c), collect(c), θ, Δ)
end

"""
    norm(x::Vector{T}) where T<:Real

Compute the l2-norm of a vector.
"""
function norm(x::Vector{T}) where T<:Real
    return sqrt(sum(x.^2))
end

"""
    norm(x::Tuple) where T<:Real

Compute the l2-norm of a tuple.
"""
function norm(x::Tuple)
    return norm(collect(x))
end
"""
    find_min_max_coordinates(design::EnergySystemDesign,min_x::Number, max_x::Number, min_y::Number, max_y::Number)

Find the minimum and maximum coordinates of the components of design
"""
function find_min_max_coordinates(design::EnergySystemDesign, min_x::Number, max_x::Number, min_y::Number, max_y::Number)
    if design.xy !== nothing && haskey(design.system,:node)
        x, y = design.xy[]
        min_x = min(min_x, x)
        max_x = max(max_x, x)
        min_y = min(min_y, y)
        max_y = max(max_y, y)
    end
    
    for child in design.components
        min_x, max_x, min_y, max_y = find_min_max_coordinates(child, min_x, max_x, min_y, max_y)
    end
    
    return min_x, max_x, min_y, max_y
end

"""
    find_min_max_coordinates(design::EnergySystemDesign)

Find the minimum and maximum coordinates of the components of design
"""
function find_min_max_coordinates(design::EnergySystemDesign)
    return find_min_max_coordinates(design, Inf, -Inf, Inf, -Inf)
end

"""
    angle(component_design_from::EnergySystemDesign, component_design_to::EnergySystemDesign)

Based on the location of node1 and node2, return the angle between the x_axis and node2 (when node1 is the origin)
"""
function angle(node1::EnergySystemDesign, node2::EnergySystemDesign)
    return atan(node2.xy[][2]-node1.xy[][2], node2.xy[][1]-node1.xy[][1])
end

"""
    angle_difference(angle1, angle2)

Compute the difference between two angles
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

Get the coordinates of a box with half side lengths Δ and centered at (x,y) starting at the upper right corner.
"""
function box(x::Real, y::Real, Δ::Real)
    xs::Vector{Real} = [x + Δ, x - Δ, x - Δ, x + Δ, x + Δ]
    ys::Vector{Real} = [y + Δ, y + Δ, y - Δ, y - Δ, y + Δ]

    return xs, ys
end

"""
    stepify(x::Vector{S}, y::Vector{T}; startAtZero::Bool = true) where {S <: Number, T <: Number}

For a data set (x,y) add intermediate points to obtain a stepwise function and add a point at zero if `startAtZero = true`
"""
function stepify(x::Vector{S}, y::Vector{T}; startAtZero::Bool = true) where {S <: Number, T <: Number}
    return startAtZero ? (vcat(0, repeat(x[1:end-1], inner = 2), x[end]), repeat(y, inner = 2)) : 
                         (vcat(repeat(x, inner = 2), x[end]), vcat(y[1], repeat(y[2:end], inner = 2)))
end

"""
    extract_combinations!(gui::GUI, availableData::Vector{Dict}, dict::Any, node::Nothing, model)

Extract all available resources in `model[dict]`
"""
function extract_combinations!(gui::GUI, availableData::Vector{Dict}, dict::Any, node::Nothing, model)
    resources::Vector{Resource} = unique([key[2] for key in keys(model[dict].data)]) 
    for res ∈ resources
        container = Dict(
            :name => string(dict), 
            :isJuMPdata => true, 
            :selection => [res],
        )
        add_description!(availableData, container, gui, dict)
    end
end

"""
    extract_combinations!(availableData::Vector{Dict}, dict::Any, node::EMB.Node, model)

Extract all available resources in `model[dict]` for a given `node`
"""
function extract_combinations!(gui::GUI, availableData::Vector{Dict}, dict::Any, node, model)
    resources = unique([key[2] for key in keys(model[dict][node,:,:].data)]) 
    for res ∈ resources
        container = Dict(
            :name => string(dict), 
            :isJuMPdata => true, 
            :selection => [node, res],
        )
        add_description!(availableData, container, gui, dict)
    end
end

"""
    place_nodes_in_circle(total_nodes::Int, current_node::Int, r::Real, xₒ::Real, yₒ::Real)

Return coordinate for point number `i` of a total of `n` points evenly distributed around a circle of radius `r` centered at (xₒ, yₒ) from -π/4 to 5π/4
"""
function place_nodes_in_circle(n::Int, i::Int, r::Real, xₒ::Real, yₒ::Real)
    θ::Float64 = n == 1 ? π : -π/4 + 3π/2 * (1 - (i-1)/(n-1))
    x::Float64 = xₒ + r * cos(θ)
    y::Float64 = yₒ + r * sin(θ)
    return x, y
end

"""
    set_colors(idToColorMap::Dict{Any,Any}, products::Vector{S}, productsColors::Vector{T})

Returns a dictionary idToColorMap with id from products and colors from productColors (which is a vector of any combinations of String and Symbol).
Color can be represented as a hex (i.e. #a4220b2) or a symbol (i.e. :green), but also a string of the identifier for default colors in the src/colors.yml file
"""
function set_colors(products::Vector{S}, productsColors::Vector{T}) where {S <: EMB.Resource, T <: Any}
    idToColorMap::Dict{Any,Any} = Dict{Any, Any}() # Initialize dictionary for colors map
    if isempty(productsColors)
        return idToColorMap
    end
    if length(products) != length(productsColors)
        @error "The input vectors must have same lengths."
        return
    end
    for (i, product) ∈ enumerate(products)
        if productsColors[i] isa Symbol || productsColors[i] isa RGB || productsColors[i][1] == '#'
            idToColorMap[product.id] = productsColors[i] 
        else
            try
                resourceColors::Dict{String, Any} = get_default_colors()
                idToColorMap[product.id] = resourceColors[productsColors[i]]
            catch
                @warn("Color identifier $(productsColors[i]) is not represented in the colors file $colorsFile. " 
                      *"Using :black instead for \"$(product.id)\".")
                idToColorMap[product.id] = "#000000" 
            end
        end
    end
    return idToColorMap
end

"""
    set_colors(idToColorMap::Dict{Any,Any}, products::Vector{S}, productsColors::Vector{T})

Returns a dictionary that completes the dictionary `idToColorMap` with default color values for standard names (like Power, NG, Coal, CO2) collected from `src/colors.yml`.
Color can be represented as a hex (i.e. #a4220b2) or a symbol (i.e. :green), but also a string of the identifier for default colors in the src/colors.yml file
"""
function set_colors(products::Vector{S}, idToColorMap::Dict) where {S <: EMB.Resource}
    complete_idToColorMap::Dict = Dict()
    defaultColors::Dict = get_default_colors()
    for product ∈ products
        if haskey(defaultColors, product.id)
            complete_idToColorMap[product.id] = defaultColors[product.id]
        end
    end
    for (key, val) ∈ idToColorMap
        complete_idToColorMap[string(key)] = val
    end
    seed::Vector{RGB} = [parse(Colorant, hex_color) for hex_color ∈ values(complete_idToColorMap)]
    productsColors::Vector{RGB} = distinguishable_colors(length(products), seed, dropseed=false)
    for product ∈ products
        if !haskey(complete_idToColorMap, product.id)
            complete_idToColorMap[product.id] = productsColors[length(complete_idToColorMap)+1]
        end
    end
    return complete_idToColorMap
end

"""
    get_default_colors()

Get the default colors in the EnergyModelsGUI repository at src/colors.yml
"""
function get_default_colors()
    return YAML.load_file(joinpath(@__DIR__,"..","src", "colors.yml"))
end

"""
    set_icons(idToIconMap::Dict)

Return a dictionary idToIconMap with id from nodes and icon paths based on provided paths (or name of .png icon file which will be found in the icons folder of any of the EMX packages). 

The icon images are assumed to be in .png format, and the strings should not contain this file ending.
"""
function set_icons(idToIconMap::Dict)
    if isempty(idToIconMap)
        return idToIconMap
    end
    for (key, val) ∈ idToIconMap
        idToIconMap[key] = find_icon_path(val)
    end
    return idToIconMap
end

"""
    set_icons(products::Vector{S}, productsColors::Vector{T})

Return a dictionary idToIconMap with id from nodes and icon paths based on provided paths (or name of .png icon file which will be found in the icons folder of any of the EMX packages). 

The icon images are assumed to be in .png format, and the strings should not contain this file ending.
"""
function set_icons(nodes::Vector{S}, icons::Vector{T}) where {S <: EMB.Node, T <: Any}
    idToIconMap::Dict{Any,Any} = Dict{Any, Any}() # Initialize dictionary for icons map
    if isempty(icons)
        return idToIconMap
    end
    if length(nodes) != length(icons)
        @error "The input vectors must have same lengths."
        return
    end
    for (i, node) ∈ enumerate(nodes)
        idToIconMap[node.id] = find_icon_path(icons[i])
    end
    return idToIconMap
end

"""
    function find_icon_path(icon::String)

Search for path to icon based on icon name `icon`
"""

function find_icon_path(icon::String)
    icon_path = "" # in case not found
    if isfile(icon)
        icon_path = icon * ".png"
    elseif isfile(joinpath(@__DIR__,"..","icons", icon * ".png"))
        icon_path = joinpath(@__DIR__,"..","icons", icon * ".png")
    else
        # Get a dictionary of installed packages
        installed_packages = installed()

        # Filter packages with names matching the pattern "EnergyModels*"
        EMXpackages = filter(pkg -> occursin(r"EnergyModels", pkg), keys(installed_packages))

        # Search through EMX packages if icons are available there
        for package ∈ EMXpackages
            packagePath::Union{String, Nothing} = Base.find_package(package)
            if !isnothing(packagePath)
                colorsFile::String = joinpath(packagePath, "ext", "EnergyModelsGUI", "icons", icon) * ".png"
                if isfile(colorsFile)
                    icon_path = colorsFile 
                    break
                end
            end
        end
    end
    return icon_path
end

"""
    update_sub_system_locations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})

Update the coordinates of a subsystem of design based on the movement of design
"""
function update_sub_system_locations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})
    for component ∈ design.components
        component.xy[] = component.xy[] .+ Δ
    end
end

"""
    design_file(system::Dict, path::String)

Construct the path for the .yml file for `system` in the folder `path`
"""
function design_file(system::Dict, path::String)
    if isempty(path)
        return ""
    end
    if !isdir(path)
        mkpath(path)
    end
    systemName::String = if !haskey(system,:node)
        "TopLevel"
    else
        string(system[:node])
    end
    file::String = joinpath(path, "$(systemName).yml")

    return file
end

"""
    find_icon(system::Dict, idToIconMap::Dict)

Find the icon associated with a given system's node id.
"""
function find_icon(system::Dict, idToIconMap::Dict)
    icon::String = ""
    if haskey(system,:node) && !isempty(idToIconMap)
        supertype::DataType = find_type_field(idToIconMap, system[:node])
        if haskey(idToIconMap, system[:node].id)
            icon = idToIconMap[system[:node].id]
        elseif supertype != Nothing
            icon = idToIconMap[supertype]
        else
            @warn("Could not find $(system[:node].id) in idToIconMap nor the type $(typeof(system[:node])). Using default setup instead")
        end
    end
    return icon
end

"""
    get_supertypes(x::Any)
    
Return the vector of the supertypes of x
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

Return closest supertype of a key being of same type as x
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

Save the x,y-coordinates of `design` to a .yml file at design.file
"""
function save_design(design::EnergySystemDesign)
    if isempty(design.file)
        @error "Path not specified for saving; use GUI(case; design_path)"
        return
    end

    design_dict::Dict = Dict()

    for component in design.components
        # Extract x,y-coordinates
        x, y = component.xy[]

        design_dict[string(component.system[:node])] = Dict(
            :x => round(x; digits = 5),
            :y => round(y; digits = 5),
        )
    end

    @info "Saving design coordinates to file $(design.file)"
    save_design(design_dict, design.file)
end

"""
    save_design(design::EnergySystemDesign, file::String)

Save the x,y-coordinates of `design_dict` to a .yml file at location given by `file`
"""
function save_design(design_dict::Dict, file::String)
    YAML.write_file(file, design_dict)
end

"""
    get_linked_nodes!(node::EMB.Node, system::Dict{Symbol, Any}, links::Vector{EMB.Link}, nodes::Vector{EMB.Node}, indices::Vector{Int})

Recursively find all nodes connected (directly or indirectly) to `node` in a system `system` and store the found links in `links` and nodes in `nodes`. Here, `indices` contains the indices where the next link and node is to be stored, repsectively.
"""
function get_linked_nodes!(node::EMB.Node, system::Dict{Symbol, Any}, links::Vector{EMB.Link}, nodes::Vector{EMB.Node}, indices::Vector{Int})
    for link ∈ system[:links]
        if node ∈ [link.from, link.to] && (indices[1] == 1 || !(link ∈ links[1:indices[1]-1]))
            links[indices[1]] = link
            indices[1] += 1

            newNodeAdded::Bool = false
            if node == link.from && !(link.to ∈ nodes[1:indices[2]-1])
                nodes[indices[2]] = link.to
                newNodeAdded = true
            elseif node == link.to && !(link.from ∈ nodes[1:indices[2]-1])
                nodes[indices[2]] = link.from
                newNodeAdded = true
            end

            # Recursively add other nodes
            if newNodeAdded
                indices[2] += 1
                get_linked_nodes!(nodes[indices[2]-1], system, links, nodes, indices)
            end
        end
    end
end

"""
    get_sector_points(;center::Tuple{Real,Real} = (0.0, 0.0), Δ::Real = 1.0, θ₁::Real = 0, θ₂::Real = π/4, steps::Int=200, type::Symbol = :circle)
    
Get points for the boundary of a sector defined by the center `c`, radius/halfsidelength `Δ`, and angles `θ₁` and `θ₂` for a square (type = :rect), a circle (type = :circle) or a triangle (type = :triangle)
"""
function get_sector_points(;c::Tuple{Real,Real} = (0.0, 0.0), Δ::Real = 1.0, θ₁::Real = 0.0, θ₂::Real = π/4, steps::Int=200, type::Symbol = :circle)
    if type == :circle
        θ::Vector{Float64} = LinRange(θ₁, θ₂, Int(round(steps*(θ₂-θ₁)/(2π))))
        xCoords::Vector{Float64} = Δ * cos.(θ) .+ c[1]
        yCoords::Vector{Float64} = Δ * sin.(θ) .+ c[2]
    
        # Include the center and close the polygon
        return [c; collect(zip(xCoords, yCoords)); c]
    elseif type == :rect
        if θ₁ == 0 && θ₂ ≈ 2π
            xCoords, yCoords = box(c[1], c[2], Δ)
            return collect(zip(xCoords, yCoords))
        else
            xy1 = square_intersection(c, θ₁, Δ)
            xy2 = square_intersection(c, θ₂, Δ)
            return [c; Tuple(xy1); Tuple(xy2); c]
        end
    elseif type == :triangle
        input::Bool = θ₂ > π/2
        if input                        # input resources on a triangle to the left
            f = θ -> -2Δ*θ/π + 2Δ
        else                          # output resources on a triangle to the right
            f = θ -> 2Δ*θ/π 
        end
        d::Float64 = Δ/2
        x::Tuple{Float64, Float64}   = input ? c .- (d/2, 0) : c .+ (d/2, 0)
        x_side::Float64 = input ? -Δ : Δ
        xy1 = c .+ (x_side, f(θ₁))
        xy2 = c .+ (x_side, f(θ₂))
        return [x; xy1; xy2; x]
    else
        @error "Type $type is not implemented."
    end
end

"""
    get_resource_colors(resources::Vector{EMB.Resource}, idToColorMap::Dict{Any,Any})

Get the colors linked the the resources in `resources` based on the mapping `idToColorMap`
"""
function get_resource_colors(resources::Vector{T}, idToColorMap::Dict{Any,Any}) where T <: EMB.Resource
    hexColors::Vector{Any} = [idToColorMap[resource.id] for resource ∈ resources]
    return [parse(Colorant, hex_color) for hex_color ∈ hexColors]
end

"""
    get_resource_colors(resources::Dict{EMB.Resource, Real}, idToColorMap::Dict{Any,Any})

Get the colors linked the the resources in `resources` based on the mapping `idToColorMap`
"""
function get_resource_colors(resources::Dict{T, S}, idToColorMap::Dict{Any,Any}) where {T <: EMB.Resource, S <: Real}
    return get_resource_colors(collect(keys(resources)), idToColorMap)
end

"""
    get_resource_colors(resources::Vector{EMG.TransmissionMode}, idToColorMap::Dict{Any,Any})

Get the colors linked the the resources in `modes` (from Transmission.modes) based on the mapping `idToColorMap`
"""
function get_resource_colors(modes::Vector{T}, idToColorMap::Dict{Any,Any}) where T <: EMG.TransmissionMode
    hexColors::Vector{Any} = [idToColorMap[map_trans_resource(mode).id] for mode ∈ modes]
    return [parse(Colorant, hex_color) for hex_color ∈ hexColors]
end

"""
    toggle_inspector!(p::Makie.AbstractPlot, toggle::Bool)

Toggle the inspector of a Makie plot
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

Add inspector_label for Poly and Mesh plots in Makie
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

Show all decorations of the ax input object
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
    get_resource_colors(::Vector{Any}, ::Dict{Any,Any})

Return empty vector for empty input
"""
function get_resource_colors(::Vector{Any}, ::Dict{Any,Any})
    return Vector{RGB}(undef,0)
end

"""
    showspines!(ax)

Show all four spines (frame) of the ax input object
"""
showspines!(ax) = begin
    ax.topspinevisible = true
    ax.bottomspinevisible = true
    ax.leftspinevisible = true
    ax.rightspinevisible = true
end

"""
    hidesplots!(plotObjs::Vector)

Hide all plots in plotObjs
"""
hideplots!(plotObjs::Vector) = begin
    for plot in values(plotObjs)
        plot.visible = false
    end
end

"""
    showplots!(plotObjs::Vector)

Show all plots in plotObjs
"""
showplots!(plotObjs::Vector) = begin
    for plot in values(plotObjs)
        plot.visible = true
    end
end

"""
    getfirst(f::Function, a::Vector)

Return the first elemnt of a satisfying the requirement of f.
"""
function getfirst(f::Function, a::Vector)
    index = findfirst(f, a)
    return isnothing(index) ? nothing : a[index]
end

"""
    export_svg(ax::Makie.Block, filename::String)

Export the `ax` to an svg file with path given by `filename`
"""
function export_svg(ax::Makie.Block, filename::String)
    bb = ax.layoutobservables.suggestedbbox[]
    protrusions = ax.layoutobservables.reporteddimensions[].outer

    axis_bb = Rect2f(
        bb.origin .- (protrusions.left, protrusions.bottom),
        bb.widths .+ (protrusions.left + protrusions.right, protrusions.bottom + protrusions.top)
    )

    pad = 0

    axis_bb_pt = axis_bb * 0.75
    ws = axis_bb_pt.widths
    o = axis_bb_pt.origin
    width = "$(ws[1] + 2 * pad)pt"
    height = "$(ws[2] + 2 * pad)pt"
    viewBox = "$(o[1] - pad) $(o[2] + ws[2] - pad) $(ws[1] + 2 * pad) $(ws[2] + 2 * pad)"

    svgstring = repr(MIME"image/svg+xml"(), ax.blockscene)

    svgstring = replace(svgstring, r"""(?<=width=")[^"]*(?=")""" => width, count = 1)
    svgstring = replace(svgstring, r"""(?<=height=")[^"]*(?=")""" => height, count = 1)
    svgstring = replace(svgstring, r"""(?<=viewBox=")[^"]*(?=")""" => viewBox, count = 1)
    open(filename, "w") do io
        print(io, svgstring)
    end
    return 0
end

"""
    export_xlsx(plotObjs::Makie.AbstractPlot, filename::String, xlabel::Symbol)

Export the `plotObjs` to an xlsx file with path given by `filename`
"""
function export_xlsx(plotObjs::Makie.AbstractPlot, filename::String, xlabel::Symbol)
    if isempty(plotObjs)
        @warn "No data to be exported"
        return 1
    end
    # Create a new Excel file and write data
    XLSX.openxlsx(filename, mode="w") do xf
        sheet = xf[1] # Access the first sheet

        noColumns = length(plotObjs)+1
        data = Vector{Any}(undef,noColumns)
        data[1] = string.(plotObjs[1][:t])
        for (i, plotObj) ∈ enumerate(plotObjs)
            data[i+1] = plotObj[:y]
        end
        labels::Vector{String} = [plotObj[:name] for plotObj in plotObjs]

        headers::Vector{Any} = vcat(xlabel, labels)

        #XLSX.rename!(sheet, "My Data Sheet")
        XLSX.writetable!(sheet, data, headers)
    end
    return 0
end

"""
    export_xlsx(plotObjs::Makie.AbstractPlot, filename::String)

Export the `plotObjs` to an xlsx file with path given by `filename`
"""
function export_xlsx(model::JuMP.Model, filename::String)
    if isempty(model)
        @warn "No data to be exported"
        return 1
    end
    # Create a new Excel file and write data
    XLSX.openxlsx(filename, mode="w") do xf
        for (i, dict) ∈ enumerate(collect(keys(object_dictionary(model))))
            sheet = XLSX.addsheet!(xf, string(dict))
            container = model[dict]
            if isempty(container)
                continue
            end
            if typeof(container) <: JuMP.Containers.DenseAxisArray
                axisTypes = nameof.([eltype(a) for a in axes(model[dict])])
            elseif typeof(container) <: JuMP.Containers.SparseAxisArray
                axisTypes = collect(nameof.(typeof.(first(container.data)[1])))
            end
            header = vcat(axisTypes, [:value])
            dataJuMP = JuMP.Containers.rowtable(
                    value,
                    container;
                    header=header,
            )
            noColumns = length(fieldnames(eltype(dataJuMP)))
            num_tuples = length(dataJuMP)
            data = [Vector{Any}(undef,num_tuples) for i ∈ range(1,noColumns)]
            for (i, nt) in enumerate(dataJuMP)
                for (j, field) in enumerate(fieldnames(typeof(nt)))
                    data[j][i] = string(getfield(nt, field))
                end
            end

            XLSX.writetable!(sheet, data, header)
        end
    end
    return 0
end

"""
    export_svg(ax::Makie.Block, filename::String)

Export results based on the state of `gui`
"""
function export_to_file(gui::GUI)
    path = gui.vars[:pathToResults]
    if isempty(path)
        @error "Path not specified for exporting results; use GUI(case; pathToResults = \"<path to exporting folder>\")"
        return
    end
    if !isdir(path)
        mkpath(path)
    end
    axesStr::String = gui.menus[:axes].selection[]
    fileEnding = gui.menus[:saveResults].selection[]
    filename::String = joinpath(path, axesStr * "." * fileEnding)
    if fileEnding ∈ ["bmp", "tiff", "tif", "jpg", "jpeg", "svg", "png"]
        CairoMakie.activate!() # Set CairoMakie as backend for proper export quality
        carioMakieActivated = true
    else
        carioMakieActivated = false
    end
    if axesStr == "All"
        axisTimeType = :topo
        if fileEnding ∈ ["bmp", "tiff", "tif", "jpg", "jpeg"]
            @warn "Exporting the figure to an $fileEnding file is not implemented"
            flag = 1
        elseif fileEnding == "xlsx"
            flag = export_xlsx(gui.model, filename)
        else
            try
                save(filename,gui.fig)
                flag = 0
            catch
                flag = 2
            end
        end
    else
        axisTimeType = gui.menus[:time].selection[]
        if fileEnding == "svg"
            flag = export_svg(gui.axes[axisTimeType], filename)
        elseif fileEnding == "xlsx"
            if axisTimeType == :topo
                @warn "Exporting the topology to an xlsx file is not implemented"
                flag = 1
            else
                plotObjs = gui.vars[:visiblePlots][axisTimeType]
                flag = export_xlsx(plotObjs, filename, axisTimeType)
            end
        else
            try
                save(filename,colorbuffer(gui.axes[axisTimeType]))
                flag = 0
            catch
                flag = 2
            end
        end
    end
    if carioMakieActivated 
        GLMakie.activate!() # Return to GLMakie as a backend
    end
    if flag == 0
        @info "Exported results to $filename"
    elseif flag == 2
        @info "An error occured, no file exported"
    end
end

"""
    get_op(x::TS.TimePeriod)

Get the operational time of `x`
"""
function get_op(x::TS.TimePeriod)
    if :period in fieldnames(typeof(x))
        return get_op(x.period)
    else
        return x.op
    end
end