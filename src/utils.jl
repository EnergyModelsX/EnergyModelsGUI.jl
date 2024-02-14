"""
    squareIntersection(c::Vector{Tc}, x::Vector{Tx}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}

Calculate the intersection point between a line starting at `x` and direction described by `θ` and a square with half side lengths `Δ` centered at center `c`  	
"""
function squareIntersection(c::Vector{Tc}, x::Vector{Tx}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}
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
    squareIntersection(c::Tuple{Tc, Tc}, x::Tuple{Tx, Tx}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}

Calculate the intersection point between a line starting at `x` and direction described by `θ` and a square with half side lengths `Δ` centered at center `c`  	
"""
function squareIntersection(c::Tuple{Tc, Tc}, x::Tuple{Tx, Tx}, θ::Tθ, Δ::TΔ) where {Tc<:Real, Tx<:Real, Tθ<:Real, TΔ<:Real}
    return squareIntersection(collect(c), collect(x), θ, Δ)
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
    facingWalls(component_design_from::EnergySystemDesign, component_design_to::EnergySystemDesign)

Based on the location of node1 and node2, return the respective walls that face eachother
"""
function facingWalls(node1::EnergySystemDesign, node2::EnergySystemDesign)
    xy_from::Tuple{Real, Real} = node1.xy[]
    xy_to::Tuple{Real, Real} = node2.xy[]
    θ::Float64 = atan(xy_to[2]-xy_from[2], xy_to[1]-xy_from[1])
    if -π/4 <= θ && θ < π/4 
        return (:E, :W)
    elseif π/4 <= θ && θ < 3π/4 
        return (:N, :S)
    elseif -3π/4 <= θ && θ < -π/4 
        return (:S, :N)
    else
        return (:W, :E)
    end
end

"""
    getOppositeWall(wall::Symbol)

return the oposite wall of the input argument
"""
function getOppositeWall(wall::Symbol)
    if wall == :E
        return :W
    elseif wall == :N
        return :S
    elseif wall == :W
        return :E
    else
        return :N
    end
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
    extractCombinations!(availableData::Vector{Vector{Any}}, dict::Any, node::Nothing, model::JuMP.Model)

Extract all available resources in `model[dict]`
"""
function extractCombinations!(availableData::Vector{Vector{Any}}, dict::Any, node::Nothing, model::JuMP.Model)
    resources::Vector{Resource} = unique([key[2] for key in keys(model[dict].data)]) 
    for res ∈ resources
        push!(availableData, [dict, res, node])
    end
end

"""
    extractCombinations!(availableData::Vector{Vector{Any}}, dict::Any, node::EMB.Node, model::JuMP.Model)

Extract all available resources in `model[dict]` for a given `node`
"""
function extractCombinations!(availableData::Vector{Vector{Any}}, dict::Any, node::Union{EMB.Node, EMB.Link, EMG.Area, EMG.Transmission}, model::JuMP.Model)
    resources = unique([key[2] for key in keys(model[dict][node,:,:].data)]) 
    for res ∈ resources
        push!(availableData, [dict, res, node])
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
    setColors(idToColorMap::Dict{Any,Any}, products::Vector{S}, productsColors::Vector{T})

Returns a dictionary idToColorMap with id from products and colors from productColors (which is a vector of any combinations of String and Symbol).
Color can be represented as a hex (i.e. #a4220b2) or a symbol (i.e. :green), but also a string of the identifier for default colors in the src/colors.toml file
"""
function setColors(products::Vector{S}, productsColors::Vector{T}) where {S <: EMB.Resource, T <: Any}
    if length(products) != length(productsColors)
        @error "The input vectors must have same lengths."
    end
    idToColorMap::Dict{Any,Any} = Dict{Any, Any}() # Initialize dictionary for colors map
    colorsFile::String = joinpath(@__DIR__,"..","src", "colors.toml")
    resourceColors::Dict{String, Any} = TOML.parsefile(colorsFile)["Resource"]
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
    return idToColorMap
end

"""
    setIcons(products::Vector{S}, productsColors::Vector{T})

Return a dictionary idToIconMap with id from nodes and icon paths based on provided paths (or name of .png icon file which will be found in the icons folder of any of the EMX packages). 

The icon images are assumed to be in .png format, and the strings should not contain this file ending.
"""
function setIcons(nodes::Vector{S}, icons::Vector{T}) where {S <: EMB.Node, T <: Any}
    idToIconMap::Dict{Any,Any} = Dict{Any, Any}() # Initialize dictionary for icons map
    if isempty(icons)
        return idToIconMap
    end
    if length(nodes) != length(icons)
        @error "The input vectors must have same lengths."
    end
    for (i, node) ∈ enumerate(nodes)
        if isfile(icons[i])
            idToIconMap[node.id] = icons[i] * ".png"
        elseif isfile(joinpath(@__DIR__,"..","icons", icons[i] * ".png"))
            idToIconMap[node.id] = joinpath(@__DIR__,"..","icons", icons[i] * ".png")
        else
            # Search through EMX packages if icons are available there
            for package ∈ ["EnergyModelsGUI", 
                           "EnergyModelsGeography", 
                           "EnergyModelsInvestments", 
                           "EnergyModelsCO2",
                           "EnergyModelsHydrogen",
                           "EnergyModelsRenewableProducers",
                           "EnergyModelsSDDP",
                           "EnergyModelsBase"]
                packagePath::Union{String, Nothing} = Base.find_package(package)
                if !isnothing(packagePath)
                    colorsFile::String = joinpath(packagePath, "..", "..", "icons", icons[i]) * ".png"
                    if isfile(colorsFile)
                        idToIconMap[node.id] = colorsFile 
                        break
                    end
                end
            end
        end
    end
    return idToIconMap
end

"""
    updateSubSystemLocations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})

Update the coordinates of a subsystem of design based on the movement of design
"""
function updateSubSystemLocations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})
    for component ∈ design.components
        component.xy[] = component.xy[] .+ Δ
    end
end

"""
    design_file(system::Dict, path::String)

Construct the path for the .toml file for `system` in the folder `path`
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
    file::String = joinpath(path, "$(systemName).toml")

    return file
end

"""
    find_icon(system::Dict, idToIconMap::Dict{Any,Any})

Find the icon associated with a given system's node id.
"""
function find_icon(system::Dict, idToIconMap::Dict{Any,Any})
    icon::String = ""
    if haskey(system,:node) && !isempty(idToIconMap)
        try
            icon = idToIconMap[system[:node].id]
        catch
            @warn("Could not find $(system[:node].id) in idToIconMap")
        end
    end
    return icon
end

"""
    save_design(design::EnergySystemDesign)

Save the x,y-coordinates of `design` to a .toml file at design.file
"""
function save_design(design::EnergySystemDesign)

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

Save the x,y-coordinates of `design_dict` to a .toml file at location given by `file`
"""
function save_design(design_dict::Dict, file::String)
    open(file, "w") do io
        TOML.print(io, design_dict) do val
            if val isa Symbol
                return string(val)
            end
        end
    end
end

"""
    getLinkedNodes!(node::EMB.Node, system::Dict{Symbol, Any}, links::Vector{EMB.Link}, nodes::Vector{EMB.Node}, indices::Vector{Int})

Recursively find all nodes connected (directly or indirectly) to `node` in a system `system` and store the found links in `links` and nodes in `nodes`. Here, `indices` contains the indices where the next link and node is to be stored, repsectively.
"""
function getLinkedNodes!(node::EMB.Node, system::Dict{Symbol, Any}, links::Vector{EMB.Link}, nodes::Vector{EMB.Node}, indices::Vector{Int})
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
                getLinkedNodes!(nodes[indices[2]-1], system, links, nodes, indices)
            end
        end
    end
end

"""
    getSectorPoints(;center::Tuple{Real,Real} = (0.0, 0.0), Δ::Real = 1.0, θ₁::Real = 0, θ₂::Real = π/4, steps::Int=200, type::Symbol = :circle)
    
Get points for the boundary of a sector defined by the center `c`, radius/halfsidelength `Δ`, and angles `θ₁` and `θ₂` for a square (type = :rect) or a circle (type = :circle)
"""
function getSectorPoints(;c::Tuple{Real,Real} = (0.0, 0.0), Δ::Real = 1.0, θ₁::Real = 0.0, θ₂::Real = π/4, steps::Int=200, type::Symbol = :circle)
    θ::Vector{Float64} = LinRange(θ₁, θ₂, Int(round(steps*(θ₂-θ₁)/(2π))))
    if type == :circle
        x::Vector{Float64} = Δ * cos.(θ) .+ c[1]
        y::Vector{Float64} = Δ * sin.(θ) .+ c[2]
    
        # Include the center and close the polygon
        return [c; collect(zip(x, y)); c]
    elseif type == :rect
        if θ₁ == 0 && θ₂ ≈ 2π
            x, y = box(c[1], c[2], Δ)
            return collect(zip(x, y))
        else
            xy1::Vector{Float64} = squareIntersection(c, c, θ₁, Δ)
            xy2::Vector{Float64} = squareIntersection(c, c, θ₂, Δ)
            return [c; Tuple(xy1); Tuple(xy2); c]
        end
    else
        @error "Type $type is not implemented."
    end
end
            
"""
    getResourceColors(resources::Vector{EMB.Resource}, idToColorMap::Dict{Any,Any})

Get the colors linked the the resources in `resources` based on the mapping `idToColorMap`
"""
function getResourceColors(resources::Vector{T}, idToColorMap::Dict{Any,Any}) where T <: EMB.Resource
    hexColors::Vector{Any} = [haskey(idToColorMap,resource.id) ? idToColorMap[resource.id] : missingColor for resource ∈ resources]
    return [parse(Colorant, hex_color) for hex_color ∈ hexColors]
end

"""
    getResourceColors(resources::Vector{EMG.TransmissionMode}, idToColorMap::Dict{Any,Any})

Get the colors linked the the resources in `modes` (from Transmission.modes) based on the mapping `idToColorMap`
"""
function getResourceColors(modes::Vector{T}, idToColorMap::Dict{Any,Any}) where T <: EMG.TransmissionMode
    hexColors::Vector{Any} = [haskey(idToColorMap, mode.resource.id) ? idToColorMap[mode.resource.id] : missingColor for mode ∈ modes]
    return [parse(Colorant, hex_color) for hex_color ∈ hexColors]
end
            
"""
    getResourceColors(resources::Dict{EMB.Resource, Real}, idToColorMap::Dict{Any,Any})

Get the colors linked the the resources in `resources` based on the mapping `idToColorMap`
"""
function getResourceColors(resources::Dict{T, S}, idToColorMap::Dict{Any,Any}) where {T <: EMB.Resource, S <: Real}
    return getResourceColors(collect(keys(resources)), idToColorMap)
end

"""
    getResourceColors(resources::Vector{Any}, idToColorMap::Dict{Any,Any})

Return empty vector for empty input
"""
function getResourceColors(resources::Vector{Any}, idToColorMap::Dict{Any,Any})
    return Vector{RGB}(undef,0)
end
EMB.inputs(n::Availability, p::Resource) = 1
EMB.outputs(::Sink) = []
EMB.outputs(n::Availability, p::Resource) = 1
EMB.outputs(n::Sink, p::Resource) = nothing