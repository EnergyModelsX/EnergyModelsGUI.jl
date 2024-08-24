"""
    pixel_to_data(gui::GUI, pixel_size::Real)

Convert `pixel_size` to data widths (in x- and y-direction) in design object `gui`.
"""
function pixel_to_data(gui::GUI, pixel_size::Real)
    # Calculate the range in data coordinates
    vars = get_vars(gui)
    x_range::Float64 = vars[:xlimits][2] - vars[:xlimits][1]
    y_range::Float64 = vars[:ylimits][2] - vars[:ylimits][1]

    # Get the widths of the axis
    plot_widths::Vec2{Int64} = pixelarea(get_ax(gui, :topo).scene)[].widths

    # Calculate the conversion factor
    x_factor::Float64 = x_range / plot_widths[1]
    y_factor::Float64 = y_range / plot_widths[2]

    # Convert pixel size to data coordinates
    return (pixel_size * x_factor, pixel_size * y_factor)
end

"""
    update_distances!(gui::GUI)

Find the minimum distance between the elements in the design object `gui` and update `Δh` such
that neighbouring icons do not overlap.
"""
function update_distances!(gui::GUI)
    min_d::Float64 = Inf
    design = get_design(gui)
    components = get_components(design)
    if length(components) > 1
        for component ∈ components
            d::Float64 = minimum([
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
    plot_widths::Vec2{Int64} = pixelarea(axes[:topo].scene)[].widths
    vars[:Δh] = maximum([
        maximum(Vector(0.5 * vars[:Δh_px] * xyWidths ./ plot_widths)),
        minimum([
            minimum(Vector(vars[:Δh_px] * xyWidths ./ plot_widths)),
            vars[:minimum_distance] / 2, # Do this to avoid overlapping squares
        ]),
    ])
end

"""
    get_change(::GUI, ::Val)

Handle different keyboard inputs (events) and return changes in x, y coordinates in the
design object `gui`.
"""
get_change(::GUI, ::Val) = (0.0, 0.0)
get_change(gui::GUI, ::Val{Keyboard.up}) = (0.0, +get_var(gui, :Δh) / 5)
get_change(gui::GUI, ::Val{Keyboard.down}) = (0.0, -get_var(gui, :Δh) / 5)
get_change(gui::GUI, ::Val{Keyboard.left}) = (-get_var(gui, :Δh) / 5, 0.0)
get_change(gui::GUI, ::Val{Keyboard.right}) = (+get_var(gui, :Δh) / 5, 0.0)

"""
    align(gui::GUI, align::Symbol)

Align components in `get_selected_systems(gui)` based on the value of Symbol `align`.

The following values are allowed

- `:horizontal` for horizontal alignment.
- `:vertical` for vertical alignment.
"""
function align(gui::GUI, align::Symbol)
    xs::Vector{Real} = Real[]
    ys::Vector{Real} = Real[]
    for sub_design ∈ get_selected_systems(gui)
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
    gui::GUI, design::EnergySystemDesign; visible::Bool=true, expand_all::Bool=true
)
    for component ∈ get_components(design)
        component_visibility::Bool = (component == get_design(gui)) || expand_all
        plot_design!(gui, component; visible=component_visibility, expand_all)
    end
    if get_design(gui) == design
        update_distances!(gui)
    end
    for component ∈ get_components(design), plot ∈ component.plots
        plot.visible = visible
    end
    for connection ∈ get_connections(design), plots ∈ get_plots(connection), plot ∈ plots[]
        plot.visible = visible
    end
end

"""
    connect!(gui::GUI, design::EnergySystemDesign)

Draws lines between connected nodes/areas in GUI `gui` using EnergySystemDesign `design`.
"""
function connect!(gui::GUI, design::EnergySystemDesign)
    # Find optimal placement of label by finding the wall that has the least number of connections
    connections = get_connections(design)
    components = get_components(design)
    for component ∈ components
        linked_to_component::Vector{Connection} = filter(
            x -> component.system[:node].id == get_connection(x).to.id, connections
        )
        linked_from_component::Vector{Connection} = filter(
            x -> component.system[:node].id == get_connection(x).from.id, connections
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

    for conn ∈ connections
        # Check if link between two elements goes in both directions (two_way)
        link = get_connection(conn)
        two_way::Bool = false
        for conn2 ∈ connections
            link2 = get_connection(conn2)
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
    push!(get_plots(connection), line_connections)
    push!(get_plots(connection), arrow_heads)
    linestyle = get_linestyle(gui, connection)

    # Create function to be run on changes in connection.from and connection.to
    update =
        () -> begin
            markersize_lengths::Tuple{Float64,Float64} = pixel_to_data(
                gui, get_var(gui, :markersize)
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
                pixel_to_data(gui, get_var(gui, :connection_linewidth)) .+
                pixel_to_data(gui, get_var(gui, :line_sep_px))
            two_way_sep::Tuple{Float64,Float64} = pixel_to_data(
                gui, get_var(gui, :two_way_sep_px)
            )
            θ::Float64 = atan(xy_2[2] - xy_1[2], xy_2[1] - xy_1[1])
            cosθ::Float64 = cos(θ)
            sinθ::Float64 = sin(θ)
            cosϕ::Float64 = -sinθ # where ϕ = θ+π/2
            sinϕ::Float64 = cosθ

            Δ::Float64 = get_var(gui, :Δh) / 2 # half width of a box
            if !isempty(get_components(connection.from))
                Δ *= get_var(gui, :parent_scaling)
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
                        get_axes(gui)[:topo],
                        xy_midpoint[1],
                        xy_midpoint[2];
                        marker=arrow_parts[j],
                        markersize=get_var(gui, :markersize),
                        rotation=θ,
                        color=colors[j],
                        inspectable=false,
                    )
                    lns = lines!(
                        get_axes(gui)[:topo],
                        xs,
                        ys;
                        color=colors[j],
                        linewidth=get_var(gui, :connection_linewidth),
                        linestyle=linestyle,
                        inspector_label=(self, i, p) ->
                            get_hover_string(connection.connection),
                        inspectable=true,
                    )
                    Makie.translate!(sctr, 0, 0, get_var(gui, :z_translate_lines))
                    get_vars(gui)[:z_translate_lines] += 1
                    Makie.translate!(lns, 0, 0, get_var(gui, :z_translate_lines))
                    get_vars(gui)[:z_translate_lines] += 1
                    push!(arrow_heads[], sctr)
                    push!(line_connections[], lns)
                else
                    arrow_heads[][j][1][] = [Point{2,Float64}(xy_midpoint[1], xy_midpoint[2])]
                    arrow_heads[][j][:rotation] = θ
                    arrow_heads[][j].visible = true
                    line_connections[][j][1][] = [
                        Point{2,Float64}(x, y) for (x, y) ∈ zip(xs, ys)
                    ]
                    line_connections[][j].visible = true
                end
                line_connections[][j].kw[:EMGUI_obj] = connection
                arrow_heads[][j].kw[:EMGUI_obj] = connection
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
            return get_var(gui, :investment_lineStyle)
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
    if isa(t, Transmission)
        if EMI.has_investment(t)
            return get_var(gui, :investment_lineStyle)
        else
            return :solid
        end
    end

    # For Links, simply use dashed style if from or to node has investments
    linestyle::Union{Symbol,Makie.Linestyle} = get_linestyle(gui, connection.from)
    if linestyle == get_var(gui, :investment_lineStyle)
        return linestyle
    end
    linestyle = get_linestyle(gui, connection.to)
    if linestyle == get_var(gui, :investment_lineStyle)
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
    if !isempty(get_components(design))
        xo2::Observable{Vector{Real}} = Observable(zeros(5))
        yo2::Observable{Vector{Real}} = Observable(zeros(5))
        vertices2::Vector{Tuple{Real,Real}} = [
            (x, y) for (x, y) ∈ zip(xo2[][1:(end - 1)], yo2[][1:(end - 1)])
        ]

        white_rect2 = poly!(
            get_axes(gui)[:topo], vertices2; color=:white, strokewidth=0, inspectable=false
        ) # Create a white background rectangle to hide lines from connections
        add_inspector_to_poly!(
            white_rect2, (self, i, p) -> get_hover_string(get_system_node(design))
        )
        Makie.translate!(white_rect2, 0, 0, get_var(gui, :z_translate_components))
        get_vars(gui)[:z_translate_components] += 1
        push!(design.plots, white_rect2)

        # observe changes in design coordinates and update enlarged box position
        on(design.xy; priority=3) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, get_var(gui, :Δh) / 2 * get_var(gui, :parent_scaling))
            white_rect2[1] = [
                (x, y) for (x, y) ∈ zip(xo2[][1:(end - 1)], yo2[][1:(end - 1)])
            ]
        end

        box_boundary2 = lines!(
            get_axes(gui)[:topo],
            xo2,
            yo2;
            color=design.color,
            linewidth=get_var(gui, :linewidth),
            linestyle=:solid,
            inspectable=false,
        )
        Makie.translate!(box_boundary2, 0, 0, get_var(gui, :z_translate_components))
        get_vars(gui)[:z_translate_components] += 1
        push!(design.plots, box_boundary2)
        box_boundary2.kw[:EMGUI_obj] = design
        white_rect2.kw[:EMGUI_obj] = design
    end

    xo::Observable{Vector{Real}} = Observable(zeros(5))
    yo::Observable{Vector{Real}} = Observable(zeros(5))
    vertices::Vector{Tuple{Real,Real}} = [
        (x, y) for (x, y) ∈ zip(xo[][1:(end - 1)], yo[][1:(end - 1)])
    ]
    white_rect = poly!(
        get_axes(gui)[:topo], vertices; color=:white, strokewidth=0, inspectable=false
    ) # Create a white background rectangle to hide lines from connections
    add_inspector_to_poly!(
        white_rect, (self, i, p) -> get_hover_string(get_system_node(design))
    )
    Makie.translate!(white_rect, 0, 0, get_var(gui, :z_translate_components))
    get_vars(gui)[:z_translate_components] += 1

    push!(design.plots, white_rect)

    # Observe changes in design coordinates and update box position
    on(design.xy; priority=3) do val
        x::Real = val[1]
        y::Real = val[2]

        xo[], yo[] = box(x, y, get_var(gui, :Δh) / 2)
        white_rect[1] = [(x, y) for (x, y) ∈ zip(xo[][1:(end - 1)], yo[][1:(end - 1)])]
    end

    box_boundary = lines!(
        get_axes(gui)[:topo],
        xo,
        yo;
        color=design.color,
        linewidth=get_var(gui, :linewidth),
        linestyle=linestyle,
        inspectable=false,
    )
    Makie.translate!(box_boundary, 0, 0, get_var(gui, :z_translate_components))
    get_vars(gui)[:z_translate_components] += 1
    push!(design.plots, box_boundary)
    box_boundary.kw[:EMGUI_obj] = design
    white_rect.kw[:EMGUI_obj] = design
end

"""
    draw_icon!(gui::GUI, design::EnergySystemDesign)

Draw an icon for EnergySystemDesign `design`.
"""
function draw_icon!(gui::GUI, design::EnergySystemDesign)
    xo::Observable{Vector{Real}} = Observable([0.0, 0.0])
    yo::Observable{Vector{Real}} = Observable([0.0, 0.0])
    xo_image = Observable(0.0 .. 0.0)
    yo_image = Observable(0.0 .. 0.0)
    on(design.xy; priority=3) do val
        x::Real = val[1]
        y::Real = val[2]

        xo[] = [
            x - get_var(gui, :Δh) * get_var(gui, :icon_scale) / 2,
            x + get_var(gui, :Δh) * get_var(gui, :icon_scale) / 2,
        ]
        yo[] = [
            y - get_var(gui, :Δh) * get_var(gui, :icon_scale) / 2,
            y + get_var(gui, :Δh) * get_var(gui, :icon_scale) / 2,
        ]
        xo_image[] = xo[][1] .. xo[][2]
        yo_image[] = yo[][1] .. yo[][2]
    end

    if isempty(design.icon) # No path to an icon has been found
        node::EMB.Node = if typeof(get_system_node(design)) <: EMB.Node
            get_system_node(design)
        else
            get_system_node(design).node
        end

        colors_input::Vector{RGB} = get_resource_colors(
            inputs(node), design.id_to_color_map
        )
        colors_output::Vector{RGB} = get_resource_colors(
            outputs(node), design.id_to_color_map
        )
        geometry::Symbol = if isa(node, Source)
            :rect
        elseif isa(node, Sink)
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
                if isa(node, NetworkNode)
                    θᵢ = (-1)^(j + 1) * π / 2 + π * (i - 1) / no_colors
                    θᵢ₊₁ = (-1)^(j + 1) * π / 2 + π * i / no_colors
                else
                    θᵢ = 2π * (i - 1) / no_colors
                    θᵢ₊₁ = 2π * i / no_colors
                end
                sector = get_sector_points()

                network_poly = poly!(
                    get_axes(gui)[:topo], sector; color=color, inspectable=false
                )
                add_inspector_to_poly!(
                    network_poly, (self, i, p) -> get_hover_string(get_system_node(design))
                )
                Makie.translate!(network_poly, 0, 0, get_var(gui, :z_translate_components))
                get_vars(gui)[:z_translate_components] += 1
                network_poly.kw[:EMGUI_obj] = design
                push!(design.plots, network_poly)
                on(design.xy; priority=3) do c
                    Δ = get_var(gui, :Δh) * get_var(gui, :icon_scale) / 2
                    sector = get_sector_points(; c, Δ, θ₁=θᵢ, θ₂=θᵢ₊₁, geometry=geometry)
                    network_poly[1][] = sector
                end
            end
        end

        if isa(node, NetworkNode)
            # Add a vertical white separation line to distinguis input resources from output resources
            center_box = lines!(
                get_axes(gui)[:topo],
                zeros(4),
                zeros(4);
                color=:black,
                linewidth=get_var(gui, :linewidth),
                inspector_label=(self, i, p) -> get_hover_string(get_system_node(design)),
                inspectable=true,
            )
            Makie.translate!(center_box, 0, 0, get_var(gui, :z_translate_components))
            get_vars(gui)[:z_translate_components] += 1
            center_box.kw[:EMGUI_obj] = design
            push!(design.plots, center_box)
            on(design.xy; priority=3) do center
                radius = get_var(gui, :Δh) * get_var(gui, :icon_scale) / 2
                x_coords, y_coords = box(center[1], center[2], radius / 4)
                center_box[1][] = Vector{Point{2,Float64}}([
                    [x, y] for (x, y) ∈ zip(x_coords, y_coords)
                ])
            end
        end
    else
        @debug "$(design.icon)"
        icon_image = image!(
            get_axes(gui)[:topo],
            xo_image,
            yo_image,
            rotr90(FileIO.load(design.icon));
            inspectable=false,
        )
        Makie.translate!(icon_image, 0, 0, get_var(gui, :z_translate_components))
        get_vars(gui)[:z_translate_components] += 1
        icon_image.kw[:EMGUI_obj] = design
        push!(design.plots, icon_image)
    end
end

"""
    draw_label!(gui::GUI, component::EnergySystemDesign)

Add a label to an `EnergySystemDesign` component.
"""
function draw_label!(gui::GUI, component::EnergySystemDesign)
    if haskey(component.system, :node)
        xo = Observable(0.0)
        yo = Observable(0.0)
        alignment = Observable((:left, :top))

        scale = 0.7

        on(component.xy; priority=3) do val
            x = val[1]
            y = val[2]

            if component.wall[] == :E
                xo[] = x + get_var(gui, :Δh) * scale
                yo[] = y
            elseif component.wall[] == :S
                xo[] = x
                yo[] = y - get_var(gui, :Δh) * scale
            elseif component.wall[] == :W
                xo[] = x - get_var(gui, :Δh) * scale
                yo[] = y
            elseif component.wall[] == :N
                xo[] = x
                yo[] = y + get_var(gui, :Δh) * scale
            end
            alignment[] = get_text_alignment(component.wall[])
        end

        node = component.system[:node]
        label = isa(node.id, Number) ? string(node) : string(node.id)

        # Check if and when there is investment in this node
        investment_times = []
        T = gui.design.system[:T]
        𝒯ᴵⁿᵛ = strategic_periods(T)
        capex_fields = get_var(gui, :descriptive_names)[:investment_indicators]
        model = get_model(gui)
        for t ∈ 𝒯ᴵⁿᵛ, capex_field ∈ capex_fields
            capex_key = Symbol(capex_field)
            if haskey(model, capex_key) &&
                !isempty(model[capex_key]) &&
                node ∈ axes(model[capex_key])[1]
                val = value(model[capex_key][node, t])
                if val > 0
                    push!(investment_times, t)
                end
            end
        end
        if isempty(investment_times)
            font_color = :black
        else
            font_color = :red
            label *= " (" * join(investment_times, ", ") * ")"
        end
        label_text = text!(
            get_axes(gui)[:topo],
            xo,
            yo;
            text=label,
            align=alignment,
            fontsize=get_var(gui, :fontsize),
            inspectable=false,
            color=font_color,
        )
        Makie.translate!(label_text, 0, 0, get_var(gui, :z_translate_components))
        get_vars(gui)[:z_translate_components] += 1
        label_text.kw[:EMGUI_obj] = component
        push!(get_plots(component), label_text)
    end
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
        Δ_lim_y < Δ_lim_x
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

    # Fix the axis limits (needed to avoid resetting limits when adding objects along
    # connection lines upon zoom)
    ax.autolimitaspect = nothing
end

"""
    update_title!(gui::GUI)

Update the title of `get_axes(gui)[:topo]` based on `get_design(gui)`.
"""
function update_title!(gui::GUI)
    design = get_design(gui)
    parent = get_parent(design)
    get_var(gui, :title)[] = if isnothing(parent)
        "top_level"
    else
        system = get_system(design)
        "$(parent).$(system[:node])"
    end
end

"""
    get_hover_string(element::Plotable)

Return the string for a EMB.Node/Area/Link/Transmission to be shown on hovering.
"""
function get_hover_string(element::Plotable)
    return string(nameof(typeof(element)))
end
