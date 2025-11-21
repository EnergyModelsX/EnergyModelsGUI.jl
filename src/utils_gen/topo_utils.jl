"""
    square_intersection(c::Point2f, x::Point2f, θ::Float32, Δ::Float32)

Calculate the intersection point between a line starting at `x` and direction described by
`θ`, and a square with half side lengths `Δ` centered at center `c`. If the line does not
intersect the square, the extension of the two facing sides to `x` will be used instead.
"""
function square_intersection(c::Point2f, x::Point2f, θ::Float32, Δ::Float32)
    # Direction vector from θ
    dx = cos(θ)
    dy = sin(θ)

    # Square bounds
    xmin, xmax = c[1] - Δ, c[1] + Δ
    ymin, ymax = c[2] - Δ, c[2] + Δ

    # Parametric line: X = x[1] + t*dx, Y = x[2] + t*dy
    ts = Float32[]
    ts_out = Float32[]

    # Check intersection with vertical sides (x = xmin and x = xmax)
    if abs(dx) > eps()
        t1 = (xmin - x[1]) / dx
        y1 = x[2] + t1 * dy
        if ymin <= y1 <= ymax
            push!(ts, t1)
        else
            push!(ts_out, t1)
        end
        t2 = (xmax - x[1]) / dx
        y2 = x[2] + t2 * dy
        if ymin <= y2 <= ymax
            push!(ts, t2)
        else
            push!(ts_out, t2)
        end
    end
    # Check intersection with horizontal sides (y = ymin and y = ymax)
    if abs(dy) > eps()
        t3 = (ymin - x[2]) / dy
        x3 = x[1] + t3 * dx
        if xmin <= x3 <= xmax
            push!(ts, t3)
        else
            push!(ts_out, t3)
        end
        t4 = (ymax - x[2]) / dy
        x4 = x[1] + t4 * dx
        if xmin <= x4 <= xmax
            push!(ts, t4)
        else
            push!(ts_out, t4)
        end
    end

    tmin = isempty(ts) ? minimum(abs.(ts_out)) : minimum(abs.(ts))

    return x + tmin * Point2f(dx, dy)
end

"""
    square_intersection(c::Point2f, θ::Float32, Δ::Float32)

Calculate the intersection point between a line starting at `c` and direction described
by `θ` and a square with half side lengths `Δ` centered at center `c`.
"""
function square_intersection(c::Point2f, θ::Float32, Δ::Float32)
    return square_intersection(c, c, θ, Δ)
end

"""
    l2_norm(x::Point2f)

Compute the l2-norm of a vector.
"""
function l2_norm(x::Point2f)
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
    design::EnergySystemDesign, min_x::Number, max_x::Number, min_y::Number, max_y::Number,
)
    if !isa(get_parent(get_system(design)), NothingElement)
        x, y = get_xy(design)[][1], get_xy(design)[][2]
        min_x = min(min_x, x)
        max_x = max(max_x, x)
        min_y = min(min_y, y)
        max_y = max(max_y, y)
    end

    for child ∈ get_components(design)
        min_x, max_x, min_y, max_y = find_min_max_coordinates(
            child, min_x, max_x, min_y, max_y,
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
    xy_1 = get_xy(node_1)[]
    xy_2 = get_xy(node_2)[]
    return atan(xy_2[2] - xy_1[2], xy_2[1] - xy_1[1])
end

"""
    angle_difference(angle1::Float32, angle2::Float32)

Compute the difference between two angles.
"""
function angle_difference(angle1::Float32, angle2::Float32)
    diff::Float32 = abs(angle1 - angle2) % Float32(2π)
    return min(diff, Float32(2π) - diff)
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
    function box(x::Float32, y::Float32, Δ::Float32)

Get the coordinates of a box with half side lengths `Δ` and centered at (`x`,`y`) starting
at the upper right corner.
"""
function box(x::Float32, y::Float32, Δ::Float32)
    xs::Vector{Float32} = [x + Δ, x - Δ, x - Δ, x + Δ, x + Δ]
    ys::Vector{Float32} = [y + Δ, y + Δ, y - Δ, y - Δ, y + Δ]

    return xs, ys
end

"""
    update_sub_system_locations!(design::EnergySystemDesign, Δ::Point2f)

Update the coordinates of a subsystem of design based on the movement of EnergySystemDesign
`design`.
"""
function update_sub_system_locations!(design::EnergySystemDesign, Δ::Point2f)
    for component ∈ get_components(design)
        get_xy(component)[] += Δ
    end
end

"""
    get_sector_points(;
        center::Point2f = Point2f(0.0f0, 0.0f0),
        Δ::Float32 = 1.0f0,
        θ₁::Float32 = 0.0f0,
        θ₂::Float32 = Float32(π / 4),
        steps::Int=200,
        geometry::Symbol = :circle)

Get points for the boundary of a sector defined by the center `c`, radius/halfsidelength `Δ`,
and angles `θ₁` and `θ₂` for a square (geometry = :rect), a circle (geometry = :circle), or a
triangle (geometry = :triangle).
"""
function get_sector_points(;
    c::Point2f = Point2f(0.0f0, 0.0f0),
    Δ::Float32 = 1.0f0,
    θ₁::Float32 = 0.0f0,
    θ₂::Float32 = Float32(π / 4),
    steps::Int = 200,
    geometry::Symbol = :circle,
)
    if geometry == :circle
        θ::Vector{Float32} = LinRange(θ₁, θ₂, Int(round(steps * (θ₂ - θ₁) / (2π))))
        x_coords::Vector{Float32} = Δ * cos.(θ) .+ c[1]
        y_coords::Vector{Float32} = Δ * sin.(θ) .+ c[2]

        # Include the center and close the polygon
        return Point2f[c, collect(zip(x_coords, y_coords))..., c]
    elseif geometry == :rect
        if θ₁ == 0 && θ₂ ≈ 2π
            x_coords, y_coords = box(c[1], c[2], Δ)
            return collect(zip(x_coords, y_coords))
        else
            xy1 = square_intersection(c, θ₁, Δ)
            xy2 = square_intersection(c, θ₂, Δ)
            vertices = Point2f[c, xy1]
            xsign = Float32[1, -1, -1, 1]
            ysign = Float32[1, 1, -1, -1]
            for (i, corner_angle) ∈ enumerate(Float32[π/4, 3π/4, 5π/4, 7π/4])
                if θ₁ < corner_angle && θ₂ > corner_angle
                    push!(vertices, c .+ (Δ * xsign[i], Δ * ysign[i]))
                end
            end
            push!(vertices, xy2)
            push!(vertices, c)
            return vertices
        end
    elseif geometry == :triangle
        input::Bool = (θ₁ + θ₂) / 2 > π / 2
        if input                      # input resources on a triangle to the left
            f = θ -> -2Δ * θ / π + 2Δ
        else                          # output resources on a triangle to the right
            f = θ -> 2Δ * θ / π
        end
        d::Float32 = Δ / 2
        x::Point2f = input ? c .- (d / 2, 0) : c .+ (d / 2, 0)
        x_side::Float32 = input ? -Δ : Δ
        xy1 = c .+ Point2f(x_side, f(θ₁))
        xy2 = c .+ Point2f(x_side, f(θ₂))
        return Point2f[x, xy1, xy2, x]
    else
        @error "Geometry $geometry is not implemented."
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
    end
end
