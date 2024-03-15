# Create a type for all Clickable objects in the gui.axes[:topo]
const Plotable = Union{Nothing, EMB.Node, EMB.Link, EMG.Area, EMG.Transmission} # Types that can trigger an update in the gui.axes[:results] plot

"""
    pixel_to_data(gui::GUI, pixel_size::Real)

Convert pixel size to data widths (in x- and y-direction)
"""
function pixel_to_data(gui::GUI, pixel_size::Real)
    # Calculate the range in data coordinates
    x_range::Float64 = gui.vars[:xlimits][][2] - gui.vars[:xlimits][][1]
    y_range::Float64 = gui.vars[:ylimits][][2] - gui.vars[:ylimits][][1]

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

Find the minimum distance between the nodes in the design object in gui and update Δh such that neighbouring icons do not overlap
"""
function update_distances!(gui::GUI)
    min_d::Float64 = Inf
    for component ∈ gui.design.components
        d::Float64 = minimum([norm(collect(component.xy[] .- component2.xy[])) for component2 ∈ gui.design.components if component != component2])
        if d < min_d
            min_d = d
        end
    end
    gui.vars[:minimum_distance] = min_d
    new_global_delta_h(gui)
end

"""
    new_global_delta_h(gui::GUI)

Recalculate the sizes of the boxes in gui.axes[:topo] such that their size is independent of zooming an resizing the window
"""
function new_global_delta_h(gui::GUI)
    xyWidths::Vec{2, Float32} = gui.axes[:topo].finallimits[].widths
    plot_widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
    gui.vars[:Δh][] = minimum([minimum(Vector(gui.vars[:Δh_px]*xyWidths./plot_widths)), gui.vars[:minimum_distance]/2])
end

"""
    get_change(::GUI, ::Val)

Handle different keyboard inputs (events) and return changes in x, y coordinates.
"""
get_change(::GUI, ::Val) = (0.0, 0.0)
get_change(gui::GUI, ::Val{Keyboard.up}) = (0.0, +gui.vars[:Δh][] / 5)
get_change(gui::GUI, ::Val{Keyboard.down}) = (0.0, -gui.vars[:Δh][] / 5)
get_change(gui::GUI, ::Val{Keyboard.left}) = (-gui.vars[:Δh][] / 5, 0.0)
get_change(gui::GUI, ::Val{Keyboard.right}) = (+gui.vars[:Δh][] / 5, 0.0)

"""
    align(gui::GUI, type::Symbol)

Align components in `gui.vars[:selected_systems]` either horizontally or vertically.
"""
function align(gui::GUI, type::Symbol)
    xs::Vector{Real} = Real[]
    ys::Vector{Real} = Real[]
    for sub_design ∈ gui.vars[:selected_systems]
        x, y = sub_design.xy[]
        push!(xs, x)
        push!(ys, y)
    end

    # Use the average of the components as the basis of the translated coordinate
    z::Real = if type == :horizontal
        sum(ys) / length(ys)
    elseif type == :vertical
        sum(xs) / length(xs)
    end

    for sub_design ∈ gui.vars[:selected_systems]
        x, y = sub_design.xy[]

        if type == :horizontal
            sub_design.xy[] = (x, z)
        elseif type == :vertical
            sub_design.xy[] = (z, y)
        end
    end
end

"""
    initialize_plot!(gui::GUI, design::EnergySystemDesign)

Initialize the plot of the topology
"""
function initialize_plot!(gui::GUI, design::EnergySystemDesign)
    for component ∈ design.components
        initialize_plot!(gui, component)
        add_component!(gui, component)
    end
    connect!(gui, design)
end

"""
    plot_design!(gui::GUI; visible::Bool = true)

Plot the topology of gui.design (only if not already available), and toggle visibility based on the optional argument `visible`
"""
function plot_design!(gui::GUI, design::EnergySystemDesign; visible::Bool = true, expandAll::Bool = true)
    for component ∈ design.components
        component_visibility::Bool = (component == gui.design) || expandAll
        plot_design!(gui, component; visible = component_visibility, expandAll)
    end
    if gui.design == design
        update_distances!(gui)
    end
    for component ∈ design.components
        for plotObj ∈ component.plotObj
            plotObj.visible = visible
        end
    end
    for connection ∈ design.connections
        for plotObjs ∈ connection[3][:plotObj]
            for plotObj ∈ plotObjs[]
                plotObj.visible = visible
            end
        end
    end
end

"""
    connect!(gui::GUI)

Draws lines between connected nodes/areas in gui.design.
"""
function connect!(gui::GUI, design::EnergySystemDesign)
    # Find optimal placement of label by finding the wall that has the least number of connections
    for component in design.components
        linkedToComponent::Vector{Connection} = filter(x -> component.system[:node].id == x[3][:connection].to.id, design.connections)
        linkedFromComponent::Vector{Connection} = filter(x -> component.system[:node].id == x[3][:connection].from.id, design.connections)
        on(component.xy, priority=4) do _
            angles::Vector{Float64} = vcat(
                [angle(component, linkedComponent[1]) for linkedComponent ∈ linkedToComponent],
                [angle(component, linkedComponent[2]) for linkedComponent ∈ linkedFromComponent]
            ) 
            min_angleDiff::Vector{Float64} = fill(Inf, 4)
            for i ∈ eachindex(min_angleDiff)
                for angle ∈ angles
                    Δθ = angle_difference(angle, (i-1)*π/2)
                    if min_angleDiff[i] > Δθ
                        min_angleDiff[i] = Δθ
                    end
                end
            end
            walls::Vector{Symbol} = [:E, :N, :W, :S]
            component.wall[] = walls[argmax(min_angleDiff)]
        end
        notify(component.xy)
    end
        
    for connection in design.connections
        # Check if link between two nodes goes in both directions (twoWay)
        connectionCon = connection[3][:connection]
        twoWay::Bool = false
        for connection2 in design.connections
            connection2Con = connection2[3][:connection]
            if connection2Con.to.id == connectionCon.from.id &&
                connection2Con.from.id == connectionCon.to.id
                twoWay = true
            end
        end

        # Plot line for connection with decorations
        connect!(gui, connection, twoWay)
    end
end

"""
    connect!(gui::GUI, connection::Tuple{EnergySystemDesign,EnergySystemDesign,Dict}, twoWay::Bool)

Draws lines between connected nodes/areas in gui.design.
"""
function connect!(gui::GUI, connection::Tuple{EnergySystemDesign,EnergySystemDesign,Dict}, twoWay::Bool)

    colors::Vector{RGB} = connection[3][:colors]
    noColors::Int64 = length(colors)

    # Create an arrow to highlight the direction of the energy flow
    l::Float64 = 1.0 # length of the arrow
    t::Float64 = 0.5 # half of the thickness of the arrow
    arrowParts::Vector{Makie.BezierPath} = Vector{Makie.BezierPath}(undef, noColors)
    for i ∈ range(1,noColors)
        arrowParts[i] = Makie.BezierPath([
            Makie.MoveTo(Makie.Point(0, 0)),
            Makie.LineTo(Makie.Point(-l, t*(2*(i-1)/noColors - 1))),
            Makie.LineTo(Makie.Point(-l, t*(2*i/noColors - 1))),
            Makie.ClosePath(),
        ])
    end

    # Allocate and store objects
    lineConnections::Observable{Vector{Any}} = Observable(Vector{Any}(undef, 0))
    arrowHeads::Observable{Vector{Any}} = Observable(Vector{Any}(undef, 0))
    push!(connection[3][:plotObj], lineConnections)
    push!(connection[3][:plotObj], arrowHeads)

    # Create function to be run on changes in connection[i].xy (for i = 1,2)
    update = () -> begin
        markersizeLengths::Tuple{Float64,Float64} = pixel_to_data(gui, gui.vars[:markersize])
        xy_1::Vector{Real} = collect(connection[1].xy[])
        xy_2::Vector{Real} = collect(connection[2].xy[])

        for i ∈ 1:length(lineConnections[])
            lineConnections[][i].visible = false
        end
        for i ∈ 1:length(arrowHeads[])
            arrowHeads[][i].visible = false
        end

        lines_shift::Tuple{Float64,Float64} = pixel_to_data(gui, gui.vars[:connectionLinewidth]) .+ pixel_to_data(gui, gui.vars[:line_sep_px])
        twoWay_sep::Tuple{Float64,Float64} = pixel_to_data(gui, gui.vars[:twoWay_sep_px][])
        θ::Float64 = atan(xy_2[2]-xy_1[2], xy_2[1]-xy_1[1])
        cosθ::Float64 = cos(θ)
        sinθ::Float64 = sin(θ)
        cosϕ::Float64 = -sinθ # where ϕ = θ+π/2
        sinϕ::Float64 = cosθ

        Δ::Float64 = gui.vars[:Δh][]/2 # half width of a box
        if !isempty(connection[1].components)
            Δ *= gui.vars[:parentScaling]
        end

        for j ∈ 1:noColors
            xy_start::Vector{Float64} = copy(xy_1)
            xy_end::Vector{Float64} = copy(xy_2)
            xy_midpoint::Vector{Float64} = copy(xy_2)
            if twoWay
                xy_start[1]   += (twoWay_sep[1]/2 + lines_shift[1]*(j-1))*cosϕ
                xy_start[2]   += (twoWay_sep[2]/2 + lines_shift[2]*(j-1))*sinϕ
                xy_end[1]     += (twoWay_sep[1]/2 + lines_shift[1]*(j-1))*cosϕ
                xy_end[2]     += (twoWay_sep[2]/2 + lines_shift[2]*(j-1))*sinϕ
                xy_midpoint[1] += (twoWay_sep[1]/2 + lines_shift[1]*(noColors-1)/2)*cosϕ
                xy_midpoint[2] += (twoWay_sep[2]/2 + lines_shift[2]*(noColors-1)/2)*sinϕ
            else
                xy_start[1]   += lines_shift[1]*(j-1)*cosϕ
                xy_start[2]   += lines_shift[2]*(j-1)*sinϕ
                xy_end[1]     += lines_shift[1]*(j-1)*cosϕ
                xy_end[2]     += lines_shift[2]*(j-1)*sinϕ
                xy_midpoint[1] += lines_shift[1]*(noColors-1)/2*cosϕ
                xy_midpoint[2] += lines_shift[2]*(noColors-1)/2*sinϕ
            end
            xy_start = square_intersection(xy_1, xy_start, θ, Δ)
            xy_end = square_intersection(xy_2, xy_end, θ+π, Δ)
            xy_midpoint = square_intersection(xy_2, xy_midpoint, θ+π, Δ)
            parm::Float64 = -xy_start[1]*cosθ - xy_start[2]*sinθ + xy_midpoint[1]*cosθ + xy_midpoint[2]*sinθ - minimum(markersizeLengths)
            xs::Vector{Float64} = [xy_start[1], parm*cosθ + xy_start[1]]
            ys::Vector{Float64} = [xy_start[2], parm*sinθ + xy_start[2]]
                
            if length(arrowHeads[]) < j
                sctr = scatter!(gui.axes[:topo], xy_midpoint[1], xy_midpoint[2], marker = arrowParts[j], markersize = gui.vars[:markersize], rotations = θ, color=colors[j], inspectable = false)
                lns = lines!(gui.axes[:topo], xs, ys; color = colors[j], linewidth = gui.vars[:connectionLinewidth], linestyle = get_style(gui,connection), inspector_label = (self, i, p) -> get_hover_string(connection[3][:connection]), inspectable = true)
                Makie.translate!(sctr, 0,0,1001)
                Makie.translate!(lns, 0,0,1000)
                push!(arrowHeads[], sctr)
                push!(lineConnections[], lns)
            else
                arrowHeads[][j][1][] = [Point{2, Float32}(xy_midpoint[1], xy_midpoint[2])]
                arrowHeads[][j][:rotations] = θ
                arrowHeads[][j].visible = true
                lineConnections[][j][1][] = [Point{2, Float32}(x, y) for (x, y) in zip(xs, ys)]
                lineConnections[][j].visible = true
            end
        end
    end

    # If components changes position, so must the connections
    for component in connection[1:2]
        on(component.xy, priority = 3) do _
            if component.plotObj[1].visible[]
                update()
            end
        end
    end
end

"""
    add_component!(gui::GUI, component::EnergySystemDesign)

Draw a box containing the icon and add a label with the id of the component with its type in parantheses
"""
function add_component!(gui::GUI, component::EnergySystemDesign)
    draw_box!(gui, component)
    draw_icon!(gui, component)
    draw_label!(gui, component)
end

"""
    get_style(gui::GUI, system::Dict)

Get the line style for an `EnergySystemDesign` object `system` based on its system properties.   
"""
function get_style(gui::GUI, system::Dict)
    if haskey(system,:node) && hasproperty(system[:node],:data)
        system_data = system[:node].data
        for data_element in eachindex(system_data)
            thistype = string(typeof(system_data[data_element]))
            if thistype == "InvData"
                return gui.vars[:investment_lineStyle]
            end
        end
    elseif haskey(system,:connection) && hasproperty(system[:connection],:modes)
        system_modes = system[:connection].modes
        for mode in eachindex(system_modes)
            this_mode = system_modes[mode]
            if hasproperty(this_mode,:data)
                system_data = this_mode.data
                for data_element in eachindex(system_data)
                    thistype = string(typeof(system_data[data_element]))
                    if thistype == "TransInvData"
                        return gui.vars[:investment_lineStyle]
                    end
                end
            end
        end
    end

    return :solid
end

"""
    get_style(gui::GUI, design::EnergySystemDesign)

Get the line style for an `EnergySystemDesign` object `design` based on its system properties.   
"""
get_style(gui::GUI, design::EnergySystemDesign) = get_style(gui, design.system)

"""
    get_style(gui::GUI, design::Connection)

Get the line style for an `Connection` object `connection` based on wheter it is part of an investment or not
"""
function get_style(gui::GUI, connection::Connection)
    style::Union{Symbol, Makie.Linestyle} = get_style(gui, connection[1])
    if style == gui.vars[:investment_lineStyle]
        return style
    end
    style = get_style(gui, connection[2])
    if style == gui.vars[:investment_lineStyle]
        return style
    end
    return get_style(gui, connection[3])
end

"""
    draw_box!(gui::GUI, design::EnergySystemDesign)

Draw a box for `design` and it's appearance, including style, color, size. 
"""
function draw_box!(gui::GUI, design::EnergySystemDesign)

    xo::Observable{Vector{Real}} = Observable(zeros(5))
    yo::Observable{Vector{Real}} = Observable(zeros(5))
    vertices::Vector{Tuple{Real,Real}} = [(x, y) for (x, y) in zip(xo[][1:end-1], yo[][1:end-1])]
    whiteRect = Observable(Makie.GeometryBasics.HyperRectangle{2, Int64})

    whiteRect = poly!(gui.axes[:topo], vertices, color=:white,strokewidth=0, inspectable = false) # Create a white background rectangle to hide lines from connections
    add_inspector_to_poly!(whiteRect, (self, i, p) -> get_hover_string(design.system[:node]))
    Makie.translate!(whiteRect, 0,0,1004)
    push!(design.plotObj, whiteRect)

    # Observe changes in design coordinates and update box position
    on(design.xy, priority = 3) do val
        x::Real = val[1]
        y::Real = val[2]

        xo[], yo[] = box(x, y, gui.vars[:Δh][]/2)
        whiteRect[1] = [(x, y) for (x, y) in zip(xo[][1:end-1], yo[][1:end-1])]
    end

    style::Union{Symbol,Makie.Linestyle} = get_style(gui, design)

    # if the design has components, draw an enlarged box around it. 
    if !isempty(design.components)
        xo2::Observable{Vector{Real}} = Observable(zeros(5))
        yo2::Observable{Vector{Real}} = Observable(zeros(5))
        vertices2::Vector{Tuple{Real,Real}} = [(x, y) for (x, y) in zip(xo2[][1:end-1], yo2[][1:end-1])]
        
        whiteRect2 = poly!(gui.axes[:topo], vertices2, color=:white,strokewidth=0, inspectable = false) # Create a white background rectangle to hide lines from connections
        add_inspector_to_poly!(whiteRect2, (self, i, p) -> get_hover_string(design.system[:node]))
        Makie.translate!(whiteRect2, 0,0,1001)
        push!(design.plotObj, whiteRect2)

        # observe changes in design coordinates and update enlarged box position
        on(design.xy, priority = 3) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, gui.vars[:Δh][]/2 * gui.vars[:parentScaling])
            whiteRect2[1] = [(x, y) for (x, y) in zip(xo2[][1:end-1], yo2[][1:end-1])]
        end


        boxBoundary2 = lines!(gui.axes[:topo], xo2, yo2; color = design.color, linewidth=gui.vars[:linewidth],linestyle = style, inspectable = false)
        Makie.translate!(boxBoundary2, 0,0,1002)
        push!(design.plotObj, boxBoundary2)
    end

    boxBoundary = lines!(gui.axes[:topo], xo, yo; color = design.color, linewidth=gui.vars[:linewidth],linestyle = style, inspectable = false)
    Makie.translate!(boxBoundary, 0,0,1005)
    push!(design.plotObj, boxBoundary)
end

"""
    draw_icon!(gui::GUI, design::EnergySystemDesign)

Draw an icon for `design`
"""
function draw_icon!(gui::GUI, design::EnergySystemDesign)
    xo::Observable{Vector{Real}} = Observable([0.0,0.0])
    yo::Observable{Vector{Real}} = Observable([0.0,0.0])
    on(design.xy, priority = 3) do val
        x::Real = val[1]
        y::Real = val[2]

        xo[] = [x - gui.vars[:Δh][] * gui.vars[:icon_scale]/2, x + gui.vars[:Δh][] * gui.vars[:icon_scale]/2]
        yo[] = [y - gui.vars[:Δh][] * gui.vars[:icon_scale]/2, y + gui.vars[:Δh][] * gui.vars[:icon_scale]/2]
    end

    if isempty(design.icon) # No path to an icon has been found
        node::EMB.Node = if typeof(design.system[:node]) <: EMB.Node
            design.system[:node] 
        else
            design.system[:node].node
        end

        colorsInput::Vector{RGB} = get_resource_colors(EMB.inputs(node), design.idToColorMap)
        colorsOutput::Vector{RGB} = get_resource_colors(EMB.outputs(node), design.idToColorMap)
        type::Symbol = if node isa EMB.Source 
            :rect 
        elseif node isa EMB.Sink 
            :circle
        else # assume NetworkNode
            :triangle
        end
        for (j, colors) ∈ enumerate([colorsInput, colorsOutput])
            noColors::Int64 = length(colors)
            for (i, color) ∈ enumerate(colors)
                θᵢ::Float64 = 0
                θᵢ₊₁::Float64 = 0
                if node isa EMB.NetworkNode # contains both input and output: Divide disc into two (left side for input and right side for output)
                    θᵢ = (-1)^(j+1)*π/2 + π*(i-1)/noColors
                    θᵢ₊₁ = (-1)^(j+1)*π/2 + π*i/noColors
                else
                    θᵢ = 2π*(i-1)/noColors
                    θᵢ₊₁ = 2π*i/noColors
                end
                sector = get_sector_points()

                networkPoly = poly!(gui.axes[:topo], sector, color=color, inspectable = false)
                add_inspector_to_poly!(networkPoly, (self, i, p) -> get_hover_string(design.system[:node]))
                Makie.translate!(networkPoly, 0,0,2001)
                push!(design.plotObj, networkPoly)
                on(design.xy, priority = 3) do c
                    Δ = gui.vars[:Δh][] * gui.vars[:icon_scale]/2
                    sector = get_sector_points(;c, Δ, θ₁ = θᵢ, θ₂ = θᵢ₊₁, type = type)
                    networkPoly[1][] = sector
                end
            end
        end

        if node isa EMB.NetworkNode
            # Add a vertical white separation line to distinguis input resources from output resources
            separationLine = lines!(gui.axes[:topo],zeros(4),zeros(4),color=:black,linewidth=gui.vars[:linewidth], inspector_label = (self, i, p) -> get_hover_string(design.system[:node]), inspectable = true)
            Makie.translate!(separationLine, 0,0,2002)
            push!(design.plotObj, separationLine)
            on(design.xy, priority = 3) do center
                radius = gui.vars[:Δh][] * gui.vars[:icon_scale]/2
                xCoords, yCoords = box(center[1], center[2], radius/4)
                separationLine[1][] = Vector{Point{2, Float32}}([[x,y] for (x,y) ∈ zip(xCoords, yCoords)])
            end
        end
    else
        @debug "$(design.icon)"
        icon_image = image!(gui.axes[:topo], xo, yo, rotr90(FileIO.load(design.icon)), inspectable = false)
        Makie.translate!(icon_image, 0,0,2000)
        push!(design.plotObj, icon_image)
    end
end

"""
    draw_label!(gui::GUI, component::EnergySystemDesign)

Add a label to a component
"""
function draw_label!(gui::GUI, component::EnergySystemDesign)

    xo = Observable(0.0)
    yo = Observable(0.0)
    alignment = Observable((:left, :top))

    scale = 0.7

    on(component.xy, priority = 3) do val

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
    if haskey(component.system,:node)
        node = component.system[:node]
        label = node.id isa Number ? string(node) : string(node.id)
        label_text = text!(gui.axes[:topo], xo, yo; text = label, align = alignment, fontsize=gui.vars[:fontsize], inspectable = false)
        Makie.translate!(label_text, 0,0,2001)
        push!(component.plotObj, label_text)
    end
end

"""
    clear_selection(gui::GUI)

Clear the color selection of components within 'gui.design' instance and to reset the `gui.vars[:selected_systems]` variable 
"""
function clear_selection(gui::GUI; clearTopo = true, clearResults = true)
    if clearTopo
        for selection in gui.vars[:selected_systems]
            toggle_selection_color!(gui, selection, false)
        end
        empty!(gui.vars[:selected_systems])
        update_available_data_menu!(gui, nothing) # Make sure the menu is updated
    end
    if clearResults
        for selection in gui.vars[:selected_plots]
            toggle_selection_color!(gui, selection, false)
        end
        empty!(gui.vars[:selected_plots])
    end
end

"""
    adjust_limits!(gui::GUI)

Adjust the limits of gui.axes[:topo] based on its content
"""
function adjust_limits!(gui::GUI)
    min_x, max_x, min_y, max_y = find_min_max_coordinates(gui.design)
    Δ_lim_x = max_x-min_x
    Δ_lim_y = max_y-min_y
    min_x -= Δ_lim_x*gui.vars[:boundary_add]
    max_x += Δ_lim_x*gui.vars[:boundary_add]
    min_y -= Δ_lim_y*gui.vars[:boundary_add]
    max_y += Δ_lim_y*gui.vars[:boundary_add]
    Δ_lim_x = max_x-min_x
    Δ_lim_y = max_y-min_y
    x_center = (min_x+max_x)/2
    y_center = (min_y+max_y)/2
    if Δ_lim_y > Δ_lim_x
        Δ_lim_x =  Δ_lim_y*gui.vars[:axAspectRatio]
    else Δ_lim_y < Δ_lim_x
        Δ_lim_y =  Δ_lim_x/gui.vars[:axAspectRatio]
    end
    min_x = x_center - Δ_lim_x/2
    max_x = x_center + Δ_lim_x/2
    min_y = y_center - Δ_lim_y/2
    max_y = y_center + Δ_lim_y/2
    gui.vars[:xlimits][] = [min_x, max_x]
    gui.vars[:ylimits][] = [min_y, max_y]
    limits!(gui.axes[:topo], gui.vars[:xlimits][], gui.vars[:ylimits][])

    gui.axes[:topo].autolimitaspect = nothing # Fix the axis limits (needed to avoid resetting limits when adding objects along connection lines upon zoom)
end

"""
    update_title!(gui::GUI)

Update the title of `gui.axes[:topo]` based on `gui.design`
"""
function update_title!(gui::GUI)
    gui.vars[:title][] = if isnothing(gui.design.parent)
        "TopLevel"
    else
        "$(gui.design.parent).$(gui.design.system[:node])"
    end
end

"""
    toggle_selection_color!(gui::GUI, selection::EnergySystemDesign, selected::Bool)

Set the color of selection to `gui.vars[:selection_color]` if selected, and its original color otherwise
"""
function toggle_selection_color!(gui::GUI, selection::EnergySystemDesign, selected::Bool)
    if selected
        selection.color[] = gui.vars[:selection_color]
    else
        selection.color[] = :black
    end
end

"""
    toggle_selection_color!(gui::GUI, plotObjs::Vector{Any}, selected::Bool)

Set the color of selection to `gui.vars[:selection_color]` if selected, and its original color otherwise
"""
function toggle_selection_color!(gui::GUI, selection::Dict{Symbol,Any}, selected::Bool)
    if selected
        for plotObj ∈ selection[:plotObj]
            for plotObj_sub ∈ plotObj[]
                plotObj_sub.color = gui.vars[:selection_color]
            end
        end
    else
        colors::Vector{RGB} = selection[:colors]
        noColors::Int64 = length(colors)
        for plotObj ∈ selection[:plotObj]
            for (i, plotObj_sub) ∈ enumerate(plotObj[])
                plotObj_sub.color = colors[((i-1) % noColors) + 1]
            end
        end
    end
end

"""
    toggle_selection_color!(gui::GUI, selection::Makie.Lines, selected::Bool)

Set the color of selection to `gui.vars[:selection_color]` if selected, and its original color otherwise
"""
function toggle_selection_color!(gui::GUI, selection::Makie.Lines, selected::Bool)
    if selected
        gui.vars[:originalPlotColor] = selection.color[]
        selection.color[] = gui.vars[:selection_color]
    else
        selection.color[] = gui.vars[:originalPlotColor]
    end
end

"""
    toggle_selection_color!(gui::GUI, selection::Makie.Combined, selected::Bool)

Set the color of selection to `gui.vars[:selection_color]` if selected, and its original color otherwise
"""
function toggle_selection_color!(gui::GUI, selection::Makie.Combined, selected::Bool)
    if selected
        gui.vars[:originalPlotColor] = selection.color[]
        selection.color[] = gui.vars[:selection_color]
    else
        selection.color[] = gui.vars[:originalPlotColor]
    end
    update_legend!(gui)
end

"""
    pick_component!(gui::GUI)

Check if a system is found under the mouse pointer is an `EnergySystemDesign` and update state variables
"""
function pick_component!(gui::GUI; pickTopoComponent = false, pickResultsComponent = false)
    plt, _ = pick(gui.fig)

    if isnothing(plt)
        clear_selection(gui; clearTopo = pickTopoComponent, clearResults = pickResultsComponent)
    else
        if pickTopoComponent
            # Loop through the design to find if the object under the pointer matches any of the object link to any of the components
            for component ∈ gui.design.components
                for plotObj ∈ component.plotObj
                    if plotObj === plt || plotObj === plt.parent || plotObj === plt.parent.parent
                        toggle_selection_color!(gui, component, true)
                        push!(gui.vars[:selected_systems], component)
                        return
                    end
                end
                if !isempty(component.components) && gui.vars[:expandAll]
                    for sub_component ∈ component.components
                        for plotObj ∈ sub_component.plotObj
                            if plotObj === plt || plotObj === plt.parent || plotObj === plt.parent.parent
                                toggle_selection_color!(gui, sub_component, true)
                                push!(gui.vars[:selected_systems], sub_component)
                                return
                            end
                        end
                    end
                end
                    
            end

            # Update the variables selections with the current selection
            for connection ∈ gui.design.connections
                for plotObj ∈ connection[3][:plotObj]
                    for plotObj_sub ∈ plotObj[]
                        if plotObj_sub === plt || plotObj_sub === plt.parent || plotObj_sub === plt.parent.parent
                            selection::Dict{Symbol,Any} = connection[3]
                            toggle_selection_color!(gui, selection, true)
                            push!(gui.vars[:selected_systems], selection)
                            return
                        end
                    end
                end
            end
            for component ∈ gui.design.components
                if !isempty(component.components) && gui.vars[:expandAll]
                    for connection ∈ component.connections
                        for plotObj ∈ connection[3][:plotObj]
                            for plotObj_sub ∈ plotObj[]
                                if plotObj_sub === plt || plotObj_sub === plt.parent || plotObj_sub === plt.parent.parent
                                    selection::Dict{Symbol,Any} = connection[3]
                                    toggle_selection_color!(gui, selection, true)
                                    push!(gui.vars[:selected_systems], selection)
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
        if pickResultsComponent
            for plotObj ∈ gui.axes[gui.menus[:time].selection[]].scene.plots
                if plotObj === plt || plotObj === plt.parent || plotObj === plt.parent.parent || plotObj === plt.parent.parent.parent
                    if !(plt ∈ gui.vars[:selected_plots])
                        toggle_selection_color!(gui, plotObj, true)
                        push!(gui.vars[:selected_plots], plotObj)
                    end
                    return
                end
            end
        end
    end
end

"""
    update!(gui::GUI)

Upon release of left mouse button update plots
"""
function update!(gui::GUI)
    selected_systems = gui.vars[:selected_systems]
    updateplot = !isempty(selected_systems)

    if updateplot
        update!(gui, selected_systems[end], updateplot = updateplot)
    else
        update!(gui, nothing; updateplot = updateplot)
    end
end

"""
    update!(gui::GUI, node::Plotable; updateplot::Bool = true)

Based on `node`, update the text in `gui.axes[:info]` and update plot in `gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, node::Plotable; updateplot::Bool = true)
    update_info_box!(gui, node)
    update_available_data_menu!(gui,node)
    if updateplot
        update_plot!(gui, node)
    end
end

"""
    update!(gui::GUI, connection::Dict{Symbol, Any}; updateplot::Bool = true)

Based on `connection[:connection]`, update the text in `gui.axes[:info]` and update plot in `gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, connection::Dict{Symbol, Any}; updateplot::Bool = true)
    update!(gui, connection[:connection]; updateplot)
end

"""
    update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool = true)

Based on `design.system[:node]`, update the text in `gui.axes[:info]` and update plot in `gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool = true)
    update!(gui, design.system[:node]; updateplot)
end

"""
    update_available_data_menu!(gui::GUI, node::Plotable)

Update the `gui.menus[:availableData]` with the available data of `node`.
"""
function update_available_data_menu!(gui::GUI, node::Plotable)
    # Find appearances of node/area/link/transmission in the model
    availableData = Vector{Dict}(undef,0)
    if !isempty(gui.model) # Plot results if available
        for dict ∈ collect(keys(object_dictionary(gui.model))) 
            if typeof(gui.model[dict]) <: JuMP.Containers.DenseAxisArray
                if any([eltype(a) <: Union{EMB.Node, EMG.Area} for a in axes(gui.model[dict])]) # nodes/areas found in structure 
                    if node ∈ gui.model[dict].axes[1] # only add dict if used by node (assume node are located at first Dimension)
                        if length(axes(gui.model[dict])) > 2
                            for res ∈ gui.model[dict].axes[3]
                                container = Dict(
                                    :name => string(dict), 
                                    :isJuMPdata => true, 
                                    :selection => [node, res],
                                )
                                add_description!(availableData, container, gui, dict)
                            end
                        else
                            container = Dict(
                                :name => string(dict), 
                                :isJuMPdata => true, 
                                :selection => [node],
                            )
                            add_description!(availableData, container, gui, dict)
                        end
                    end
                elseif any([eltype(a) <: EMG.TransmissionMode for a in axes(gui.model[dict])]) # nodes found in structure 
                    if node isa EMG.Transmission
                        for mode ∈ node.modes 
                            if mode ∈ gui.model[dict].axes[1] # only add dict if used by node (assume node are located at first Dimension)
                                container = Dict(
                                    :name => string(dict), 
                                    :isJuMPdata => true, 
                                    :selection => [mode],
                                ) # do not include node (<: EMG.Transmission) here as the mode is unique to this transmission
                                add_description!(availableData, container, gui, dict)
                            end
                        end
                    end
                elseif isnothing(node)
                    if length(axes(gui.model[dict])) > 1
                        for res ∈ gui.model[dict].axes[2]
                            container = Dict(
                                :name => string(dict), 
                                :isJuMPdata => true, 
                                :selection => [res],
                            )
                            add_description!(availableData, container, gui, dict)
                        end
                    else
                        container = Dict(
                            :name => string(dict), 
                            :isJuMPdata => true, 
                            :selection => EMB.Node[],
                        )
                        add_description!(availableData, container, gui, dict)
                    end
                end
            elseif typeof(gui.model[dict]) <: JuMP.Containers.SparseAxisArray
                if any([typeof(x) <: Union{EMB.Node, EMB.Link, EMG.Area} for x in first(gui.model[dict].data)[1]]) # nodes/area/links found in structure
                    if !isnothing(node)
                        extract_combinations!(gui, availableData, dict, node, gui.model)
                    end
                elseif isnothing(node)
                    extract_combinations!(gui, availableData, dict, node, gui.model)
                end
            end
        end
    end

    # Add timedependent input data (if available)
    if !isnothing(node)
        for fieldName ∈ fieldnames(typeof(node))
            field = getfield(node, fieldName)

            if typeof(field) <: TS.TimeProfile
                container = Dict(
                    :name => string(fieldName), 
                    :isJuMPdata => false, 
                    :selection => [node],
                    :fieldData => field,
                )
                structure = Symbol(nameof(typeof(node)))
                structure_field = fieldName
                add_description!(availableData, container, gui, structure, structure_field)
            elseif field isa Dict
                for (dictname, dictvalue) ∈ field
                    if typeof(dictvalue) <: TS.TimeProfile
                        container = Dict(
                            :name => "$fieldName.$dictname", 
                            :isJuMPdata => false, 
                            :selection => [node],
                            :fieldData => dictvalue,
                        )
                        structure = Symbol(nameof(typeof(node)))
                        structure_field = fieldName
                        add_description!(availableData, container, gui, structure, structure_field, dictname)
                    end
                end
            elseif field isa Vector{<:EMG.TransmissionMode}
                for mode ∈ field
                    for mode_fieldName ∈ fieldnames(typeof(mode))
                        mode_field = getfield(mode, mode_fieldName)
                        if typeof(mode_field) <: TS.TimeProfile
                            container = Dict(
                                :name => "$mode_fieldName", 
                                :isJuMPdata => false, 
                                :selection => [mode],
                                :fieldData => mode_field,
                            )
                            structure = Symbol(nameof(typeof(mode)))
                            structure_field = mode_fieldName
                            add_description!(availableData, container, gui, structure, structure_field)
                        end
                    end
                end
            elseif field isa Vector{Data}
                for data ∈ field
                    for data_fieldName ∈ fieldnames(typeof(data))
                        data_field = getfield(data, data_fieldName)
                        if typeof(data_field) <: TS.TimeProfile
                            container = Dict(
                                :name => "$fieldName.$data_fieldName", 
                                :isJuMPdata => false, 
                                :selection => [node],
                                :fieldData => data_field,
                            )
                            structure = Symbol(nameof(typeof(data)))
                            structure_field = data_fieldName
                            add_description!(availableData, container, gui, structure, structure_field)
                        end
                    end
                end
            end
        end
    end
    availableData_strings::Vector{String} = create_label.(availableData)

    gui.menus[:availableData].options = zip(availableData_strings, availableData)

    # Make sure an option is selected if the menu is altered
    #if isnothing(gui.menus[:availableData].selection[]) && !isempty(gui.menus[:availableData].options[])
    #    labels, _ =  collect(zip(gui.menus[:availableData].options[]...))
    #    lastViableLabelIndex = nothing
    #    for label ∈ gui.vars[:availableData_menu_history][]
    #        lastViableLabelIndex = findfirst(isequal(label), labels)
    #        if !isnothing(lastViableLabelIndex)
    #            break
    #        end
    #    end
    #    if !isnothing(lastViableLabelIndex)
    #        gui.menus[:availableData].i_selected[] = lastViableLabelIndex
    #    elseif isnothing(node) || length(gui.menus[:availableData].options[]) == 1
    #        gui.menus[:availableData].i_selected[] = 1
    #    end 
    #end
end

"""
    add_description!(availableData::Vector{Dict}, gui::GUI, structure::Symbol)

Update the container with a description if available, and add container to availableData.
"""
function add_description!(availableData::Vector{Dict}, container::Dict{Symbol, Any}, gui::GUI, dict::Symbol)
    try
        container[:description] = gui.vars[:descriptiveNames][:variables][dict]
    catch
        @warn "Could not find a description for the $dict dictionary. Using the string `$dict` instead."
    end
    push!(availableData, container)
end

"""
    add_description!(availableData::Vector{Dict}, gui::GUI, structure::Symbol, structure_field::Symbol)

Update the container with a description if available, and add container to availableData.
"""
function add_description!(availableData::Vector{Dict}, container::Dict{Symbol, Any}, gui::GUI, structure::Symbol, structure_field::Symbol)
    try
        container[:description] = gui.vars[:descriptiveNames][:structures][structure][structure_field]
    catch
        @warn "Could not find a description of $structure_field of the $structure structure. Using the string `$structure.$structure_field` instead"
    end
    push!(availableData, container)
end

"""
    add_description!(availableData::Vector{Dict}, gui::GUI, structure::Symbol, structure_field::Symbol, dictname::Symbol)

Update the container with a description if available, and add container to availableData.
"""
function add_description!(availableData::Vector{Dict}, container::Dict{Symbol, Any}, gui::GUI, structure::Symbol, structure_field::Symbol, dictname::Symbol)
    try
        container[:description] = gui.vars[:descriptiveNames][:structures][structure][structure_field][dictname]
    catch
        @warn "Could not find a description of $dictname in the $structure_field Dict of the $structure structure. Using the string `$structure_field.$dictname` instead"
    end
    push!(availableData, container)
end

"""
    get_data(model::JuMP.Model, selection::Dict{Symbol, Any}, T::TS.TimeStructure, period::Int64, scenario::Int64, representativePeriod::Int64)

Get the values from the JuMP `model` or the input data for at `selection` for all times `T` restricted to `period`
"""
function get_data(model::JuMP.Model, selection::Dict, T::TS.TimeStructure, period::Int64, scenario::Int64, representativePeriod::Int64)
    if selection[:isJuMPdata] # Model results
        return get_jump_values(model, Symbol(selection[:name]), selection[:selection], T, period, scenario, representativePeriod)
    else
        fieldData = selection[:fieldData]
        x_values, xType = get_time_values(T, typeof(fieldData), period, scenario, representativePeriod)
        if :vals ∈ fieldnames(typeof(fieldData))
            if fieldData isa TS.StrategicProfile
                if :vals ∈ fieldnames(typeof(fieldData.vals[period]))
                    y_values = fieldData.vals[period].vals
                else
                    y_values = [fieldData.vals[period].val]
                end
            elseif fieldData isa TS.ScenarioProfile
                if :vals ∈ fieldnames(typeof(fieldData.vals[scenario]))
                    y_values = fieldData.vals[scenario].vals
                else
                    y_values = [fieldData.vals[scenario].val]
                end
            elseif fieldData isa TS.RepresentativeProfile
                if :vals ∈ fieldnames(typeof(fieldData.vals[representativePeriod]))
                    y_values = fieldData.vals[representativePeriod].vals
                else
                    y_values = [fieldData.vals[representativePeriod].val]
                end
            else
                y_values = fieldData.vals
            end
        elseif :val ∈ fieldnames(typeof(fieldData))
            y_values = [fieldData.val]
        else
            @error "Could not extract y-data from structure"
        end
        return x_values, y_values, xType
    end
end

"""
    get_jump_values(model::JuMP.Model, dict::Symbol, selection::Vector{Any}, T::TS.TimeStructure, period::Int64, scenario::Int64, representativePeriod::Int64)

Get the values from the JuMP `model` for dictionary `dict` at `selection` for all times `T` restricted to `period`
"""
function get_jump_values(model::JuMP.Model, dict::Symbol, selection::Vector, T::TS.TimeStructure, period::Int64, scenario::Int64, representativePeriod::Int64)
    i_T, type = get_time_axis(model[dict])
    x_values, xType = get_time_values(T, type, period, scenario, representativePeriod)
    y_values::Vector{Float64} = if xType == :StrategicPeriod
        [value(model[dict][vcat(selection[1:i_T-1], t, selection[i_T:end])...]) for t ∈ TS.strat_periods(T)]
    elseif xType == :RepresentativePeriod
        [value(model[dict][vcat(selection[1:i_T-1], t, selection[i_T:end])...]) for t ∈ TS.repr_periods(T)]
    else
        if eltype(T.operational) <: TS.RepresentativePeriods
            [value(model[dict][vcat(selection[1:i_T-1], t, selection[i_T:end])...]) for t ∈ T if t.sp == period && t.period.rp == representativePeriod]
        elseif eltype(T.operational) <: TS.OperationalScenarios
            if eltype(T.operational[period].scenarios) <: TS.RepresentativePeriods
                [value(model[dict][vcat(selection[1:i_T-1], t, selection[i_T:end])...]) for t ∈ T if t.sp == period && t.period.sc == scenario && t.period.period.rp == representativePeriod]
            else
                [value(model[dict][vcat(selection[1:i_T-1], t, selection[i_T:end])...]) for t ∈ T if t.sp == period && t.period.sc == scenario]
            end
        else
            [value(model[dict][vcat(selection[1:i_T-1], t, selection[i_T:end])...]) for t ∈ T if t.sp == period]
        end
    end
    return x_values, y_values, xType
end

"""
    get_time_values(T::TS.TimeStructure, type::DataType, period::Int64, scenario::Int64, representativePeriod::Int64)

Get the time values for a given time type (TS.StrategicPeriod or TS.OperationalPeriod)
"""
function get_time_values(T::TS.TimeStructure, type::Type, period::Int64, scenario::Int64, representativePeriod::Int64)
    if type <: TS.StrategicPeriod
        return TS.strat_periods(T), :StrategicPeriod
    elseif type <: TS.TimeStructure{T} where T
        return TS.repr_periods(T), :RepresentativePeriod
    else
        if eltype(T.operational) <: TS.RepresentativePeriods
            return [t for t ∈ T if t.sp == period && t.period.rp == representativePeriod], :OperationalPeriod
        elseif eltype(T.operational) <: TS.OperationalScenarios
            if eltype(T.operational[period].scenarios) <: TS.RepresentativePeriods
                return [t for t ∈ T if t.sp == period && t.period.sc == scenario && t.period.period.rp == representativePeriod], :OperationalPeriod
            else
                return [t for t ∈ T if t.sp == period && t.period.sc == scenario], :OperationalPeriod
            end
        else
            return [t for t ∈ T if t.sp == period], :OperationalPeriod
        end
    end
end

"""
    get_time_axis(data::Union{JuMP.Containers.DenseAxisArray, JuMP.Containers.SparseAxisArray})

Get the index of the axis/column corresponding to TS.TimePeriod and return the specific type
"""
function get_time_axis(data::Union{JuMP.Containers.DenseAxisArray, JuMP.Containers.SparseAxisArray})
    types::Vector{Type} = collect(get_jump_axis_types(data))
    i_T::Union{Int64, Nothing} = findfirst(x -> x <: TS.TimePeriod || x <: TS.TimeStructure{T} where T, types)
    if isnothing(i_T)
        return i_T, nothing
    else
        return i_T, types[i_T]
    end
end

"""
    get_jump_axis_types(data::JuMP.Containers.DenseAxisArray)

Get the types for each axis in the Jump container DenseAxisArray
"""
function get_jump_axis_types(data::JuMP.Containers.DenseAxisArray)
    return eltype.(axes(data))
end

"""
    get_jump_axis_types(data::JuMP.Containers.SparseAxisArray)

Get the types for each column in the Jump container SparseAxisArray
"""
function get_jump_axis_types(data::JuMP.Containers.SparseAxisArray)
    return typeof.(first(data.data)[1])
end

"""
    create_label(selection::Vector{Any})

Return a label for a given selection to be used in the gui.menus[:availableData] menu
"""
function create_label(selection::Dict{Symbol, Any})
    label::String = selection[:isJuMPdata] ? "" : "Case data: "
    if haskey(selection, :description)
        label *= selection[:description] * " ($(selection[:name]))"
    else
        label *= selection[:name]
    end
    otherRes::Bool = false
    if length(selection) > 1
        for select ∈ selection[:selection]
            if !(select isa Plotable)
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

Based on `node` update the results in `gui.axes[:results]`
"""
function update_plot!(gui::GUI, node::Plotable)
    T = gui.root_design.system[:T]
    selection = gui.menus[:availableData].selection[]
    if !isnothing(selection)
        xlabel = "Time"
        if haskey(selection, :description)
            ylabel = selection[:description]
        else
            ylabel = selection[:name]
        end
        period = gui.menus[:period].selection[]
        representativePeriod = gui.menus[:representativePeriod].selection[]
        scenario = gui.menus[:scenario].selection[]

        t_values, y_values, xType = get_data(gui.model, selection, T, period, scenario, representativePeriod)

        label::String = create_label(selection)
        if !isnothing(node)
            label *= " for $node"
        end 
        if xType == :StrategicPeriod
            xlabel *= " (StrategicPeriod)"
        elseif xType == :RepresentativePeriod
            xlabel *= " (RepresentativePeriod)"
        elseif xType == :OperationalPeriod
            xlabel *= " (OperationalPeriod)"

            if eltype(T.operational) <: TS.RepresentativePeriods
                label *= " for strategic period $period and representative period $representativePeriod"
            else
                label *= " for strategic period $period"
            end
        end

        noPts = length(t_values)
        # For FixedProfiles, make sure the y_values are extended correspondingly to the x_values
        if noPts > length(y_values)
            y_values = vcat(y_values, fill(y_values[end], noPts - length(y_values)))
        end
        if xType == :OperationalPeriod
            x_values = get_op.(t_values)
            x_valuesStep, y_valuesStep = stepify(vec(x_values),vec(y_values))
            # For FixedProfile, make values constant over the operational period
            points = [Point{2, Float64}(x, y) for (x, y) ∈ zip(x_valuesStep,y_valuesStep)]
            custom_ticks = (0:noPts, string.(0:noPts))
            gui.menus[:time].i_selected[] = 3
        else
            points = [Point{2, Float64}(x, y) for (x, y) ∈ zip(1:noPts,y_values)]
            custom_ticks = (1:noPts, [string(t) for t in t_values])
            if xType == :StrategicPeriod
                gui.menus[:time].i_selected[] = 1
            else
                gui.menus[:time].i_selected[] = 2
            end
        end
        notify(gui.menus[:time].selection) # In case the new plot is on an other time type
        axisTimeType = gui.menus[:time].selection[]
        plotObjs = filter(x -> x isa Combined || x isa Lines, gui.axes[axisTimeType].scene.plots) # Only extract Lines and Combined (bars). Done to avoid Wireframe-objects
        
        plotObj = getfirst(x -> !(x ∈ [x[:plotObj] for x ∈ gui.vars[:pinnedPlots][axisTimeType]]) && !(x isa Wireframe), plotObjs) # check if there are any non-pinned plots that can be overwritten
        if isnothing(plotObj)
            plotObj = getfirst(x -> !x.visible[] && !(x isa Wireframe), plotObjs) # Overwrite a hidden plots
            if !isnothing(plotObj)
                push!(gui.vars[:visiblePlots][axisTimeType], Dict(:plotObj => plotObj, :name => selection[:name], :selection => selection[:selection], :t => t_values, :y => y_values))
            end
        else # overwrite non-pinned plot
            if !(plotObj ∈ [x[:plotObj] for x ∈ gui.vars[:visiblePlots][axisTimeType]])
                push!(gui.vars[:visiblePlots][axisTimeType], Dict(:plotObj => plotObj, :name => selection[:name], :selection => selection[:selection], :t => t_values, :y => y_values))
            end
        end

        if !isnothing(plotObj)
            plotObj[1][] = points
            plotObj.visible = true # If it has been hidden after a "Remove Plot" action
            plotObj.label = label
        else
            if xType == :OperationalPeriod
                plotObj = lines!(gui.axes[axisTimeType], points, label = label)
            else
                n_visible = length(gui.vars[:visiblePlots][axisTimeType]) + 1
                plotObj = barplot!(gui.axes[axisTimeType], points, dodge = n_visible*ones(Int, length(points)), n_dodge = n_visible, strokecolor = :black, strokewidth = 1, label = label)
            end
            push!(gui.vars[:visiblePlots][axisTimeType], Dict(:plotObj => plotObj, :name => selection[:name], :selection => selection[:selection], :t => t_values, :y => y_values))
        end
        update_barplot_dodge!(gui)
        if all(y_values .≈ 0)
            toggle_inspector!(plotObj, false) # Deactivate inspector for bars to avoid issue with wireframe when selecting a bar with values being zero
        end

        if isempty(gui.vars[:resultsLegend]) # Initialize the legend box
            push!(gui.vars[:resultsLegend], axislegend(gui.axes[axisTimeType], [plotObj], [label], labelsize = gui.vars[:fontsize])) # Add legends inside axes[:results] area
        else
            update_legend!(gui)
        end

        if xType == :OperationalPeriod
            gui.axes[axisTimeType].xticks = Makie.automatic
        else
            gui.axes[axisTimeType].xticks = custom_ticks 
        end
        gui.axes[axisTimeType].xlabel = xlabel
        gui.axes[axisTimeType].ylabel = ylabel
        update_limits!(gui)
    end
end

"""
    update_limits!(gui::GUI)

Update the limits based on the visible plots of type `axisTimeType`
"""
function update_limits!(gui::GUI)
    axisTimeType = gui.menus[:time].selection[]
    autolimits!(gui.axes[axisTimeType])
    yorigin::Float32 = gui.axes[axisTimeType].finallimits[].origin[2]
    ywidth::Float32 = gui.axes[axisTimeType].finallimits[].widths[2]
    ylims!(gui.axes[axisTimeType], yorigin, yorigin + ywidth*1.1) # ensure that the legend box does not overlap the data
end

"""
    update_legend!(gui::GUI)

Update the legend based on the visible plots of type `axisTimeType`
"""
function update_legend!(gui::GUI)
    axisTimeType = gui.menus[:time].selection[]
    if !isempty(gui.vars[:resultsLegend])
        gui.vars[:resultsLegend][1].entrygroups[] = [
            (nothing, 
            [LegendEntry(x[:plotObj].label, x[:plotObj], gui.vars[:resultsLegend][1]) for x ∈ gui.vars[:visiblePlots][axisTimeType]],
            )
        ]
    end
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `connection[:connection]` update the results in `gui.axes[:results]`
"""
function update_plot!(gui::GUI, connection::Dict{Symbol,Any})
    update_plot!(gui, connection[:connection])
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `design.system[:node]` update the results in `gui.axes[:results]`
"""
function update_plot!(gui::GUI, design::EnergySystemDesign)
    update_plot!(gui, design.system[:node])
end

"""
    update_info_box!(gui::GUI, node; indent::Int64 = 0)

Based on `node` update the text in `gui.axes[:info]`
"""
function update_info_box!(gui::GUI, node; indent::Int64 = 0)
    infoBox = gui.axes[:info].scene.plots[1][1]
    if isnothing(node)
        infoBox[] = gui.vars[:defaultText]
        return
    end
    if indent == 0
        infoBox[] =  "$node ($(typeof(node)))\n"
    end
    indent += 1
    indent_str = "  " ^ indent
    isIterable(x) = x isa Vector || x isa Dict || typeof(x) <: EMB.Node || typeof(x) <: EMB.Resource
    if node isa Vector
        for (i,field1) ∈ enumerate(node)
            if isIterable(field1)
                infoBox[] *= indent_str * "$i: $(typeof(field1)):\n"
                update_info_box!(gui, field1; indent)
            else
                infoBox[] *= indent_str * "$i: $(typeof(field1))\n"
            end
        end
    elseif node isa Dict
        for field1 ∈ keys(node)
            infoBox[] *= indent_str * "$field1 => $(node[field1])\n"
        end
    else
        for field1 ∈ fieldnames(typeof(node))
            value1 = getfield(node,field1)
            if isIterable(value1)
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

Return the string for a Node/Area/Link/Transmission to be shown on hovering
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
        axisTimeType = gui.menus[:time].selection[]
        n_visible = length(gui.vars[:visiblePlots][axisTimeType])
        for x ∈ gui.vars[:visiblePlots][axisTimeType]
            x[:plotObj].n_dodge = n_visible
        end
    end
end