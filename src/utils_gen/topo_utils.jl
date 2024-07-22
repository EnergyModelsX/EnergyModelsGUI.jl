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

    for child ∈ get_components(design)
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

Get the text alignment for a label attached to a wall.
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
    update_sub_system_locations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})

Update the coordinates of a subsystem of design based on the movement of EnergySystemDesign
`design`.
"""
function update_sub_system_locations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})
    for component ∈ get_components(design)
        get_xy(component)[] = get_xy(component)[] .+ Δ
    end
end

"""
    get_sector_points(;
        center::Tuple{Real,Real} = (0.0, 0.0),
        Δ::Real = 1.0,
        θ₁::Real = 0,
        θ₂::Real = π/4,
        steps::Int=200,
        geometry::Symbol = :circle)

Get points for the boundary of a sector defined by the center `c`, radius/halfsidelength `Δ`,
and angles `θ₁` and `θ₂` for a square (geometry = :rect), a circle (geometry = :circle), or a
triangle (geometry = :triangle).
"""
function get_sector_points(;
    c::Tuple{Real,Real}=(0.0, 0.0),
    Δ::Real=1.0,
    θ₁::Real=0.0,
    θ₂::Real=π / 4,
    steps::Int=200,
    geometry::Symbol=:circle,
)
    if geometry == :circle
        θ::Vector{Float64} = LinRange(θ₁, θ₂, Int(round(steps * (θ₂ - θ₁) / (2π))))
        x_coords::Vector{Float64} = Δ * cos.(θ) .+ c[1]
        y_coords::Vector{Float64} = Δ * sin.(θ) .+ c[2]

        # Include the center and close the polygon
        return [c; collect(zip(x_coords, y_coords)); c]
    elseif geometry == :rect
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
    elseif geometry == :triangle
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
        @error "Geometry $geometry is not implemented."
    end
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
