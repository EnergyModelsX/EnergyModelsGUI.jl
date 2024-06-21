"""
    pixel_to_data(gui::GUI, pixel_size::Real)

Convert `pixel_size` to data widths (in x- and y-direction) in design object `gui`.
"""
function pixel_to_data(gui::GUI, pixel_size::Real)
    # Calculate the range in data coordinates
    x_range::Float64 = gui.vars[:xlimits][2] - gui.vars[:xlimits][1]
    y_range::Float64 = gui.vars[:ylimits][2] - gui.vars[:ylimits][1]

    # Get the widths of the axis
    plot_widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths

    # Calculate the conversion factor
    x_factor::Float64 = x_range / plot_widths[1]
    y_factor::Float64 = y_range / plot_widths[2]

    # Convert pixel size to data coordinates
    return (pixel_size * x_factor, pixel_size * y_factor)
end

"""
    update_distances!(gui::GUI)

Find the minimum distance between the nodes in the design object `gui` and update `Δh` such
that neighbouring icons do not overlap.
"""
function update_distances!(gui::GUI)
    min_d::Float64 = Inf
    for component ∈ gui.design.components
        if length(gui.design.components) > 1
            d::Float64 = minimum([
                norm(collect(component.xy[] .- component2.xy[])) for
                component2 ∈ gui.design.components if component != component2
            ])
            if d < min_d
                min_d = d
            end
        end
    end
    gui.vars[:minimum_distance] = min_d
    return new_global_delta_h(gui)
end

"""
    new_global_delta_h(gui::GUI)

Recalculate the sizes of the boxes in `gui.axes[:topo]` such that their size is independent
of zooming an resizing the window.
"""
function new_global_delta_h(gui::GUI)
    xyWidths::Vec{2,Float32} = gui.axes[:topo].finallimits[].widths
    plot_widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
    #gui.vars[:Δh][] = minimum(Vector(gui.vars[:Δh_px] * xyWidths ./ plot_widths))
    gui.vars[:Δh][] = maximum([
        maximum(Vector(0.5 * gui.vars[:Δh_px] * xyWidths ./ plot_widths)),
        minimum([
            minimum(Vector(gui.vars[:Δh_px] * xyWidths ./ plot_widths)),
            gui.vars[:minimum_distance] / 2, # Do this to avoid overlapping squares
        ]),
    ])
end

"""
    get_change(::GUI, ::Val)

Handle different keyboard inputs (events) and return changes in x, y coordinates in the
design object `gui`.
"""
get_change(::GUI, ::Val) = (0.0, 0.0)
get_change(gui::GUI, ::Val{Keyboard.up}) = (0.0, +gui.vars[:Δh][] / 5)
get_change(gui::GUI, ::Val{Keyboard.down}) = (0.0, -gui.vars[:Δh][] / 5)
get_change(gui::GUI, ::Val{Keyboard.left}) = (-gui.vars[:Δh][] / 5, 0.0)
get_change(gui::GUI, ::Val{Keyboard.right}) = (+gui.vars[:Δh][] / 5, 0.0)

"""
    align(gui::GUI, align::Symbol)

Align components in `gui.vars[:selected_systems]` based on the value of Symbol `align`.

The following values are allowed

- `:horizontal` for horizontal alignment.
- `:vertical` for vertical alignment.
"""
function align(gui::GUI, align::Symbol)
    xs::Vector{Real} = Real[]
    ys::Vector{Real} = Real[]
    for sub_design ∈ gui.vars[:selected_systems]
        if isa(sub_design, EnergySystemDesign)
            x, y = sub_design.xy[]
            push!(xs, x)
            push!(ys, y)
        end
    end

    # Use the average of the components as the basis of the translated coordinate
    z::Real = if align == :horizontal
        sum(ys) / length(ys)
    elseif align == :vertical
        sum(xs) / length(xs)
    end

    for sub_design ∈ gui.vars[:selected_systems]
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
    for component ∈ design.components
        initialize_plot!(gui, component)
        add_component!(gui, component)
    end
    return connect!(gui, design)
end

"""
    plot_design!(
        gui::GUI, design::EnergySystemDesign; visible::Bool=true, expand_all::Bool=true
    )

Plot the topology of gui.design (only if not already available), and toggle visibility
based on the optional argument `visible`.
"""
function plot_design!(
    gui::GUI, design::EnergySystemDesign; visible::Bool=true, expand_all::Bool=true
)
    for component ∈ design.components
        component_visibility::Bool = (component == gui.design) || expand_all
        plot_design!(gui, component; visible=component_visibility, expand_all)
    end
    if gui.design == design
        update_distances!(gui)
    end
    for component ∈ design.components, plot ∈ component.plots
        plot.visible = visible
    end
    for connection ∈ design.connections, plots ∈ connection.plots, plot ∈ plots[]
        plot.visible = visible
    end
end

"""
    connect!(gui::GUI, design::EnergySystemDesign)

Draws lines between connected nodes/areas in GUI `gui` using EnergySystemDesign `design`.
"""
function connect!(gui::GUI, design::EnergySystemDesign)
    # Find optimal placement of label by finding the wall that has the least number of connections
    for component ∈ design.components
        linked_to_component::Vector{Connection} = filter(
            x -> component.system[:node].id == x.connection.to.id, design.connections
        )
        linked_from_component::Vector{Connection} = filter(
            x -> component.system[:node].id == x.connection.from.id, design.connections
        )
        on(component.xy; priority=4) do _
            angles::Vector{Float64} = vcat(
                [
                    angle(component, linked_component.from) for
                    linked_component ∈ linked_to_component
                ],
                [
                    angle(component, linked_component.to) for
                    linked_component ∈ linked_from_component
                ],
            )
            min_angle_diff::Vector{Float64} = fill(Inf, 4)
            for i ∈ eachindex(min_angle_diff)
                for angle ∈ angles
                    Δθ = angle_difference(angle, (i - 1) * π / 2)
                    if min_angle_diff[i] > Δθ
                        min_angle_diff[i] = Δθ
                    end
                end
            end
            walls::Vector{Symbol} = [:E, :N, :W, :S]
            component.wall[] = walls[argmax(min_angle_diff)]
        end
        notify(component.xy)
    end

    for connection ∈ design.connections
        # Check if link between two nodes goes in both directions (two_way)
        connection_con = connection.connection
        two_way::Bool = false
        for connection2 ∈ design.connections
            connection2_con = connection2.connection
            if connection2_con.to.id == connection_con.from.id &&
                connection2_con.from.id == connection_con.to.id
                two_way = true
            end
        end

        # Plot line for connection with decorations
        connect!(gui, connection, two_way)
    end
end

"""
    connect!(gui::GUI, connection::Connection, two_way::Bool)

When a boolean argument `two_way` is specified, draw the lines in both directions.
"""
function connect!(gui::GUI, connection::Connection, two_way::Bool)
    colors::Vector{RGB} = connection.colors
    no_colors::Int64 = length(colors)

    # Create an arrow to highlight the direction of the energy flow
    l::Float64 = 1.0 # length of the arrow
    t::Float64 = 0.5 # half of the thickness of the arrow
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
    line_connections::Observable{Vector{Any}} = Observable(Vector{Any}(undef, 0))
    arrow_heads::Observable{Vector{Any}} = Observable(Vector{Any}(undef, 0))
    push!(connection.plots, line_connections)
    push!(connection.plots, arrow_heads)
    linestyle = get_linestyle(gui, connection)

    # Create function to be run on changes in connection.from and connection.to
    update =
        () -> begin
            markersize_lengths::Tuple{Float64,Float64} = pixel_to_data(
                gui, gui.vars[:markersize]
            )
            xy_1::Vector{Real} = collect(connection.from.xy[])
            xy_2::Vector{Real} = collect(connection.to.xy[])

            for i ∈ 1:length(line_connections[])
                line_connections[][i].visible = false
            end
            for i ∈ 1:length(arrow_heads[])
                arrow_heads[][i].visible = false
            end

            lines_shift::Tuple{Float64,Float64} =
                pixel_to_data(gui, gui.vars[:connection_linewidth]) .+
                pixel_to_data(gui, gui.vars[:line_sep_px])
            two_way_sep::Tuple{Float64,Float64} = pixel_to_data(
                gui, gui.vars[:two_way_sep_px][]
            )
            θ::Float64 = atan(xy_2[2] - xy_1[2], xy_2[1] - xy_1[1])
            cosθ::Float64 = cos(θ)
            sinθ::Float64 = sin(θ)
            cosϕ::Float64 = -sinθ # where ϕ = θ+π/2
            sinϕ::Float64 = cosθ

            Δ::Float64 = gui.vars[:Δh][] / 2 # half width of a box
            if !isempty(connection.from.components)
                Δ *= gui.vars[:parent_scaling]
            end

            for j ∈ 1:no_colors
                xy_start::Vector{Float64} = copy(xy_1)
                xy_end::Vector{Float64} = copy(xy_2)
                xy_midpoint::Vector{Float64} = copy(xy_2) # The midpoint of the end of all lines (for arrow head)
                if two_way
                    xy_start[1] += (two_way_sep[1] / 2 + lines_shift[1] * (j - 1)) * cosϕ
                    xy_start[2] +=
                        (two_way_sep[2] / 2 + lines_shift[2] * (j - 1)) * sinϕ
                    xy_end[1] += (two_way_sep[1] / 2 + lines_shift[1] * (j - 1)) * cosϕ
                    xy_end[2] += (two_way_sep[2] / 2 + lines_shift[2] * (j - 1)) * sinϕ
                    xy_midpoint[1] +=
                        (two_way_sep[1] / 2 + lines_shift[1] * (no_colors - 1) / 2) * cosϕ
                    xy_midpoint[2] +=
                        (two_way_sep[2] / 2 + lines_shift[2] * (no_colors - 1) / 2) * sinϕ
                else
                    xy_start[1] += lines_shift[1] * (j - 1) * cosϕ
                    xy_start[2] += lines_shift[2] * (j - 1) * sinϕ
                    xy_end[1] += lines_shift[1] * (j - 1) * cosϕ
                    xy_end[2] += lines_shift[2] * (j - 1) * sinϕ
                    xy_midpoint[1] += lines_shift[1] * (no_colors - 1) / 2 * cosϕ
                    xy_midpoint[2] += lines_shift[2] * (no_colors - 1) / 2 * sinϕ
                end
                xy_start = square_intersection(xy_1, xy_start, θ, Δ)
                xy_end = square_intersection(xy_2, xy_end, θ + π, Δ)
                xy_midpoint = square_intersection(xy_2, xy_midpoint, θ + π, Δ)
                parm::Float64 =
                    -xy_start[1] * cosθ - xy_start[2] * sinθ +
                    xy_midpoint[1] * cosθ +
                    xy_midpoint[2] * sinθ - minimum(markersize_lengths)
                xs::Vector{Float64} = [xy_start[1], parm * cosθ + xy_start[1]]
                ys::Vector{Float64} = [xy_start[2], parm * sinθ + xy_start[2]]

                if length(arrow_heads[]) < j
                    sctr = scatter!(
                        gui.axes[:topo],
                        xy_midpoint[1],
                        xy_midpoint[2];
                        marker=arrow_parts[j],
                        markersize=gui.vars[:markersize],
                        rotations=θ,
                        color=colors[j],
                        inspectable=false,
                    )
                    lns = lines!(
                        gui.axes[:topo],
                        xs,
                        ys;
                        color=colors[j],
                        linewidth=gui.vars[:connection_linewidth],
                        linestyle=linestyle,
                        inspector_label=(self, i, p) ->
                            get_hover_string(connection.connection),
                        inspectable=true,
                    )
                    Makie.translate!(sctr, 0, 0, gui.vars[:z_translate_lines])
                    gui.vars[:z_translate_lines] += 1
                    Makie.translate!(lns, 0, 0, gui.vars[:z_translate_lines])
                    gui.vars[:z_translate_lines] += 1
                    push!(arrow_heads[], sctr)
                    push!(line_connections[], lns)
                else
                    arrow_heads[][j][1][] = [Point{2,Float32}(xy_midpoint[1], xy_midpoint[2])]
                    arrow_heads[][j][:rotations] = θ
                    arrow_heads[][j].visible = true
                    line_connections[][j][1][] = [
                        Point{2,Float32}(x, y) for (x, y) ∈ zip(xs, ys)
                    ]
                    line_connections[][j].visible = true
                end
            end
        end

    # If components changes position, so must the connections
    for component ∈ [connection.from, connection.to]
        on(component.xy; priority=3) do _
            if component.plots[1].visible[]
                update()
            end
        end
    end
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
function get_linestyle(gui::GUI, system::Dict)
    if haskey(system, :node)
        if EMI.has_investment(system[:node])
            return gui.vars[:investment_lineStyle]
        end
    end
    return :solid
end

"""
    get_linestyle(gui::GUI, connection::Connection)

Get the line style for an Connection `connection` based on its properties.
"""
function get_linestyle(gui::GUI, connection::Connection)
    # Check of connection is a transmission
    t = connection.connection
    if isa(t, EMG.Transmission)
        if EMI.has_investment(t)
            return gui.vars[:investment_lineStyle]
        else
            return :solid
        end
    end

    # For Links, simply use dashed style if from or to node has investments
    linestyle::Union{Symbol,Makie.Linestyle} = get_linestyle(gui, connection.from)
    if linestyle == gui.vars[:investment_lineStyle]
        return linestyle
    end
    linestyle = get_linestyle(gui, connection.to)
    if linestyle == gui.vars[:investment_lineStyle]
        return linestyle
    end
    return :solid
end

"""
    draw_box!(gui::GUI, design::EnergySystemDesign)

Draw a box for EnergySystemDesign `design` and it's appearance, including style, color, size.
"""
function draw_box!(gui::GUI, design::EnergySystemDesign)
    linestyle::Union{Symbol,Makie.Linestyle} = get_linestyle(gui, design)

    # if the design has components, draw an enlarged box around it.
    if !isempty(design.components)
        xo2::Observable{Vector{Real}} = Observable(zeros(5))
        yo2::Observable{Vector{Real}} = Observable(zeros(5))
        vertices2::Vector{Tuple{Real,Real}} = [
            (x, y) for (x, y) ∈ zip(xo2[][1:(end - 1)], yo2[][1:(end - 1)])
        ]

        white_rect2 = poly!(
            gui.axes[:topo], vertices2; color=:white, strokewidth=0, inspectable=false
        ) # Create a white background rectangle to hide lines from connections
        add_inspector_to_poly!(
            white_rect2, (self, i, p) -> get_hover_string(design.system[:node])
        )
        Makie.translate!(white_rect2, 0, 0, gui.vars[:z_translate_components])
        gui.vars[:z_translate_components] += 1
        push!(design.plots, white_rect2)

        # observe changes in design coordinates and update enlarged box position
        on(design.xy; priority=3) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, gui.vars[:Δh][] / 2 * gui.vars[:parent_scaling])
            white_rect2[1] = [
                (x, y) for (x, y) ∈ zip(xo2[][1:(end - 1)], yo2[][1:(end - 1)])
            ]
        end

        box_boundary2 = lines!(
            gui.axes[:topo],
            xo2,
            yo2;
            color=design.color,
            linewidth=gui.vars[:linewidth],
            linestyle=:solid,
            inspectable=false,
        )
        Makie.translate!(box_boundary2, 0, 0, gui.vars[:z_translate_components])
        gui.vars[:z_translate_components] += 1
        push!(design.plots, box_boundary2)
    end

    xo::Observable{Vector{Real}} = Observable(zeros(5))
    yo::Observable{Vector{Real}} = Observable(zeros(5))
    vertices::Vector{Tuple{Real,Real}} = [
        (x, y) for (x, y) ∈ zip(xo[][1:(end - 1)], yo[][1:(end - 1)])
    ]
    white_rect = Observable(Makie.GeometryBasics.HyperRectangle{2,Int64})

    white_rect = poly!(
        gui.axes[:topo], vertices; color=:white, strokewidth=0, inspectable=false
    ) # Create a white background rectangle to hide lines from connections
    add_inspector_to_poly!(
        white_rect, (self, i, p) -> get_hover_string(design.system[:node])
    )
    Makie.translate!(white_rect, 0, 0, gui.vars[:z_translate_components])
    gui.vars[:z_translate_components] += 1

    push!(design.plots, white_rect)

    # Observe changes in design coordinates and update box position
    on(design.xy; priority=3) do val
        x::Real = val[1]
        y::Real = val[2]

        xo[], yo[] = box(x, y, gui.vars[:Δh][] / 2)
        white_rect[1] = [(x, y) for (x, y) ∈ zip(xo[][1:(end - 1)], yo[][1:(end - 1)])]
    end

    box_boundary = lines!(
        gui.axes[:topo],
        xo,
        yo;
        color=design.color,
        linewidth=gui.vars[:linewidth],
        linestyle=linestyle,
        inspectable=false,
    )
    Makie.translate!(box_boundary, 0, 0, gui.vars[:z_translate_components])
    gui.vars[:z_translate_components] += 1
    return push!(design.plots, box_boundary)
end

"""
    draw_icon!(gui::GUI, design::EnergySystemDesign)

Draw an icon for EnergySystemDesign `design`.
"""
function draw_icon!(gui::GUI, design::EnergySystemDesign)
    xo::Observable{Vector{Real}} = Observable([0.0, 0.0])
    yo::Observable{Vector{Real}} = Observable([0.0, 0.0])
    on(design.xy; priority=3) do val
        x::Real = val[1]
        y::Real = val[2]

        xo[] = [
            x - gui.vars[:Δh][] * gui.vars[:icon_scale] / 2,
            x + gui.vars[:Δh][] * gui.vars[:icon_scale] / 2,
        ]
        yo[] = [
            y - gui.vars[:Δh][] * gui.vars[:icon_scale] / 2,
            y + gui.vars[:Δh][] * gui.vars[:icon_scale] / 2,
        ]
    end

    if isempty(design.icon) # No path to an icon has been found
        node::EMB.Node = if typeof(design.system[:node]) <: EMB.Node
            design.system[:node]
        else
            design.system[:node].node
        end

        colors_input::Vector{RGB} = get_resource_colors(
            EMB.inputs(node), design.id_to_color_map
        )
        colors_output::Vector{RGB} = get_resource_colors(
            EMB.outputs(node), design.id_to_color_map
        )
        geometry::Symbol = if isa(node, EMB.Source)
            :rect
        elseif isa(node, EMB.Sink)
            :circle
        else # assume NetworkNode
            :triangle
        end
        for (j, colors) ∈ enumerate([colors_input, colors_output])
            no_colors::Int64 = length(colors)
            for (i, color) ∈ enumerate(colors)
                θᵢ::Float64 = 0
                θᵢ₊₁::Float64 = 0

                # Check if node is a NetworkNode (if so, devide disc into two where
                # left side is for input and right side is for output)
                if isa(node, EMB.NetworkNode)
                    θᵢ = (-1)^(j + 1) * π / 2 + π * (i - 1) / no_colors
                    θᵢ₊₁ = (-1)^(j + 1) * π / 2 + π * i / no_colors
                else
                    θᵢ = 2π * (i - 1) / no_colors
                    θᵢ₊₁ = 2π * i / no_colors
                end
                sector = get_sector_points()

                network_poly = poly!(
                    gui.axes[:topo], sector; color=color, inspectable=false
                )
                add_inspector_to_poly!(
                    network_poly, (self, i, p) -> get_hover_string(design.system[:node])
                )
                Makie.translate!(network_poly, 0, 0, gui.vars[:z_translate_components])
                gui.vars[:z_translate_components] += 1
                push!(design.plots, network_poly)
                on(design.xy; priority=3) do c
                    Δ = gui.vars[:Δh][] * gui.vars[:icon_scale] / 2
                    sector = get_sector_points(; c, Δ, θ₁=θᵢ, θ₂=θᵢ₊₁, geometry=geometry)
                    network_poly[1][] = sector
                end
            end
        end

        if isa(node, EMB.NetworkNode)
            # Add a vertical white separation line to distinguis input resources from output resources
            center_box = lines!(
                gui.axes[:topo],
                zeros(4),
                zeros(4);
                color=:black,
                linewidth=gui.vars[:linewidth],
                inspector_label=(self, i, p) -> get_hover_string(design.system[:node]),
                inspectable=true,
            )
            Makie.translate!(center_box, 0, 0, gui.vars[:z_translate_components])
            gui.vars[:z_translate_components] += 1
            push!(design.plots, center_box)
            on(design.xy; priority=3) do center
                radius = gui.vars[:Δh][] * gui.vars[:icon_scale] / 2
                x_coords, y_coords = box(center[1], center[2], radius / 4)
                center_box[1][] = Vector{Point{2,Float32}}([
                    [x, y] for (x, y) ∈ zip(x_coords, y_coords)
                ])
            end
        end
    else
        @debug "$(design.icon)"
        icon_image = image!(
            gui.axes[:topo], xo, yo, rotr90(FileIO.load(design.icon)); inspectable=false
        )
        Makie.translate!(icon_image, 0, 0, gui.vars[:z_translate_components])
        gui.vars[:z_translate_components] += 1
        push!(design.plots, icon_image)
    end
end

"""
    draw_label!(gui::GUI, component::EnergySystemDesign)

Add a label to an `EnergySystemDesign` component.
"""
function draw_label!(gui::GUI, component::EnergySystemDesign)
    xo = Observable(0.0)
    yo = Observable(0.0)
    alignment = Observable((:left, :top))

    scale = 0.7

    on(component.xy; priority=3) do val
        x = val[1]
        y = val[2]

        if component.wall[] == :E
            xo[] = x + gui.vars[:Δh][] * scale
            yo[] = y
        elseif component.wall[] == :S
            xo[] = x
            yo[] = y - gui.vars[:Δh][] * scale
        elseif component.wall[] == :W
            xo[] = x - gui.vars[:Δh][] * scale
            yo[] = y
        elseif component.wall[] == :N
            xo[] = x
            yo[] = y + gui.vars[:Δh][] * scale
        end
        alignment[] = get_text_alignment(component.wall[])
    end
    if haskey(component.system, :node)
        node = component.system[:node]
        label = isa(node.id, Number) ? string(node) : string(node.id)
        label_text = text!(
            gui.axes[:topo],
            xo,
            yo;
            text=label,
            align=alignment,
            fontsize=gui.vars[:fontsize],
            inspectable=false,
        )
        Makie.translate!(label_text, 0, 0, gui.vars[:z_translate_components])
        gui.vars[:z_translate_components] += 1
        push!(component.plots, label_text)
    end
end

"""
    adjust_limits!(gui::GUI)

Adjust the limits of gui.axes[:topo] based on its content.
"""
function adjust_limits!(gui::GUI)
    min_x, max_x, min_y, max_y = find_min_max_coordinates(gui.design)
    Δ_lim_x = max_x - min_x
    Δ_lim_y = max_y - min_y
    boundary_add = gui.vars[:boundary_add]
    min_x -= Δ_lim_x * boundary_add
    max_x += Δ_lim_x * boundary_add
    min_y -= Δ_lim_y * boundary_add
    max_y += Δ_lim_y * boundary_add
    Δ_lim_x = max_x - min_x
    Δ_lim_y = max_y - min_y
    x_center = (min_x + max_x) / 2
    y_center = (min_y + max_y) / 2
    if Δ_lim_y > Δ_lim_x
        Δ_lim_x = Δ_lim_y * gui.vars[:ax_aspect_ratio]
    else
        Δ_lim_y < Δ_lim_x
        Δ_lim_y = Δ_lim_x / gui.vars[:ax_aspect_ratio]
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
    gui.vars[:xlimits] = [min_x, max_x]
    gui.vars[:ylimits] = [min_y, max_y]
    limits!(gui.axes[:topo], gui.vars[:xlimits], gui.vars[:ylimits])

    # Fix the axis limits (needed to avoid resetting limits when adding objects along
    # connection lines upon zoom)
    return gui.axes[:topo].autolimitaspect = nothing
end

"""
    update_title!(gui::GUI)

Update the title of `gui.axes[:topo]` based on `gui.design`.
"""
function update_title!(gui::GUI)
    return gui.vars[:title][] = if isnothing(gui.design.parent)
        "top_level"
    else
        "$(gui.design.parent).$(gui.design.system[:node])"
    end
end

"""
    toggle_selection_color!(gui::GUI, selection, selected::Bool)

Set the color of selection to `gui.vars[:selection_color]` if selected, and its original
color otherwise using the argument `selected`.
"""
function toggle_selection_color!(gui::GUI, selection::EnergySystemDesign, selected::Bool)
    if selected
        selection.color[] = gui.vars[:selection_color]
    else
        selection.color[] = :black
    end
end
function toggle_selection_color!(gui::GUI, selection::Connection, selected::Bool)
    plots = selection.plots
    if selected
        for plot ∈ plots
            for plot_sub ∈ plot[]
                plot_sub.color = gui.vars[:selection_color]
            end
        end
    else
        colors::Vector{RGB} = selection.colors
        no_colors::Int64 = length(colors)
        for plot ∈ plots
            for (i, plot_sub) ∈ enumerate(plot[])
                plot_sub.color = colors[((i - 1) % no_colors) + 1]
            end
        end
    end
end
function toggle_selection_color!(gui::GUI, selection::Dict{Symbol,Any}, selected::Bool)
    if selected
        selection[:plot].color[] = gui.vars[:selection_color]
    else
        selection[:plot].color[] = selection[:color]
    end
    return update_legend!(gui)
end

"""
    pick_component!(gui::GUI)

Check if a system is found under the mouse pointer and if it is an `EnergySystemDesign`
and update state variables.
"""
function pick_component!(gui::GUI; pick_topo_component=false, pick_results_component=false)
    plt, _ = pick(gui.fig)

    if isnothing(plt)
        clear_selection(
            gui; clear_topo=pick_topo_component, clear_results=pick_results_component
        )
    else
        if pick_topo_component
            # Loop through the design to find if the object under the pointer matches any
            # of the object link to any of the components
            for component ∈ gui.design.components
                for plot ∈ component.plots
                    if plot === plt || plot === plt.parent || plot === plt.parent.parent
                        toggle_selection_color!(gui, component, true)
                        push!(gui.vars[:selected_systems], component)
                        return nothing
                    end
                end
                if !isempty(component.components) && gui.vars[:expand_all]
                    for sub_component ∈ component.components
                        for plot ∈ sub_component.plots
                            if plot === plt ||
                                plot === plt.parent ||
                                plot === plt.parent.parent
                                toggle_selection_color!(gui, sub_component, true)
                                push!(gui.vars[:selected_systems], sub_component)
                                return nothing
                            end
                        end
                    end
                end
            end

            # Update the variables selections with the current selection
            for connection ∈ gui.design.connections
                for plot ∈ connection.plots
                    for plot_sub ∈ plot[]
                        if plot_sub === plt ||
                            plot_sub === plt.parent ||
                            plot_sub === plt.parent.parent
                            toggle_selection_color!(gui, connection, true)
                            push!(gui.vars[:selected_systems], connection)
                            return nothing
                        end
                    end
                end
            end
            for component ∈ gui.design.components
                if !isempty(component.components) && gui.vars[:expand_all]
                    for connection ∈ component.connections
                        for plot ∈ connection.plots
                            for plot_sub ∈ plot[]
                                if plot_sub === plt ||
                                    plot_sub === plt.parent ||
                                    plot_sub === plt.parent.parent
                                    toggle_selection_color!(gui, connection, true)
                                    push!(gui.vars[:selected_systems], connection)
                                    return nothing
                                end
                            end
                        end
                    end
                end
            end
        end
        if pick_results_component
            time_axis = gui.menus[:time].selection[]
            for vis_obj ∈ gui.vars[:visible_plots][time_axis]
                plot = vis_obj[:plot]
                if plot === plt ||
                    plot === plt.parent ||
                    plot === plt.parent.parent ||
                    plot === plt.parent.parent.parent
                    if !(vis_obj ∈ gui.vars[:selected_plots])
                        toggle_selection_color!(gui, vis_obj, true)
                        push!(gui.vars[:selected_plots], vis_obj)
                    end
                    return nothing
                end
            end
        end
    end
end

"""
    update_limits!(gui::GUI)

Update the limits based on the visible plots of type `time_axis`
"""
function update_limits!(gui::GUI)
    time_axis = gui.menus[:time].selection[]
    autolimits!(gui.axes[time_axis])
    yorigin::Float32 = gui.axes[time_axis].finallimits[].origin[2]
    ywidth::Float32 = gui.axes[time_axis].finallimits[].widths[2]

    # ensure that the legend box does not overlap the data
    ylims!(gui.axes[time_axis], yorigin, yorigin + ywidth * 1.1)
end

"""
    get_hover_string(node::Plotable)

Return the string for a Node/Area/Link/Transmission to be shown on hovering.
"""
function get_hover_string(node::Plotable)
    return string(nameof(typeof(node)))
end
