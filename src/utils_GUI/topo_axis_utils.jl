"""
    pixel_to_data(gui::GUI, pixel_size::Real)

Convert `pixel_size` to data widths (in x- and y-direction) in design object `gui`.
"""
function pixel_to_data(gui::GUI, pixel_size::Real)
    # Calculate the range in data coordinates
    vars = get_vars(gui)
    x_range::Float32 = vars[:xlimits][2] - vars[:xlimits][1]
    y_range::Float32 = vars[:ylimits][2] - vars[:ylimits][1]

    # Get the widths of the axis
    plot_widths::Vec2{Int64} = viewport(get_ax(gui, :topo).scene)[].widths

    # Calculate the conversion factor
    x_factor::Float32 = x_range / plot_widths[1]
    y_factor::Float32 = y_range / plot_widths[2]

    # Convert pixel size to data coordinates
    return Point2f(pixel_size * x_factor, pixel_size * y_factor)
end

"""
    update_distances!(gui::GUI)

Find the minimum distance between the elements in the design object `gui` and update `Δh` such
that neighbouring icons do not overlap.
"""
function update_distances!(gui::GUI)
    min_d::Float32 = Inf
    design = get_design(gui)
    components = get_components(design)
    if length(components) > 1
        for component ∈ components
            d::Float32 = minimum([
                l2_norm(collect(get_xy(component)[] .- get_xy(component2)[])) for
                component2 ∈ components if component != component2
            ])
            if d < min_d
                min_d = d
            end
        end
    end
    get_vars(gui)[:minimum_distance] = min_d
    return new_global_delta_h(gui)
end

"""
    new_global_delta_h(gui::GUI)

Recalculate the sizes of the boxes in `get_axes(gui)[:topo]` such that their size is independent
of zooming an resizing the window.
"""
function new_global_delta_h(gui::GUI)
    vars = get_vars(gui)
    axes = get_axes(gui)
    xyWidths::Vec = axes[:topo].finallimits[].widths
    plot_widths::Vec2{Int64} = viewport(axes[:topo].scene)[].widths
    min_distance_x = vars[:minimum_distance] / sqrt(2) # the minimum distance to avoid overlapping squares
    vars[:Δh][] = minimum([
        minimum(Vector(vars[:Δh_px] * xyWidths ./ plot_widths)),
        min_distance_x * 0.90f0, # separate the squares sufficiently
    ])
end

"""
    get_change(::GUI, ::Val)

Handle different keyboard inputs (events) and return changes in x, y coordinates in the
design object `gui`.
"""
get_change(::GUI, ::Val) = Point2f(0.0f0, 0.0f0)
get_change(gui::GUI, ::Val{Keyboard.up}) = Point2f(0.0f0, +get_var(gui, :Δh)[] / 5)
get_change(gui::GUI, ::Val{Keyboard.down}) = Point2f(0.0f0, -get_var(gui, :Δh)[] / 5)
get_change(gui::GUI, ::Val{Keyboard.left}) = Point2f(-get_var(gui, :Δh)[] / 5, 0.0f0)
get_change(gui::GUI, ::Val{Keyboard.right}) = Point2f(+get_var(gui, :Δh)[] / 5, 0.0f0)

"""
    align(gui::GUI, align::Symbol)

Align components in `get_selected_systems(gui)` based on the value of Symbol `align`.

The following values are allowed

- `:horizontal` for horizontal alignment.
- `:vertical` for vertical alignment.
"""
function align(gui::GUI, align::Symbol)
    xs::Vector{Float32} = Float32[]
    ys::Vector{Float32} = Float32[]
    for sub_design ∈ get_selected_systems(gui)
        if isa(sub_design, EnergySystemDesign)
            x, y = sub_design.xy[]
            push!(xs, x)
            push!(ys, y)
        end
    end

    # Use the average of the components as the basis of the translated coordinate
    z::Float32 = if align == :horizontal
        sum(ys) / length(ys)
    elseif align == :vertical
        sum(xs) / length(xs)
    end

    for sub_design ∈ get_selected_systems(gui)
        if isa(sub_design, EnergySystemDesign)
            x, y = sub_design.xy[]

            if align == :horizontal
                sub_design.xy[] = (x, z)
            elseif align == :vertical
                sub_design.xy[] = (z, y)
            end
        end
    end
end

"""
    initialize_plot!(gui::GUI, design::EnergySystemDesign)

Initialize the plot of the topology of design object `gui` given an EnergySystemDesign
`design`.
"""
function initialize_plot!(gui::GUI, design::EnergySystemDesign)
    for component ∈ get_components(design)
        initialize_plot!(gui, component)
        add_component!(gui, component)
    end
    return connect!(gui, design)
end

"""
    plot_design!(
        gui::GUI, design::EnergySystemDesign; visible::Bool=true, expand_all::Bool=true
    )

Plot the topology of get_design(gui) (only if not already available), and toggle visibility
based on the optional argument `visible`.
"""
function plot_design!(
    gui::GUI, design::EnergySystemDesign; visible::Bool = true, expand_all::Bool = true,
)
    for component ∈ get_components(design)
        component_visibility::Bool = (component == get_design(gui)) || expand_all
        plot_design!(gui, component; visible = component_visibility, expand_all)
    end
    if get_design(gui) == design
        update_distances!(gui)
    end
    for component ∈ get_components(design), plot ∈ get_plots(component)
        plot.visible = visible
    end
    for connection ∈ get_connections(design), plots ∈ get_plots(connection)
        if isa(plots, Makie.AbstractPlot) # handle the arrowheads (scatter! object)
            plots.visible = visible
        else # handle the lines (vector of line! objects)
            for plot_sub ∈ plots
                plot_sub.visible = visible
            end
        end
    end
end

"""
    connect!(gui::GUI, design::EnergySystemDesign)

Draws lines between connected nodes/areas in GUI `gui` using EnergySystemDesign `design`.
"""
function connect!(gui::GUI, design::EnergySystemDesign)
    connections = get_connections(design)

    for conn ∈ connections
        # Check if link between two elements goes in both directions (two_way)
        link = get_element(conn)
        two_way::Bool = false
        for conn2 ∈ connections
            link2 = get_element(conn2)
            if link2.to.id == link.from.id && link2.from.id == link.to.id
                two_way = true
            end
        end

        # Plot line for connection with decorations
        connect!(gui, conn, two_way)
    end
end

"""
    connect!(gui::GUI, connection::Connection, two_way::Bool)

When a boolean argument `two_way` is specified, draw the lines in both directions.
"""
function connect!(gui::GUI, connection::Connection, two_way::Bool)
    colors::Vector{RGB} = get_colors(connection)
    no_colors::Int64 = length(colors)

    # Create an arrow to highlight the direction of the energy flow
    l::Float32 = 1.0f0 # length of the arrow
    t::Float32 = 0.5f0 # half of the thickness of the arrow
    arrow_parts::Vector{Makie.BezierPath} = Vector{Makie.BezierPath}(undef, no_colors)
    for i ∈ range(1, no_colors)
        arrow_parts[i] = Makie.BezierPath([
            Makie.MoveTo(Makie.Point(0, 0)),
            Makie.LineTo(Makie.Point(-l, t * (2 * (i - 1) / no_colors - 1))),
            Makie.LineTo(Makie.Point(-l, t * (2 * i / no_colors - 1))),
            Makie.ClosePath(),
        ])
    end

    # Allocate and store objects
    linestyle = get_linestyle(gui, connection)
    linewidth = get_var(gui, :connection_linewidth)
    markersize = get_var(gui, :markersize)
    two_way_sep_px = get_var(gui, :two_way_sep_px)
    line_sep_px = get_var(gui, :line_sep_px)
    parent_scaling = get_var(gui, :parent_scaling)

    from_xy = connection.from.xy
    to_xy = connection.to.xy
    Δh = get_var(gui, :Δh)

    triple = @lift begin
        xy_midpoints = Vector{Point2f}(fill(Point2f(0.0f0, 0.0f0), no_colors))
        θs = Vector{Float32}(fill(0.0f0, no_colors))
        pts_lines =
            Vector{Vector{Point2f}}(fill(fill(Point2f(0.0f0, 0.0f0), 2), no_colors))
        for j ∈ 1:no_colors
            lines_shift::Point2f =
                pixel_to_data(gui, linewidth) .+
                pixel_to_data(gui, line_sep_px)
            two_way_sep::Point2f = pixel_to_data(gui, two_way_sep_px)
            markersize_lengths::Point2f = pixel_to_data(gui, markersize)

            xy_1::Point2f = $from_xy
            xy_2::Point2f = $to_xy

            θ::Float32 = atan(xy_2[2] - xy_1[2], xy_2[1] - xy_1[1])
            cosθ::Float32 = cos(θ)
            sinθ::Float32 = sin(θ)
            cosϕ::Float32 = -sinθ # where ϕ = θ+π/2
            sinϕ::Float32 = cosθ

            # Create directional vectors in the direction of θ and ϕ
            dirϕ::Point2f = Point2f(cosϕ, sinϕ)
            dirθ::Point2f = Point2f(cosθ, sinθ)

            Δ::Float32 = $Δh / 2 # half width of a box
            if !isempty(get_components(connection.from))
                Δ *= parent_scaling
            end

            xy_start::Point2f = xy_1 + (j - 1) * lines_shift .* dirϕ
            xy_end::Point2f = xy_2 + (j - 1) * lines_shift .* dirϕ
            xy_midpoint::Point2f = xy_2 + (no_colors - 1) / 2 * lines_shift .* dirϕ # The midpoint of the end of all lines (for arrow head)

            if two_way # separate the opposite directed lines by two_way_sep
                xy_start += two_way_sep / 2 .* dirϕ
                xy_end += two_way_sep / 2 .* dirϕ
                xy_midpoint += two_way_sep / 2 .* dirϕ
            end
            xy_start = square_intersection(xy_1, xy_start, θ, Δ)
            xy_end = square_intersection(xy_2, xy_end, θ + π, Δ)
            xy_midpoint = square_intersection(xy_2, xy_midpoint, θ + π, Δ)
            parm::Float32 =
                -xy_start[1] * cosθ - xy_start[2] * sinθ +
                xy_midpoint[1] * cosθ +
                xy_midpoint[2] * sinθ - minimum(markersize_lengths)

            xy_midpoints[j] = xy_midpoint
            θs[j] = θ
            pts_lines[j] = Point2f[xy_start, parm*dirθ+xy_start]
        end

        # return the objects into a tuple Observable
        (xy_midpoints, θs, pts_lines)
    end

    # Extract observables from the tuple
    xy_midpoints = @lift $triple[1]
    θs = @lift $triple[2]

    ax = get_ax(gui, :topo)
    sctr = scatter!(
        ax,
        xy_midpoints;
        marker = arrow_parts,
        markersize = get_var(gui, :markersize),
        rotation = θs,
        color = colors,
        inspectable = false,
    )
    Makie.translate!(sctr, 0, 0, get_var(gui, :z_translate_lines))
    sctr.kw[:EMGUI_obj] = connection
    push!(get_plots(connection), sctr)

    lns_arr::Vector{Makie.AbstractPlot} = Makie.AbstractPlot[] # to store the line plots

    for j ∈ 1:no_colors
        pts_lines = @lift $triple[3][j]
        lns = lines!(
            ax,
            pts_lines;
            color = colors[j],
            linewidth = linewidth,
            linestyle = linestyle[j],
            inspector_label = (self, i, p) -> get_hover_string(connection),
            inspectable = true,
        )
        Makie.translate!(lns, 0, 0, get_var(gui, :z_translate_lines))
        lns.kw[:EMGUI_obj] = connection
        push!(lns_arr, lns)
    end
    push!(get_plots(connection), lns_arr)

    get_vars(gui)[:z_translate_lines] += 0.0001f0
end

"""
    add_component!(gui::GUI, component::EnergySystemDesign)

Draw a box containing the icon and add a label with the id of the EnergySystemDesign
`component` with its type in parantheses.
"""
function add_component!(gui::GUI, component::EnergySystemDesign)
    draw_box!(gui, component)
    draw_icon!(gui, component)
    return draw_label!(gui, component)
end

"""
    get_linestyle(gui::GUI, design::EnergySystemDesign)

Get the line style for an EnergySystemDesign `design` based on its properties.
"""
get_linestyle(gui::GUI, design::EnergySystemDesign) = get_linestyle(gui, design.system)
function get_linestyle(gui::GUI, system::AbstractSystem)
    node = get_parent(system)
    if isa(node, EMB.Node) && EMI.has_investment(node)
        return get_var(gui, :investment_lineStyle)
    end
    return :solid
end

"""
    get_linestyle(gui::GUI, connection::Connection)

Get the line style for an Connection `connection` based on its properties.
"""
function get_linestyle(gui::GUI, connection::Connection)
    # Check if connection is a transmission
    linestyles = get_linestyle(gui, get_element(connection))
    if !isempty(linestyles)
        return linestyles
    end

    # For Links, simply use dashed style if from or to node has investments
    no_lines = length(get_colors(connection))
    linestyle::Union{Symbol,Makie.Linestyle} = get_linestyle(gui, connection.from)
    if linestyle == get_var(gui, :investment_lineStyle)
        return fill(linestyle, no_lines)
    end
    linestyle = get_linestyle(gui, connection.to)
    if linestyle == get_var(gui, :investment_lineStyle)
        return fill(linestyle, no_lines)
    end
    return fill(:solid, no_lines)
end

"""
    get_linestyle(::GUI, ::AbstractElement)

Dispatchable function for the EnergyModelsGeography extension.
"""
function get_linestyle(::GUI, ::AbstractElement)
    return []
end

"""
    draw_box!(gui::GUI, design::EnergySystemDesign)

Draw a box for EnergySystemDesign `design` and it's appearance, including style, color, size.
"""
function draw_box!(gui::GUI, design::EnergySystemDesign)
    linestyle::Union{Symbol,Makie.Linestyle} = get_linestyle(gui, design)

    Δh = get_var(gui, :Δh)
    xy = design.xy

    # if the design has components, draw an enlarged box around it.
    if !isempty(get_components(design))
        # Build the rectangle path from the observables
        rect = @lift begin
            Δ = $Δh * get_var(gui, :parent_scaling)
            Rect2f($xy .- Point2f(Δ/2, Δ/2), Point2f(Δ, Δ))
        end

        white_rect2 = poly!(
            get_axes(gui)[:topo],
            rect;
            color = WHITE,
            inspectable = true,
            strokewidth = get_var(gui, :linewidth),
            strokecolor = design.color,
            linestyle = linestyle,
        ) # Create a white background rectangle to hide lines from connections

        add_inspector_to_poly!(white_rect2, (self, i, p) -> get_hover_string(design))
        Makie.translate!(white_rect2, 0.0f0, 0.0f0, get_var(gui, :z_translate_components))
        get_vars(gui)[:z_translate_components] += 0.0001f0
        push!(design.plots, white_rect2)
        white_rect2.kw[:EMGUI_obj] = design
    end

    # Build the rectangle path from the observables
    rect = @lift Rect2f($xy .- Point2f($Δh/2, $Δh/2), Point2f($Δh, $Δh))

    white_rect = poly!(
        get_axes(gui)[:topo],
        rect;
        color = WHITE,
        inspectable = true,
        strokewidth = get_var(gui, :linewidth),
        strokecolor = design.color,
        linestyle = linestyle,
    ) # Create a white background rectangle to hide lines from connections

    add_inspector_to_poly!(white_rect, (self, i, p) -> get_hover_string(design))
    Makie.translate!(white_rect, 0.0f0, 0.0f0, get_var(gui, :z_translate_components))
    get_vars(gui)[:z_translate_components] += 0.0001f0

    push!(design.plots, white_rect)
    white_rect.kw[:EMGUI_obj] = design
end

"""
    draw_icon!(gui::GUI, design::EnergySystemDesign)

Draw an icon for EnergySystemDesign `design`.
"""
function draw_icon!(gui::GUI, design::EnergySystemDesign)
    ax = get_axes(gui)[:topo]
    if isempty(design.icon) # No path to an icon has been found
        node::EMB.Node = get_ref_element(design)

        colors_input::Vector{RGBA{Float32}} = get_resource_colors(
            inputs(node), design.id_to_color_map,
        )
        colors_output::Vector{RGBA{Float32}} = get_resource_colors(
            outputs(node), design.id_to_color_map,
        )
        all_colors = vcat(colors_input, colors_output)
        no_circle_points::Int64 = 100
        geometry::Symbol, no_points::Int64 = if isa(node, Source)
            (:rect, 5)
        elseif isa(node, Sink)
            (:circle, no_circle_points+2)
        else # assume NetworkNode
            (:triangle, 4)
        end

        no_polygons::Int64 = length(all_colors)
        xy = design.xy
        Δh = get_var(gui, :Δh)
        icon_scale = get_var(gui, :icon_scale)
        node_isa_networknode::Bool = isa(node, NetworkNode)

        poly_points_obs::Observable{Vector{Vector{Point2f}}} = @lift begin
            poly_points::Vector{Vector{Point2f}} = Vector{Vector{Point2f}}(
                fill(fill(Point2f(0, 0), no_points), no_polygons),
            )
            idx = 1
            for (j, colors) ∈ enumerate([colors_input, colors_output])
                no_colors::Int64 = length(colors)
                for i ∈ 1:no_colors
                    θᵢ::Float32 = 0.0f0
                    θᵢ₊₁::Float32 = 0.0f0

                    # Check if node is a NetworkNode (if so, devide disc into two where
                    # left side is for input and right side is for output)
                    if node_isa_networknode
                        θᵢ = (-1)^(j + 1) * π / 2 + π * (i - 1) / no_colors
                        θᵢ₊₁ = (-1)^(j + 1) * π / 2 + π * i / no_colors
                    else
                        θᵢ = 2π * (i - 1) / no_colors
                        θᵢ₊₁ = 2π * i / no_colors
                    end
                    poly_points[idx] = get_sector_points(;
                        c = $xy,
                        Δ = $Δh * icon_scale / 2,
                        θ₁ = θᵢ,
                        θ₂ = θᵢ₊₁,
                        geometry = geometry,
                        steps = no_circle_points,
                    )
                    idx += 1
                end
            end
            poly_points
        end

        polys = poly!(ax, poly_points_obs; color = all_colors, inspectable = true)
        add_inspector_to_poly!(polys, (self, i, p) -> get_hover_string(design))
        Makie.translate!(
            polys,
            0.0f0,
            0.0f0,
            get_var(gui, :z_translate_components),
        )
        polys.kw[:EMGUI_obj] = design
        push!(design.plots, polys)

        if node_isa_networknode
            # Add a center box to separate input resources from output resources
            Δh = get_var(gui, :Δh)
            xy = design.xy

            box = @lift begin
                Δ = $Δh * get_var(gui, :icon_scale) / 4
                Rect2f($xy .- Point2f(Δ, Δ)/2, Point2f(Δ, Δ))
            end

            center_box = poly!(
                ax,
                box;
                color = WHITE,
                inspectable = true,
                strokewidth = get_var(gui, :linewidth),
            )

            add_inspector_to_poly!(
                center_box, (self, i, p) -> get_hover_string(design),
            )

            Makie.translate!(
                center_box,
                0.0f0,
                0.0f0,
                get_var(gui, :z_translate_components),
            )
            center_box.kw[:EMGUI_obj] = design
            push!(design.plots, center_box)
        end
    else
        Δh = get_var(gui, :Δh)
        xy = design.xy
        scale = get_var(gui, :icon_scale)
        xo_image = @lift ($xy[1] - $Δh * scale / 2) .. ($xy[1] + $Δh * scale / 2)
        yo_image = @lift ($xy[2] - $Δh * scale / 2) .. ($xy[2] + $Δh * scale / 2)

        icon_image = image!(
            ax,
            xo_image,
            yo_image,
            rotr90(FileIO.load(design.icon));
            inspectable = true,
            inspector_label = (self, i, p) -> get_hover_string(design),
        )
        Makie.translate!(icon_image, 0.0f0, 0.0f0, get_var(gui, :z_translate_components))
        icon_image.kw[:EMGUI_obj] = design
        push!(design.plots, icon_image)
    end
    get_vars(gui)[:z_translate_components] += 0.0001f0
end

"""
    draw_label!(gui::GUI, component::EnergySystemDesign)

Add a label to an `EnergySystemDesign` component.
"""
function draw_label!(gui::GUI, component::EnergySystemDesign)
    connections = get_connections(get_parent(component))
    id = get_parent(get_system(component)).id
    linked_to_component::Vector{Connection} = filter(
        x -> id == get_element(x).to.id,
        connections,
    )
    linked_from_component::Vector{Connection} = filter(
        x -> id == get_element(x).from.id,
        connections,
    )

    scale = 0.7
    Δh = get_var(gui, :Δh)
    xy = component.xy
    walls::Vector{Symbol} = [:E, :N, :W, :S]

    # Find optimal placement of label by finding the wall that has the least number of connections
    tuple = @lift begin
        angles::Vector{Float32} = vcat(
            [
                angle(component, linked_component.from) for
                linked_component ∈ linked_to_component
            ],
            [
                angle(component, linked_component.to) for
                linked_component ∈ linked_from_component
            ],
        )
        min_angle_diff::Vector{Float32} = fill(Inf, 4)
        for i ∈ eachindex(min_angle_diff)
            for angle ∈ angles
                Δθ::Float32 = angle_difference(angle, (i - 1) * Float32(π) / 2)
                if min_angle_diff[i] > Δθ
                    min_angle_diff[i] = Δθ
                end
            end
        end
        wall = walls[argmax(min_angle_diff)]
        shift_xy = if wall == :E
            Point2f($Δh * scale, 0.0f0)
        elseif wall == :S
            Point2f(0.0f0, -$Δh * scale)
        elseif wall == :W
            Point2f(-$Δh * scale, 0.0f0)
        elseif wall == :N
            Point2f(0.0f0, $Δh * scale)
        end
        xy_label = $xy + shift_xy
        alignment = get_text_alignment(wall)
        (xy_label, alignment)
    end

    # Extract observables from the tuple
    xy_label_obs = @lift $tuple[1]
    alignment_obs = @lift $tuple[2]

    node = get_element(component)

    label_text = text!(
        get_axes(gui)[:topo],
        xy_label_obs;
        text = get_element_label(node),
        align = alignment_obs,
        fontsize = get_var(gui, :fontsize),
        inspectable = false,
        color = has_invested(component) ? RED : BLACK,
    )
    Makie.translate!(label_text, 0.0f0, 0.0f0, get_var(gui, :z_translate_components))
    get_vars(gui)[:z_translate_components] += 0.0001f0
    label_text.kw[:EMGUI_obj] = component
    push!(get_plots(component), label_text)
end

"""
    get_element_label(element)

Get the label of the element based on its `id` field. If the `id` is a number it returns the
built in Base.display() functionality of node, otherwise, the `id` field is converted to a string.
"""
function get_element_label(element::AbstractGUIObj)
    return get_element_label(get_element(element))
end
function get_element_label(element::EMB.Node)
    return isa(element.id, Number) ? string(element) : string(element.id)
end
function get_element_label(element::EMB.Link)
    return get_element_label(element.from) * "-" * get_element_label(element.to)
end

"""
    adjust_limits!(gui::GUI)

Adjust the limits of get_axes(gui)[:topo] based on its content.
"""
function adjust_limits!(gui::GUI)
    vars = get_vars(gui)
    min_x, max_x, min_y, max_y = find_min_max_coordinates(get_design(gui))
    Δ_lim_x = max_x - min_x
    Δ_lim_y = max_y - min_y
    boundary_add = vars[:boundary_add]
    min_x -= Δ_lim_x * boundary_add
    max_x += Δ_lim_x * boundary_add
    min_y -= Δ_lim_y * boundary_add
    max_y += Δ_lim_y * boundary_add
    Δ_lim_x = max_x - min_x
    Δ_lim_y = max_y - min_y
    x_center = (min_x + max_x) / 2
    y_center = (min_y + max_y) / 2
    if Δ_lim_y > Δ_lim_x
        Δ_lim_x = Δ_lim_y * vars[:ax_aspect_ratio]
    else
        Δ_lim_y = Δ_lim_x / vars[:ax_aspect_ratio]
    end
    min_x = x_center - Δ_lim_x / 2
    max_x = x_center + Δ_lim_x / 2
    min_y = y_center - Δ_lim_y / 2
    max_y = y_center + Δ_lim_y / 2
    if min_x ≈ max_x
        min_x -= boundary_add
        max_x += boundary_add
    end
    if min_y ≈ max_y
        min_y -= boundary_add
        max_y += boundary_add
    end
    vars[:xlimits] = [min_x, max_x]
    vars[:ylimits] = [min_y, max_y]
    ax = get_ax(gui, :topo)
    limits!(ax, vars[:xlimits], vars[:ylimits])
end

"""
    update_title!(gui::GUI)

Update the title of `get_axes(gui)[:topo]` based on `get_design(gui)`.
"""
function update_title!(gui::GUI)
    parent = get_parent(get_system(gui))
    title_obs = get_var(gui, :title)
    title_obs[] = if isa(parent, NothingElement)
        "top_level"
    else
        "top_level.$(parent)"
    end
end

"""
    get_hover_string(obj::AbstractGUIObj)

Return the string for a EMB.Node/Area/Link/Transmission to be shown on hovering.
"""
function get_hover_string(obj::AbstractGUIObj)
    element = get_element(obj)
    label = get_element_label(element)
    inv_times = get_inv_times(obj)
    inv_str = "$label ($(nameof(typeof(element))))"
    if !isempty(inv_times)
        capex = get_capex(obj)
        label = get_element_label(obj)
        for (t, capex) ∈ zip(inv_times, capex)
            inv_str *= "\n\t$t: $(format_number(capex))"
        end
    end
    return inv_str
end
