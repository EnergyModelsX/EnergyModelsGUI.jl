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
    align(gui::GUI, type::Symbol)

Align components in `gui.vars[:selected_systems]` based on the value of Symbol `type`.

The following values are allowed

- `:horizontal` for horizontal alignment.
- `:vertical` for vertical alignment.
"""
function align(gui::GUI, type::Symbol)
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
    z::Real = if type == :horizontal
        sum(ys) / length(ys)
    elseif type == :vertical
        sum(xs) / length(xs)
    end

    for sub_design ∈ gui.vars[:selected_systems]
        if isa(sub_design, EnergySystemDesign)
            x, y = sub_design.xy[]

            if type == :horizontal
                sub_design.xy[] = (x, z)
            elseif type == :vertical
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
        type::Symbol = if isa(node, EMB.Source)
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
                    sector = get_sector_points(; c, Δ, θ₁=θᵢ, θ₂=θᵢ₊₁, type=type)
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
    clear_selection(gui::GUI; clear_topo=true, clear_results=true)

Clear the color selection of components within 'gui.design' instance and reset the
`gui.vars[:selected_systems]` variable.
"""
function clear_selection(gui::GUI; clear_topo=true, clear_results=true)
    if clear_topo
        for selection ∈ gui.vars[:selected_systems]
            toggle_selection_color!(gui, selection, false)
        end
        empty!(gui.vars[:selected_systems])
        update_available_data_menu!(gui, nothing) # Make sure the menu is updated
    end
    if clear_results
        for selection ∈ gui.vars[:selected_plots]
            toggle_selection_color!(gui, selection, false)
        end
        empty!(gui.vars[:selected_plots])
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
            axis_time_type = gui.menus[:time].selection[]
            for vis_obj ∈ gui.vars[:visible_plots][axis_time_type]
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
    update!(gui::GUI)

Upon release of left mouse button update plots.
"""
function update!(gui::GUI)
    selected_systems = gui.vars[:selected_systems]
    updateplot = !isempty(selected_systems)

    if updateplot
        update!(gui, selected_systems[end]; updateplot=updateplot)
    else
        update!(gui, nothing; updateplot=updateplot)
    end
end

"""
    update!(gui::GUI, node::Plotable; updateplot::Bool=true)

Based on `node`, update the text in `gui.axes[:info]` and update plot in
`gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, node::Plotable; updateplot::Bool=true)
    update_info_box!(gui, node)
    update_available_data_menu!(gui, node)
    if updateplot
        update_plot!(gui, node)
    end
end

"""
    update!(gui::GUI, connection::Connection; updateplot::Bool=true)

Based on `connection.connection`, update the text in `gui.axes[:info]`
and update plot in `gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, connection::Connection; updateplot::Bool=true)
    return update!(gui, connection.connection; updateplot)
end

"""
    update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)

Based on `design.system[:node]`, update the text in `gui.axes[:info]`
and update plot in `gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)
    return update!(gui, design.system[:node]; updateplot)
end

"""
    initialize_available_data!(gui)

For all plotable objects, initialize the available data menu with items.
"""
function initialize_available_data!(gui)
    system = gui.root_design.system
    plotables = []
    append!(plotables, [nothing]) # nothing here represents no selection
    append!(plotables, system[:nodes])
    if haskey(system, :areas)
        append!(plotables, system[:areas])
    end
    append!(plotables, system[:links])
    if haskey(system, :transmission)
        append!(plotables, system[:transmission])
    end
    for node ∈ plotables
        # Find appearances of node/area/link/transmission in the model
        available_data = Vector{Dict}(undef, 0)
        if termination_status(gui.model) == MOI.OPTIMAL # Plot results if available
            for dict ∈ collect(keys(object_dictionary(gui.model)))
                if isempty(gui.model[dict])
                    continue
                end
                if typeof(gui.model[dict]) <: JuMP.Containers.DenseAxisArray
                    # nodes/areas found in structure
                    if any(eltype.(axes(gui.model[dict])) .<: Union{EMB.Node,EMG.Area})
                        # only add dict if used by node (assume node are located at first Dimension)
                        if exists(gui.model[dict], node)
                            if length(axes(gui.model[dict])) > 2
                                for res ∈ gui.model[dict].axes[3]
                                    container = Dict(
                                        :name => string(dict),
                                        :is_jump_data => true,
                                        :selection => [node, res],
                                    )
                                    key_str = "variables.$dict"
                                    add_description!(
                                        available_data, container, gui, key_str
                                    )
                                end
                            else
                                container = Dict(
                                    :name => string(dict),
                                    :is_jump_data => true,
                                    :selection => [node],
                                )
                                key_str = "variables.$dict"
                                add_description!(available_data, container, gui, key_str)
                            end
                        end
                    elseif any(eltype.(axes(gui.model[dict])) .<: EMG.TransmissionMode) # nodes found in structure
                        if isa(node, EMG.Transmission)
                            for mode ∈ modes(node)
                                # only add dict if used by node (assume node are located at first Dimension)
                                if exists(gui.model[dict], mode)
                                    # do not include node (<: EMG.Transmission) here
                                    # as the mode is unique to this transmission
                                    container = Dict(
                                        :name => string(dict),
                                        :is_jump_data => true,
                                        :selection => [mode],
                                    )
                                    key_str = "variables.$dict"
                                    add_description!(
                                        available_data, container, gui, key_str
                                    )
                                end
                            end
                        end
                    elseif isnothing(node)
                        if length(axes(gui.model[dict])) > 1
                            for res ∈ gui.model[dict].axes[2]
                                container = Dict(
                                    :name => string(dict),
                                    :is_jump_data => true,
                                    :selection => [res],
                                )
                                key_str = "variables.$dict"
                                add_description!(available_data, container, gui, key_str)
                            end
                        else
                            container = Dict(
                                :name => string(dict),
                                :is_jump_data => true,
                                :selection => EMB.Node[],
                            )
                            key_str = "variables.$dict"
                            add_description!(available_data, container, gui, key_str)
                        end
                    end
                elseif typeof(gui.model[dict]) <: SparseVars
                    fieldtypes = typeof.(first(keys(gui.model[dict].data)))
                    if any(fieldtypes .<: Union{EMB.Node,EMB.Link,EMG.Area}) # nodes/area/links found in structure
                        if exists(gui.model[dict], node) # current node found in structure
                            extract_combinations!(
                                gui, available_data, dict, node, gui.model
                            )
                        end
                    elseif any(fieldtypes .<: EMG.TransmissionMode) # TransmissionModes found in structure
                        if isa(node, EMG.Transmission)
                            for mode ∈ modes(node)
                                if exists(gui.model[dict], mode) # current mode found in structure
                                    extract_combinations!(
                                        gui, available_data, dict, mode, gui.model
                                    )
                                end
                            end
                        end
                    elseif isnothing(node)
                        extract_combinations!(gui, available_data, dict, gui.model)
                    end
                end
            end
        end

        # Add timedependent input data (if available)
        if !isnothing(node)
            for field_name ∈ fieldnames(typeof(node))
                field = getfield(node, field_name)
                structure = String(nameof(typeof(node)))
                name = "$field_name"
                key_str = "structures.$structure.$name"
                add_description!(field, name, key_str, "", node, available_data, gui)
            end
        end
        gui.vars[:available_data][node] = Dict(
            :container => available_data,
            :container_strings => create_label.(available_data),
        )
    end
end

"""
    update_available_data_menu!(gui::GUI, node::Plotable)

Update the `gui.menus[:available_data]` with the available data of `node`.
"""
function update_available_data_menu!(gui::GUI, node::Plotable)
    container = gui.vars[:available_data][node][:container]
    container_strings = gui.vars[:available_data][node][:container_strings]
    return gui.menus[:available_data].options = zip(container_strings, container)
end

"""
    add_description!(
        field::Dict,
        name::String,
        key_str::String,
        pre_desc::String,
        node::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

Update the container with a description if available, and add description to available_data.
"""
function add_description!(
    field::Dict,
    name::String,
    key_str::String,
    pre_desc::String,
    node::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    for (dictname, dictvalue) ∈ field
        name_field = "$name.$dictname"
        key_str_field = "$key_str.$dictname"
        add_description!(
            dictvalue, name_field, key_str_field, pre_desc, node, available_data, gui
        )
    end
end

"""
    add_description!(
        field::Vector,
        name::String,
        key_str::String,
        pre_desc::String,
        node::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

If field is a vector, loop through the vector and update the container with a description
if available, and add description to available_data.
"""
function add_description!(
    field::Vector,
    name::String,
    key_str::String,
    pre_desc::String,
    node::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    for data ∈ field
        data_type = nameof(typeof(data))
        name_field = "$name.$data_type"
        key_str_field = "$key_str.$data_type"
        add_description!(
            data, name_field, key_str_field, pre_desc, node, available_data, gui
        )
    end
end

"""
    add_description!(
        field::Any,
        name::String,
        key_str::String,
        pre_desc::String,
        node::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

Update the container with a description if available, and add description to available_data.
"""
function add_description!(
    field::Any,
    name::String,
    key_str::String,
    pre_desc::String,
    node::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    field_type = typeof(field)
    for sub_field_name ∈ fieldnames(field_type)
        sub_field = getfield(field, sub_field_name)
        name_field_type = nameof(field_type)
        name_field = "$name.$sub_field_name"
        pre_desc_sub = "$pre_desc$name_field_type: "
        key_str = "structures.$name_field_type.$sub_field_name"
        add_description!(
            sub_field, name_field, key_str, pre_desc_sub, node, available_data, gui
        )
    end
end

"""
    add_description!(
        field::T,
        name::String,
        key_str::String,
        pre_desc::String,
        node::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    ) where {T<:TS.TimeProfile}

Update the container with a description if available, and add description to available_data.
"""
function add_description!(
    field::T,
    name::String,
    key_str::String,
    pre_desc::String,
    node::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
) where {T<:TS.TimeProfile}
    container = Dict(
        :name => name, :is_jump_data => false, :selection => [node], :field_data => field
    )
    add_description!(available_data, container, gui, key_str; pre_desc)
end

"""
    add_description!(
        available_data::Vector{Dict},
        container::Dict{Symbol,Any},
        gui::GUI,
        key_str::String;
        pre_desc::String="",
    )

Update the container with a description if available, and add container to available_data.
"""
function add_description!(
    available_data::Vector{Dict},
    container::Dict{Symbol,Any},
    gui::GUI,
    key_str::String;
    pre_desc::String="",
)
    structure = get_nth_field(key_str, '.', 3)
    if structure == "to" || structure == "from" # don't add `to` and `from` fields
        return nothing
    end
    description = pre_desc
    try
        description *= String(get_nested_value(gui.vars[:descriptive_names], key_str))
    catch
        description = key_str[(findfirst('.', key_str) + 1):end]
        @warn "Could't find a description for $description. \
            Using the string $description instead"
    end
    container[:description] = description
    push!(available_data, container)
end

"""
    get_data(
        model::JuMP.Model,
        selection::Dict{Symbol, Any},
        T::TS.TimeStructure,
        sp::Int64,
        rp::Int64
        sc::Int64,
    )

Get the values from the JuMP `model` or the input data for at `selection` for all times `T`
restricted to strategic period `sp`, representative period `rp`, and scenario `sc`.
"""
function get_data(
    model::JuMP.Model, selection::Dict, T::TS.TimeStructure, sp::Int64, rp::Int64, sc::Int64
)
    if selection[:is_jump_data]
        dict = Symbol(selection[:name])
        i_T, type = get_time_axis(model[dict])
    else
        field_data = selection[:field_data]
        type = typeof(field_data)
    end
    t_values, x_type = get_time_values(T, type, sp, rp, sc)
    if selection[:is_jump_data]
        y_values = get_jump_values(model, dict, selection[:selection], t_values, i_T)
    else
        y_values = field_data[t_values]
    end
    return t_values, y_values, x_type
end

"""
    get_jump_values(
        model::JuMP.Model, var::Symbol, selection::Vector, t_values::Vector, i_T::Int64
    )

Get the values from the JuMP `model` for symbol `var` at `selection` for all times `T` \
restricted to `sp`
"""
function get_jump_values(
    model::JuMP.Model, var::Symbol, selection::Vector, t_values::Vector, i_T::Int64
)
    return [
        value(model[var][vcat(selection[1:(i_T - 1)], t, selection[i_T:end])...]) for
        t ∈ t_values
    ]
end

"""
    get_time_values(
        T::TS.TimeStructure, type::Type, sp::Int64, rp::Int64, sc::Int64
    )

Get the time values for a given time type (TS.StrategicPeriod, TS.RepresentativePeriod
or TS.OperationalPeriod)
"""
function get_time_values(T::TS.TimeStructure, type::Type, sp::Int64, rp::Int64, sc::Int64)
    if type <: TS.StrategicPeriod
        return [t for t ∈ TS.strat_periods(T)], :StrategicPeriod
    elseif type <: TS.TimeStructure{T} where {T}
        return [t for t ∈ TS.repr_periods(T)], :RepresentativePeriod
    else
        if eltype(T.operational) <: TS.RepresentativePeriods
            if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
                return [
                    t for
                    t ∈ T if t.sp == sp && t.period.rp == rp && t.period.period.sc == sc
                ],
                :OperationalPeriod
            else
                return [t for t ∈ T if t.sp == sp && t.period.rp == rp], :OperationalPeriod
            end
        elseif eltype(T.operational) <: TS.OperationalScenarios
            return [t for t ∈ T if t.sp == sp && t.period.sc == sc], :OperationalPeriod
        else
            return [t for t ∈ T if t.sp == sp], :OperationalPeriod
        end
    end
end

"""
    get_time_axis(
        data::Union{
            JuMP.Containers.DenseAxisArray,
            JuMP.Containers.SparseAxisArray,
            SparseVariables.IndexedVarArray,
        },
    )

Get the index of the axis/column corresponding to TS.TimePeriod and return the specific type.
"""
function get_time_axis(
    data::Union{
        JuMP.Containers.DenseAxisArray,
        JuMP.Containers.SparseAxisArray,
        SparseVariables.IndexedVarArray,
    },
)
    types::Vector{Type} = collect(get_jump_axis_types(data))
    i_T::Union{Int64,Nothing} = findfirst(
        x -> x <: TS.TimePeriod || x <: TS.TimeStructure{T} where {T}, types
    )
    if isnothing(i_T)
        return i_T, nothing
    else
        return i_T, types[i_T]
    end
end

"""
    get_jump_axis_types(data::JuMP.Containers.DenseAxisArray)

Get the types for each axis in the data.
"""
function get_jump_axis_types(data::JuMP.Containers.DenseAxisArray)
    return eltype.(axes(data))
end
function get_jump_axis_types(data::SparseVars)
    return typeof.(first(keys(data.data)))
end

"""
    create_label(selection::Vector{Any})

Return a label for a given `selection` to be used in the gui.menus[:available_data] menu.
"""
function create_label(selection::Dict{Symbol,Any})
    label::String = selection[:is_jump_data] ? "" : "Case data: "
    if haskey(selection, :description)
        label *= selection[:description] * " ($(selection[:name]))"
    else
        label *= selection[:name]
    end
    otherRes::Bool = false
    if length(selection) > 1
        for select ∈ selection[:selection]
            if !isa(select, Plotable)
                if !otherRes
                    label *= " ("
                    otherRes = true
                end
                label *= "$(select)"
                if select != selection[:selection][end]
                    label *= ", "
                end
            end
        end
        if otherRes
            label *= ")"
        end
    end
    return label
end

"""
    update_plot!(gui::GUI, node)

Based on `node` update the results in `gui.axes[:results]`.
"""
function update_plot!(gui::GUI, node::Plotable)
    T = gui.root_design.system[:T]
    selection = gui.menus[:available_data].selection[]
    if !isnothing(selection)
        xlabel = "Time"
        if haskey(selection, :description)
            ylabel = selection[:description]
        else
            ylabel = selection[:name]
        end
        sp = gui.menus[:period].selection[]
        rp = gui.menus[:representative_period].selection[]
        sc = gui.menus[:scenario].selection[]

        t_values, y_values, x_type = get_data(gui.model, selection, T, sp, rp, sc)

        label::String = create_label(selection)
        if !isnothing(node)
            label *= " for $node"
        end
        if x_type == :StrategicPeriod
            xlabel *= " (StrategicPeriod)"
        elseif x_type == :RepresentativePeriod
            xlabel *= " (RepresentativePeriod)"
        elseif x_type == :OperationalPeriod
            xlabel *= " (OperationalPeriod)"

            if eltype(T.operational) <: TS.RepresentativePeriods
                if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
                    label *= " for strategic period $sp, representative period $rp and scenario $sc"
                else
                    label *= " for strategic period $sp and representative period $rp"
                end
            elseif eltype(T.operational) <: TS.RepresentativePeriods
                label *= " for strategic period $sp and representative period $rp"
            else
                label *= " for strategic period $sp"
            end
        end

        no_pts = length(t_values)
        # For FixedProfiles, make sure the y_values are extended correspondingly to the x_values
        if no_pts > length(y_values)
            y_values = vcat(y_values, fill(y_values[end], no_pts - length(y_values)))
        end
        if x_type == :OperationalPeriod
            x_values = get_op.(t_values)
            x_values_step, y_values_step = stepify(vec(x_values), vec(y_values))
            # For FixedProfile, make values constant over the operational period
            points = [Point{2,Float64}(x, y) for (x, y) ∈ zip(x_values_step, y_values_step)]
            custom_ticks = (0:no_pts, string.(0:no_pts))
            gui.menus[:time].i_selected[] = 3
        else
            points = [Point{2,Float64}(x, y) for (x, y) ∈ zip(1:no_pts, y_values)]
            custom_ticks = (1:no_pts, [string(t) for t ∈ t_values])
            if x_type == :StrategicPeriod
                gui.menus[:time].i_selected[] = 1
            else
                gui.menus[:time].i_selected[] = 2
            end
        end
        notify(gui.menus[:time].selection) # In case the new plot is on an other time type
        axis_time_type = gui.menus[:time].selection[]
        pinned_plots = [x[:plot] for x ∈ gui.vars[:pinned_plots][axis_time_type]]
        visible_plots = [x[:plot] for x ∈ gui.vars[:visible_plots][axis_time_type]]
        plots = filter(
            x ->
                (isa(x, Combined) || isa(x, Lines)) &&
                    !isa(x, Wireframe) &&
                    !(x ∈ pinned_plots),
            gui.axes[axis_time_type].scene.plots,
        ) # Extract non-pinned plots. Only extract Lines and Combined (bars). Done to avoid Wireframe-objects

        plot = getfirst(x -> x ∈ visible_plots, plots) # get first non-pinned visible plots
        if isnothing(plot)
            @debug "Could not find a visible plot to overwrite, try to find a hidden plot to overwrite"
            plot = getfirst(
                x ->
                    (isa(x, Combined) || isa(x, Lines)) &&
                        !isa(x, Wireframe) &&
                        !x.visible[],
                plots,
            ) # Extract non-visible plots that can be replaced
            if !isnothing(plot) # Overwrite a hidden plots
                @debug "Found a hidden plot to overwrite"
                push!(
                    gui.vars[:visible_plots][axis_time_type],
                    Dict(
                        :plot => plot,
                        :name => selection[:name],
                        :selection => selection[:selection],
                        :t => t_values,
                        :y => y_values,
                        :color => plot.color[],
                    ),
                )
            end
        else # Overwrite the non-pinned visible plot
            @debug "Found a visible plot to overwrite"
            # remove the plot to be overwritten
            filter!(x -> x[:plot] != plot, gui.vars[:visible_plots][axis_time_type])

            push!(
                gui.vars[:visible_plots][axis_time_type],
                Dict(
                    :plot => plot,
                    :name => selection[:name],
                    :selection => selection[:selection],
                    :t => t_values,
                    :y => y_values,
                    :color => plot.color[],
                ),
            )
        end

        if !isnothing(plot)
            plot[1][] = points
            plot.visible = true # If it has been hidden after a "Remove Plot" action
            plot.label = label
        else
            @debug "Could not find anything to overwrite, creating new plot instead"
            if x_type == :OperationalPeriod
                plot = lines!(gui.axes[axis_time_type], points; label=label)
            else
                n_visible = length(gui.vars[:visible_plots][axis_time_type]) + 1
                plot = barplot!(
                    gui.axes[axis_time_type],
                    points;
                    dodge=n_visible * ones(Int, length(points)),
                    n_dodge=n_visible,
                    strokecolor=:black,
                    strokewidth=1,
                    label=label,
                )
            end
            push!(
                gui.vars[:visible_plots][axis_time_type],
                Dict(
                    :plot => plot,
                    :name => selection[:name],
                    :selection => selection[:selection],
                    :t => t_values,
                    :y => y_values,
                    :color => plot.color[],
                ),
            )
        end
        update_barplot_dodge!(gui)
        if all(y_values .≈ 0)
            # Deactivate inspector for bars to avoid issue with wireframe when selecting
            # a bar with values being zero
            toggle_inspector!(plot, false)
        end

        if isempty(gui.vars[:results_legend]) # Initialize the legend box
            push!(
                gui.vars[:results_legend],
                axislegend(
                    gui.axes[axis_time_type], [plot], [label]; labelsize=gui.vars[:fontsize]
                ),
            ) # Add legends inside axes[:results] area
        else
            update_legend!(gui)
        end

        if x_type == :OperationalPeriod
            gui.axes[axis_time_type].xticks = Makie.automatic
        else
            gui.axes[axis_time_type].xticks = custom_ticks
        end
        gui.axes[axis_time_type].xlabel = xlabel
        gui.axes[axis_time_type].ylabel = ylabel
        update_limits!(gui)
    end
end

"""
    update_limits!(gui::GUI)

Update the limits based on the visible plots of type `axis_time_type`
"""
function update_limits!(gui::GUI)
    axis_time_type = gui.menus[:time].selection[]
    autolimits!(gui.axes[axis_time_type])
    yorigin::Float32 = gui.axes[axis_time_type].finallimits[].origin[2]
    ywidth::Float32 = gui.axes[axis_time_type].finallimits[].widths[2]

    # ensure that the legend box does not overlap the data
    ylims!(gui.axes[axis_time_type], yorigin, yorigin + ywidth * 1.1)
end

"""
    update_legend!(gui::GUI)

Update the legend based on the visible plots of type `axis_time_type`
"""
function update_legend!(gui::GUI)
    axis_time_type = gui.menus[:time].selection[]
    if !isempty(gui.vars[:results_legend])
        gui.vars[:results_legend][1].entrygroups[] = [(
            nothing,
            #! format: off
            [
                LegendEntry(x[:plot].label, x[:plot], gui.vars[:results_legend][1])
                for x ∈ gui.vars[:visible_plots][axis_time_type]
            ],
            #! format: on
        )]
    end
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `connection.connection` update the results in `gui.axes[:results]`
"""
function update_plot!(gui::GUI, connection::Connection)
    return update_plot!(gui, connection.connection)
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `design.system[:node]` update the results in `gui.axes[:results]`
"""
function update_plot!(gui::GUI, design::EnergySystemDesign)
    return update_plot!(gui, design.system[:node])
end

"""
    update_info_box!(gui::GUI, node; indent::Int64=0)

Based on `node` update the text in `gui.axes[:info]`
"""
function update_info_box!(gui::GUI, node; indent::Int64=0)
    infoBox = gui.axes[:info].scene.plots[1][1]
    if isnothing(node)
        infoBox[] = gui.vars[:default_text]
        return nothing
    end
    if indent == 0
        infoBox[] = "$node ($(typeof(node)))\n"
    end
    indent += 1
    indent_str = "  "^indent
    is_iterable(x) =
        isa(x, Vector) || isa(x, Dict) || typeof(x) <: EMB.Node || typeof(x) <: EMB.Resource
    if isa(node, Vector)
        for (i, field1) ∈ enumerate(node)
            if is_iterable(field1)
                infoBox[] *= indent_str * "$i: $(typeof(field1)):\n"
                update_info_box!(gui, field1; indent)
            else
                infoBox[] *= indent_str * "$i: $(typeof(field1))\n"
            end
        end
    elseif isa(node, Dict)
        for field1 ∈ keys(node)
            infoBox[] *= indent_str * "$field1 => $(node[field1])\n"
        end
    else
        for field1 ∈ fieldnames(typeof(node))
            value1 = getfield(node, field1)
            if is_iterable(value1)
                infoBox[] *= indent_str * "$(field1) ($(typeof(value1))):\n"
                update_info_box!(gui, value1; indent)
            else
                infoBox[] *= indent_str * "$(field1): $value1\n"
            end
        end
    end
end

"""
    get_hover_string(node::Plotable)

Return the string for a Node/Area/Link/Transmission to be shown on hovering.
"""
function get_hover_string(node::Plotable)
    return string(nameof(typeof(node)))
end

"""
    update_barplot_dodge!(gui::GUI)

Update the barplot of the state of the GUI (such that the bars are dodged away from each other)
"""
function update_barplot_dodge!(gui::GUI)
    if gui.menus[:time].selection[] != :results_op
        axis_time_type = gui.menus[:time].selection[]
        n_visible = length(gui.vars[:visible_plots][axis_time_type])
        for (i, x) ∈ enumerate(gui.vars[:visible_plots][axis_time_type])
            x[:plot].n_dodge = n_visible
            x[:plot].dodge = i * ones(Int, length(x[:plot].dodge[]))
        end
    end
end
