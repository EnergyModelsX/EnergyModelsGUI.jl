##########################################################################################################################
# Set global variables
Δh = Observable(0.05) # Half of sidelength of main box
alternatingColors = Observable(true)
coarseCoastLines = false
Δh_px = 50              # Pixel size of a box for nodes
markersize = 15         # Marker size for arrows in connections
boundary_add = 0.12     # Relative to the xlim/ylim-dimensions, expand the axis
linewidth = 2           # Width of the line around boxes
line_sep_px = 2         # Separation (in px) between lines for connections
repeatColors = 2        # Scale to repeat colors (resources) for a connection
connectionLinewidth = 2 # line width of connection lines
axAspectRatio = 1.0     # Aspect ratio for the topology plotting area
axWidth = 1350          # No pixels for the width of the topology plotting area
fontsize = 12           # General font size (in px)
noArrows = 12           # Scale to adjust number of arrows along a connection 
parentScaling = 1.2     # Scale for enlargement of boxes around main boxes for nodes for parent systems
noPtsCircle = 100       # No points for when plotting circle or arcs
twoWay_sep_px = Observable(6) # No pixels between set of lines for nodes having connections both ways
selection_color = :green2 # Colors for box boundaries when selection objects
investment_lineStyle = Linestyle([1.0, 1.5, 2.0, 2.5].*5) # linestyle for investment connections and box boundaries for nodes

# gobal variables for legends
colorBoxPadding_px = 25         # Padding around the legends
colorBoxesWidth_px = 20         # Width of the rectangles for the colors in legends
colorBoxesHeight_px = fontsize  # Height of the rectangles for the colors in legends
colorBoxesSep_px = 5            # Separation between rectangles 
boxTextSep_px = 5               # Separation between rectangles for colors and text

on(alternatingColors) do x
    twoWay_sep_px[] = x ? 6 : 10
end
notify(alternatingColors)
plot_widths = Observable(Vector{Int64}([800,700]))
icon_scale = 0.8 # scale icons w.r.t. the surrounding box in fraction of Δh

xlimits = Observable(Vector{Float64}([0.0,1.0]))
ylimits = Observable(Vector{Float64}([0.0,1.0]))
dragging = Ref(false)
is_ctrl_pressed = Ref(false)

# Create an arrow to highlight the direction of the energy flow
arrow = BezierPath([
    MoveTo(Point(0, 0)),
    LineTo(Point(-1.0, -0.3)),
    LineTo(Point(-1.0, 0.3)),
    ClosePath(),
])
# Create half an arrow to highlight the direction of the energy flow for cases with two way flow
halfArrow = BezierPath([
    MoveTo(Point(0, 0)),
    LineTo(Point(-1.0, 0.0)),
    LineTo(Point(-1.0, 0.5)),
    ClosePath(),
])

##########################################################################################################################

"""
    pixel_to_data(pixel_size::Real)

Convert pixel size to data widths (in x- and y-direction)
"""
function pixel_to_data(pixel_size::Real)
    # Calculate the range in data coordinates
    x_range = xlimits[][2] - xlimits[][1]
    y_range = ylimits[][2] - ylimits[][1]
    # Calculate the conversion factor
    x_factor = x_range / plot_widths[][1]
    y_factor = y_range / plot_widths[][2]
    # Convert pixel size to data coordinates
    return (pixel_size * x_factor, pixel_size * y_factor)
end

"""
    Find the min max coordinates, this could be use to fix the map focus on the specified region.
"""
function find_min_max_coordinates(component::EnergySystemDesign,min_x::Number, max_x::Number, min_y::Number, max_y::Number)
    if component.xy !== nothing && haskey(component.system,:node)
        x, y = component.xy[]
        min_x = min(min_x, x)
        max_x = max(max_x, x)
        min_y = min(min_y, y)
        max_y = max(max_y, y)
    end
    
    for child in component.components
        min_x, max_x, min_y, max_y = find_min_max_coordinates(child, min_x, max_x, min_y, max_y)
    end
    
    return min_x, max_x, min_y, max_y
end

function find_min_max_coordinates(root::EnergySystemDesign)
    return find_min_max_coordinates(root, Inf, -Inf, Inf, -Inf)
end

function new_global_delta_h(ax::Axis)
    xyWidths = ax.finallimits[].widths
    plot_widths = ax.scene.px_area[].widths
    global Δh[] = minimum(Vector(Δh_px*xyWidths./plot_widths))
end

function new_global_delta_h(design::EnergySystemDesign)
    min_x, max_x, min_y, max_y = find_min_max_coordinates(design)
    global Δh[] = max(0.005*sqrt((max_x-min_x)^2+(max_y-min_y)^2),0.05)
    return min_x, max_x, min_y, max_y
end

"""
    This function updates the wall field for a pair of EnergySystemDesign's based on their relative location to each other. This is done to 
        reduce lines crossing over boxes

    Parameters:
    - `component_design_from::EnergySystemDesign: An instance of a EnergySystemDesign from which the connection originates
    - `component_design_to::EnergySystemDesign: An instance of a EnergySystemDesign from which the connection ends

"""
function facingWalls(component_design_from::EnergySystemDesign, component_design_to::EnergySystemDesign)
    xy_from = component_design_from.xy[]
    xy_to = component_design_to.xy[]
    θ = atan(xy_to[2]-xy_from[2], xy_to[1]-xy_from[1])
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
    Functions handling different keyboard inputs (events) and return changes in x, y coordinates.
"""
get_change(::Val) = (0.0, 0.0)
get_change(::Val{Keyboard.up}) = (0.0, +Δh[] / 5)
get_change(::Val{Keyboard.down}) = (0.0, -Δh[] / 5)
get_change(::Val{Keyboard.left}) = (-Δh[] / 5, 0.0)
get_change(::Val{Keyboard.right}) = (+Δh[] / 5, 0.0)

"""
    Function to get the opposite wall symbol

    Parameters:
    - `wall::Symbol`: A symbol for a wall (i.e., :E as in East) 

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
Function to align certain components within an 'EnergySystemDesign' instance either horizontally or vertically.
"""
function align(design::EnergySystemDesign, type)
    xs = Real[]
    ys = Real[]
    for sub_design in design.components
        if sub_design.color[] == selection_color
            x, y = sub_design.xy[]
            push!(xs, x)
            push!(ys, y)
        end
    end

    ym = sum(ys) / length(ys)
    xm = sum(xs) / length(xs)

    for sub_design in design.components
        if sub_design.color[] == selection_color

            x, y = sub_design.xy[]

            if type == :horizontal
                sub_design.xy[] = (x, ym)
            elseif type == :vertical
                sub_design.xy[] = (xm, y)
            end


        end
    end
end
"""
Draws lines between connected objects in design.

    Parameters:
    - `ax::Axis`: An instance of the `Axis` (or similar) type for performing the actual connection.
    - `design::EnergySystemDesign`: An instance of the `EnergySystemDesign` struct representing the design.

"""
function connect!(ax::Axis, design::EnergySystemDesign)
    topLevel = haskey(design.system,:areas) && haskey(design.system,:transmission)

    for component in design.components
        linkedToComponent = filter(x -> component.system[:node].id == x[3][:connection].to.id, design.connections)
        linkedFromComponent = filter(x -> component.system[:node].id == x[3][:connection].from.id, design.connections)
        on(component.xy, priority=4) do val
            wallCounter = Dict(:E => 0, :N => 0, :W => 0, :S => 0)
            for linkedComponent in linkedToComponent
                wall_from, wall_to = facingWalls(component, linkedComponent[1])
                wallCounter[wall_from] += 1
            end
            for linkedComponent in linkedFromComponent
                wall_from, wall_to = facingWalls(component, linkedComponent[2])
                wallCounter[wall_from] += 1
            end
            minConnections, min_wall = findmin(wallCounter)
            maxConnections, max_wall = findmax(wallCounter)
            opposite_max_wall = getOppositeWall(max_wall)
            if wallCounter[opposite_max_wall] == minConnections
                component.wall[] = opposite_max_wall
            else
                component.wall[] = min_wall
            end
        end
        notify(component.xy)
    end
        
    for connection in design.connections
        
        # Check if link between two nodes goes in both directions (twoWay)
        connectionCon = connection[3][:connection]
        twoWay = false
        for connection2 in design.connections
            connection2Con = connection2[3][:connection]
            if connection2Con.to.id == connectionCon.from.id &&
                connection2Con.from.id == connectionCon.to.id
                twoWay = true
            end
        end

        # Plot line for connection with decorations
        connect!(ax, connection, twoWay)
    end
end
"""
     Calculate the intersection point between a line starting at x_start and direction described by θ
     and a square with half side lengths Δ centered at center
"""
function squareIntersection(center::Vector{T}, x_start::Vector{T}, θ::T, Δ::T) where T<:Real
    
    # Ensure that -π ≤ θ ≤ π
    θ = θ > π ? θ-2π : θ
    θ = θ < -π ? θ+2π : θ

    # Calculate angles at the corers of the square with respect to the point x_start
    θ_se = atan(center[2]-Δ-x_start[2], center[1]+Δ-x_start[1])
    θ_ne = atan(center[2]+Δ-x_start[2], center[1]+Δ-x_start[1])
    θ_nw = atan(center[2]+Δ-x_start[2], center[1]-Δ-x_start[1])
    θ_sw = atan(center[2]-Δ-x_start[2], center[1]-Δ-x_start[1])

    # Return the intersection point
    if θ_se <= θ && θ < θ_ne # Facing walls are (:E, :W)
        return [center[1]+Δ, center[2] + (center[1]+Δ-x_start[1])*tan(θ)]
    elseif θ_ne <= θ && θ < θ_nw # Facing walls are (:N, :S)
        return [center[1] + (center[2]+Δ-x_start[2])/tan(θ), center[2]+Δ]
    elseif θ_sw <= θ && θ < θ_se # Facing walls are (:S, :N)
        return [center[1] + (center[2]-Δ-x_start[2])/tan(θ), center[2]-Δ]
    else # Facing walls are (:W, :E)
        return [center[1]-Δ, center[2] + (center[1]-Δ-x_start[1])*tan(θ)]
    end
end

"""
     Compute the l2-norm of a vector.
"""
function norm(x::Vector{T}) where T<:Real
    return sqrt(sum(x.^2))
end
"""
     Function to add a line connecting/updating 2 components.
"""
function connect!(ax::Axis, connection::Tuple{EnergySystemDesign,EnergySystemDesign,Dict}, twoWay::Bool)

    colors = connection[3][:colors]
    noColors = length(colors)
    xs = Observable(Float64[])
    ys = Observable(Float64[])

    lineConnections = Observable(Vector{Any}(undef, 0))
    halfArrows = Observable(Vector{Any}(undef, 0))
    update = () -> begin
        axDiagonalLength = norm(collect(ax.finallimits[].widths))
        xy_1 = collect(connection[1].xy[])
        xy_2 = collect(connection[2].xy[])
        lineLength = norm(xy_2-xy_1)
        repeatColorsLoc = noColors == 1 ? 1 : max(Int(round(repeatColors*lineLength/axDiagonalLength)),1)
        colorsRep = repeat(colors,repeatColorsLoc)
        noLinePts = noColors*repeatColorsLoc+1
        for i ∈ 1:length(lineConnections[])
            lineConnections[][i].visible = false
        end
        for i ∈ 1:length(halfArrows[])
            halfArrows[][i].visible = false
        end
        noArrowsSegment = noColors == 1 ? max(Int(round(noArrows/repeatColorsLoc*lineLength/axDiagonalLength)),1) :
                                          max(Int(round(noArrows/repeatColorsLoc*(lineLength/axDiagonalLength)^2)),1)
        placeArrows(x) = noArrowsSegment == 1 ? [x[2]] : collect(range(x[1] + (x[2]-x[1])/noArrowsSegment, x[2], noArrowsSegment))
        if alternatingColors[]
            xy_start = xy_1
            xy_end = xy_2
            twoWay_sep = pixel_to_data(twoWay_sep_px[])
            θ = atan(xy_end[2]-xy_start[2], xy_end[1]-xy_start[1])
            if twoWay
                xy_start[1] += twoWay_sep[1]/2*cos(θ+π/2)
                xy_start[2] += twoWay_sep[2]/2*sin(θ+π/2)
                xy_end[1]   += twoWay_sep[1]/2*cos(θ+π/2)
                xy_end[2]   += twoWay_sep[2]/2*sin(θ+π/2)
                marker = halfArrow
            else
                marker = arrow
            end
            Δ = Δh[]/2
            if !isempty(connection[1].components)
                Δ *= parentScaling
            end
            Δ = Δ-pixel_to_data(connectionLinewidth/2)[1] # Ensure that the endpoints of the line are fully covered by the square
            xy_start = squareIntersection(xy_1, xy_start, θ, Δ)
            xy_end = squareIntersection(xy_2, xy_end, θ+π, Δ)
            lineParametrization(t) = xy_start .+ (xy_end .- xy_start).*t 
            for (i,t) ∈ enumerate(range(0,1,noLinePts))
                xy = lineParametrization(t)
                if length(xs[]) < i
                    push!(xs[], xy[1])
                else
                    xs[][i] = xy[1]
                end
                if length(ys[]) < i
                    push!(ys[], xy[2])
                else
                    ys[][i] = xy[2]
                end
            end
                
            for i ∈ 1:noLinePts-1
                x_lines = xs[][i:i+1]
                y_lines = ys[][i:i+1]
                x_halfArrows = placeArrows(x_lines)
                y_halfArrows = placeArrows(y_lines)
                if i > 1000
                    @error "Too many object being plotted. It is here assumed that this is because of the GeoMakie zooming bug"
                end
                if length(halfArrows[]) < i
                    sctr = scatter!(ax, x_halfArrows, y_halfArrows, marker = marker, markersize = markersize, rotations = θ, color=colorsRep[i])
                    lns = lines!(ax, x_lines, y_lines; color = colorsRep[i], linewidth = connectionLinewidth, linestyle = get_style(connection))
                    GLMakie.translate!(sctr, 0,0,1000)
                    GLMakie.translate!(lns, 0,0,1000)
                    push!(halfArrows[], sctr)
                    push!(lineConnections[], lns)
                else
                    halfArrows[][i][1][] = [Point{2, Float32}(x, y) for (x, y) in zip(x_halfArrows, y_halfArrows)] 
                    halfArrows[][i][:rotations] = θ
                    halfArrows[][i].visible = true
                    lineConnections[][i][1][] = [Point{2, Float32}(x, y) for (x, y) in zip(x_lines, y_lines)]
                    lineConnections[][i].visible = true
                end
            end
        else
            lineConnections = Vector{Any}(undef, noColors)
            for i ∈ 1:noColors
                lineConnections[i] = lines!(ax, xs[], ys[]; color = colorsRep[i], linewidth=connectionLinewidth)
                GLMakie.translate!(lineConnections[i], 0,0,1000)
            end

            for i ∈ 1:noColors
                lineConnections[i].linestyle = get_style(connection)
            end
            empty!(xs[])
            empty!(ys[])
            for component ∈ connection[1:2]
                push!(xs[], component.xy[][1])
                push!(ys[], component.xy[][2])
            end
            θ = atan(ys[][end]-ys[][1], xs[][end]-xs[][1])
            lines_shift = pixel_to_data(connectionLinewidth) .+ pixel_to_data(line_sep_px)
            if twoWay
                twoWay_sep = pixel_to_data(twoWay_sep_px[])
            else
                twoWay_sep = .- pixel_to_data((noColors-1)*(line_sep_px + connectionLinewidth))
            end
            x = Vector(xs[])
            y = Vector(ys[])
            for i ∈ 1:noColors
                x .= xs[] .+ (twoWay_sep[1]/2 + lines_shift[1]*(i-1))*cos(θ+π/2)
                y .= ys[] .+ (twoWay_sep[2]/2 + lines_shift[2]*(i-1))*sin(θ+π/2)
                lineConnections[i][1][][1] = [x[1], y[1]]
                lineConnections[i][1][][2] = [x[2], y[2]]
                notify(lineConnections[i][1])
            end
            notify(xs)
            notify(ys)

            # Update the direcitonal arrows along the lines
            halfArrows[:rotations] = θ 
            halfArrows[1] = placeArrows(x)
            halfArrows[2] = placeArrows(y)
            #notify(halfArrows)

        end
    end


    for component in connection[1:2]
        on(component.xy) do val
            update()
        end
    end
end


"""
    Positioning nodes and their labels based on specific directions.
"""
get_node_position(w::Symbol, delta, i) = get_node_position(Val(w), delta, i)
get_node_label_position(w::Symbol, x, y) = get_node_label_position(Val(w), x, y)

get_node_position(::Val{:N}, delta, i) = (delta * i - Δh[], +Δh[])
get_node_label_position(::Val{:N}, x, y) = (x + Δh[] / 10, y + Δh[] / 5)

get_node_position(::Val{:S}, delta, i) = (delta * i - Δh[], -Δh[])
get_node_label_position(::Val{:S}, x, y) = (x + Δh[] / 10, y - Δh[] / 5)

get_node_position(::Val{:E}, delta, i) = (+Δh[], delta * i - Δh[])
get_node_label_position(::Val{:E}, x, y) = (x + Δh[] / 5, y)

get_node_position(::Val{:W}, delta, i) = (-Δh[], delta * i - Δh[])
get_node_label_position(::Val{:W}, x, y) = (x - Δh[] / 5, y)


"""
    Adding components
"""
function add_component!(ax::Axis, component::EnergySystemDesign)

    draw_box!(ax, component)
    draw_icon!(ax, component)
    draw_label!(ax, component)

end

"""
    Text allignment
"""
get_text_alignment(wall::Symbol) = get_text_alignment(Val(wall))
get_text_alignment(::Val{:E}) = (:left, :center)
get_text_alignment(::Val{:W}) = (:right, :center)
get_text_alignment(::Val{:S}) = (:center, :top)
get_text_alignment(::Val{:N}) = (:center, :bottom)

"""
    Get the line style for an `EnergySystemDesign` object based on its system properties.   
"""
function get_style(system::Dict)
    if haskey(system,:node) && hasproperty(system[:node],:data)
        system_data = system[:node].data
        for data_element in eachindex(system_data)
            thistype = string(typeof(system_data[data_element]))
            if thistype == "InvData"
                return investment_lineStyle
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
                        return investment_lineStyle
                    end
                end
            end
        end
    end

    return :solid
end
get_style(design::EnergySystemDesign) = get_style(design.system)
function get_style(connection::Tuple{EnergySystemDesign,EnergySystemDesign,Dict})
    style = get_style(connection[1])
    if style == investment_lineStyle
        return style
    end
    style = get_style(connection[2])
    return style
end


"""
    Function for drawing a box and it's appearance, including style, color, size. 
"""
function draw_box!(ax::Axis, design::EnergySystemDesign)

    xo = Observable(zeros(5))
    yo = Observable(zeros(5))
    vertices = [(x, y) for (x, y) in zip(xo[][1:end-1], yo[][1:end-1])]
    #whiteRect = Observable(GLMakie.GeometryBasics.HyperRectangle{2, Int64})
    #xy_ll = Observable(zeros(2)) # Coordinate for box corner at lower left

    whiteRect = poly!(ax, vertices, color=:white,strokewidth=0) # Create a white background rectangle to hide lines from connections
    GLMakie.translate!(whiteRect, 0,0,1004)
    push!(design.plotObj, whiteRect)

    # Observe changes in design coordinates and update box position
    on(design.xy) do val
        x = val[1]
        y = val[2]

        xo[], yo[] = box(x, y, Δh[]/2)
        whiteRect[1] = [(x, y) for (x, y) in zip(xo[][1:end-1], yo[][1:end-1])]
    end

    style = get_style(design)

    # if the design has components, draw an enlarged box around it. 
    if !isempty(design.components)
        xo2 = Observable(zeros(5))
        yo2 = Observable(zeros(5))
        vertices = [(x, y) for (x, y) in zip(xo2[][1:end-1], yo2[][1:end-1])]
        
        whiteRect2 = poly!(ax, vertices, color=:white,strokewidth=0) # Create a white background rectangle to hide lines from connections
        GLMakie.translate!(whiteRect2, 0,0,1002)
        push!(design.plotObj, whiteRect2)

        # observe changes in design coordinates and update enlarged box position
        on(design.xy) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, Δh[]/2 * parentScaling)
            whiteRect2[1] = [(x, y) for (x, y) in zip(xo2[][1:end-1], yo2[][1:end-1])]
        end


        boxBoundary2 = lines!(ax, xo2, yo2; color = design.color, linewidth=linewidth,linestyle = style)
        GLMakie.translate!(boxBoundary2, 0,0,1001)
    end

    boxBoundary = lines!(ax, xo, yo; color = design.color, linewidth=linewidth,linestyle = style)
    GLMakie.translate!(boxBoundary, 0,0,1005)


end

"""
    Get points for the boundary of a sector defined by the center, radius, θ₁ and θ₂ 
"""
function getSectorPoints(;center::Tuple{Real,Real} = (0.0,0.0), radius::Real = 1.0, θ₁::Real = 0, θ₂::Real = π/4, steps::Int=100)
    θ = LinRange(θ₁, θ₂, Int(round(steps*(θ₂-θ₁)/(2π))))
    x = radius * cos.(θ) .+ center[1]
    y = radius * sin.(θ) .+ center[2]
    
    # Include the center and close the polygon
    return [center; collect(zip(x, y)); center]
end


function draw_icon!(ax::Axis, design::EnergySystemDesign)
    xo = Observable(zeros(2))
    yo = Observable(zeros(2))
    on(design.xy) do val
        x = val[1]
        y = val[2]

        xo[] = [x - Δh[] * icon_scale/2, x + Δh[] * icon_scale/2]
        yo[] = [y - Δh[] * icon_scale/2, y + Δh[] * icon_scale/2]
    end

    if isnothing(design.icon)
        node = design.system[:node] 
        if typeof(node) <: EnergyModelsGeography.Area
            node = node.node
        end

        if typeof(node) <: EnergyModelsBase.Sink
            resourcesInput = node.input
            hexColors = [haskey(design.idToColorsMap,resource.id) ? design.idToColorsMap[resource.id] : missingColor for resource ∈ keys(resourcesInput)]
            colors = [parse(Colorant, hex_color) for hex_color ∈ hexColors]
            sinkPoly = scatter!(ax, design.xy, markersize=Δh_px, color=colors[1])
            push!(design.plotObj, sinkPoly)
            GLMakie.translate!(sinkPoly, 0,0,2000)
        elseif typeof(node) <: EnergyModelsBase.NetworkNode
            if typeof(node) <: EnergyModelsBase.Availability
                resourcesInput = node.input
                resourcesOutput = node.output
            else
                resourcesInput = keys(node.input)
                resourcesOutput = keys(node.output)
            end

            hexColorsInput = [haskey(design.idToColorsMap,resource.id) ? design.idToColorsMap[resource.id] : missingColor for resource ∈ resourcesInput]
            colorsInput = [parse(Colorant, hex_color) for hex_color ∈ hexColorsInput]
            hexColorsOutput = [haskey(design.idToColorsMap,resource.id) ? design.idToColorsMap[resource.id] : missingColor for resource ∈ resourcesOutput]
            colorsOutput = [parse(Colorant, hex_color) for hex_color ∈ hexColorsOutput]
            for (j, colors) ∈ enumerate([colorsInput, colorsOutput])
                noColors = length(colors)
                for (i, color) ∈ enumerate(colors)
                    θᵢ = (-1)^(j+1)*π/2 + π*(i-1)/noColors
                    θᵢ₊₁ = (-1)^(j+1)*π/2 + π*i/noColors
                    sector = getSectorPoints()

                    networkPoly = poly!(ax, sector, color=color)
                    GLMakie.translate!(networkPoly, 0,0,2000)
                    push!(design.plotObj, networkPoly)
                    on(design.xy, priority = 3) do center
                        radius = Δh[] * icon_scale/2
                        sector = getSectorPoints(center = center, radius = radius, θ₁ = θᵢ, θ₂ = θᵢ₊₁)
                        networkPoly[1][] = sector
                    end
                end
            end

            # Add a vertical white separation line to distinguis input resources from output resources
            separationLine = lines!([0.0,1.0],[0.0,1.0],color=:white,linewidth=Δh_px/25)
            GLMakie.translate!(separationLine, 0,0,2001)
            push!(design.plotObj, separationLine)
            on(design.xy) do center
                radius = Δh[] * icon_scale/2
                separationLine[1][] = Vector{Point{2, Float32}}([[center[1], center[2]-radius], [center[1], center[2]+radius]])
            end

        elseif typeof(node) <: EnergyModelsBase.Source
            resourcesOutput = node.output
            hexColors = [haskey(design.idToColorsMap,resource.id) ? design.idToColorsMap[resource.id] : missingColor for resource ∈ keys(resourcesOutput)]
            colors = [parse(Colorant, hex_color) for hex_color ∈ hexColors]
            box = Rect2{Float64}([0.0, 0.0], [1.0, 1.0])
            sourcePoly = poly!(ax, box, color=colors[1])
            on(xo) do _
                sourcePoly[1][] = Rect2{Float64}([xo[][1], yo[][1]],
                                                 [xo[][2] - xo[][1], yo[][2] - yo[][1]])
            end
            notify(xo)
            GLMakie.translate!(sourcePoly, 0,0,2000)
            push!(design.plotObj, sourcePoly)
        end
    else
        icon_image = image!(ax, xo, yo, rotr90(load(design.icon)))
        GLMakie.translate!(icon_image, 0,0,2000)
        push!(design.plotObj, icon_image)
    end
end

function draw_label!(ax::Axis, component::EnergySystemDesign)

    xo = Observable(0.0)
    yo = Observable(0.0)
    alignment = Observable((:left, :top))

    scale = 0.7

    on(component.xy) do val

        x = val[1]
        y = val[2]

        if component.wall[] == :E
            xo[] = x + Δh[] * scale
            yo[] = y
        elseif component.wall[] == :S
            xo[] = x
            yo[] = y - Δh[] * scale
        elseif component.wall[] == :W
            xo[] = x - Δh[] * scale
            yo[] = y
        elseif component.wall[] == :N
            xo[] = x
            yo[] = y + Δh[] * scale
        end
        alignment[] = get_text_alignment(component.wall[])

    end
    if haskey(component.system,:node)
        label_text = text!(ax, xo, yo; text = "$(string(component.system[:node]))\n($(typeof(component.system[:node])))", align = alignment, fontsize=fontsize)
        GLMakie.translate!(label_text, 0,0,1007)
    end
end


function box(x, y, Δh_)

    xs = [x + Δh_, x - Δh_, x - Δh_, x + Δh_, x + Δh_]
    ys = [y + Δh_, y + Δh_, y - Δh_, y - Δh_, y + Δh_]

    return xs, ys
end

"""
    Function to clear the color selection of components within 'EnergySystemDesign' instance. 
"""
function clear_selection(design::EnergySystemDesign)
    for component in design.components
        component.color[] = :black
    end
end

"""
    Define the main function to view the topology
"""
function view(design::EnergySystemDesign) 
    view(design,design,true)
end

function updateSubSystemLocations!(design::EnergySystemDesign, Δ::Tuple{Real,Real})
    for component ∈ design.components
        component.xy[] = component.xy[] .+ Δ
    end
end
function adjustLimits(min_x,max_x,min_y,max_y)
    Δ_lim_x = max_x-min_x
    Δ_lim_y = max_y-min_y
    min_x -= Δ_lim_x*boundary_add
    max_x += Δ_lim_x*boundary_add
    min_y -= Δ_lim_y*boundary_add
    max_y += Δ_lim_y*boundary_add
    if Δ_lim_y > Δ_lim_x
        Δ_lim_x =  Δ_lim_y*axAspectRatio
        x_center = (min_x+max_x)/2
        min_x = x_center - Δ_lim_x/2
        max_x = x_center + Δ_lim_x/2
    else Δ_lim_y < Δ_lim_x
        Δ_lim_y =  Δ_lim_x/axAspectRatio
        y_center = (min_y+max_y)/2
        min_y = y_center - Δ_lim_y/2
        max_y = y_center + Δ_lim_y/2
    end
    return min_x,max_x,min_y,max_y
end
function view(design::EnergySystemDesign,root_design::EnergySystemDesign,interactive = true)
    min_x, max_x, min_y, max_y = new_global_delta_h(design)
    if interactive
        GLMakie.activate!(inline=false)
    else
        CairoMakie.activate!()
    end

    title = if isnothing(design.parent)
        "TopLevel [$(design.file)]"
    else
        "$(design.parent).$(string(design.system[:node])) [$(design.file)]"
    end
    min_x, max_x, min_y, max_y = adjustLimits(min_x,max_x,min_y,max_y)

    xlimits[] = [min_x, max_x]
    ylimits[] = [min_y, max_y]

    # Create a figure
    fig = Figure(resolution = (axWidth, axWidth/axAspectRatio))
    if haskey(root_design.system,:areas) # Use GeoMakie 
        source = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        dest   = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        ax = GeoAxis(
            fig[2:11, 1:10],
            source = source, 
            dest = dest,
            coastlines = coarseCoastLines,  # You can set this to true if you want coastlines
            lonlims = Tuple(xlimits[]),
            latlims = Tuple(ylimits[]),
            backgroundcolor=:lightblue1,
        )

        if !coarseCoastLines

            # Define the URL and the local file path
            url = "https://datahub.io/core/geo-countries/r/countries.geojson"
            temp_dir = tempdir()  # Get the system's temporary directory
            filename = "EnergyModelsGUI_countries.geojson"
            local_file_path = joinpath(temp_dir, filename)

            # Download the file if it doesn't exist
            if !isfile(local_file_path)
                Base.download(url, local_file_path)
            end

            # Now read the data from the file
            countries = GeoJSON.read(read(local_file_path, String))
            poly!(ax, countries; color = :honeydew, colormap = :dense,
                strokecolor = :gray50, strokewidth = 0.5,
            )
        end
    else
        ax = Axis(
            fig[2:11, 1:10],
            aspect = DataAspect(),
        )
        limits!(ax, xlimits[], ylimits[])
    end

    colorBoxes = Vector{Any}(undef,0)
    colorLegends = Vector{Any}(undef,0)
    for (i, (desc, color)) in enumerate(root_design.idToColorsMap)
        box = Rect2{Float64}([0.0, 0.0], [1.0, 1.0])
        push!(colorBoxes, poly!(ax, box, color=color))
        push!(colorLegends, text!(ax, 0.0, 0.0, text=desc, fontsize=fontsize))
        GLMakie.translate!(colorBoxes[i], 0,0,1000)
        GLMakie.translate!(colorLegends[i], 0,0,1000)
    end

    if interactive
        GLMakie.Label(fig[12, 1], "Tips:\n ctrl+left-click to select multiple nodes (use arrows to move all nodes simultaneously).\n right-click and drag to pan\n scroll wheel to zoom"; 
                      fontsize = fontsize)
        #lineConnectionType_menu = Menu(fig[12, 3], options = ["Multiple lines", "Single line"], default = "Multiple lines", fontsize = fontsize)
        align_horizontal_button = GLMakie.Button(fig[12, 4]; label = "align horz.", fontsize = fontsize)
        align_vertical_button = GLMakie.Button(fig[12, 5]; label = "align vert.", fontsize = fontsize)
        open_button = GLMakie.Button(fig[12, 6]; label = "open", fontsize = fontsize)
        up_button = GLMakie.Button(fig[12, 7]; label = "navigate up", fontsize = fontsize)
        save_button = GLMakie.Button(fig[12, 8]; label = "save", fontsize = fontsize)
        resetView_button = GLMakie.Button(fig[12, 9]; label = "reset view", fontsize = fontsize)
        GLMakie.Label(fig[1, :], title; halign = :center, fontsize = fontsize)
    end

    connect!(ax, design)
    
    for component in design.components
        add_component!(ax,component)
    end

    notifyComponents = () -> begin
        for component ∈ design.components
            notify(component.xy)
        end
    end

    new_global_delta_h(ax)
    on(ax.scene.px_area) do _
        notifyComponents()
    end
    on(ax.finallimits) do _
        notifyComponents()
    end
    on(alternatingColors) do _
        notifyComponents()
    end

    if interactive
        on(ax.finallimits, priority = 9) do finallimits
            widths = finallimits.widths
            origin = finallimits.origin
            xlimits[] = [origin[1], origin[1] + widths[1]]
            ylimits[] = [origin[2], origin[2] + widths[2]]
            new_global_delta_h(ax)
            notifyComponents()
            for (i, colorBox) ∈ enumerate(colorBoxes)
                padding = pixel_to_data(colorBoxPadding_px)
                colorBoxesWidth = pixel_to_data(colorBoxesWidth_px)[1]
                colorBoxesHeight = pixel_to_data(colorBoxesHeight_px)[2]
                colorBoxesSep = pixel_to_data(colorBoxesSep_px)[2]
                boxTextSep = pixel_to_data(boxTextSep_px)[1]
                colorBox[1][] = Rect2{Float64}([xlimits[][1] + padding[1], 
                                                ylimits[][2] - padding[2] - colorBoxesHeight - (i-1)*(colorBoxesSep+colorBoxesHeight)], 
                                                [colorBoxesWidth, colorBoxesHeight])
                colorLegends[i][1][] = [Point{2, Float32}(xlimits[][1] + padding[1] + colorBoxesWidth + boxTextSep,
                                                          ylimits[][2] - padding[2] - colorBoxesHeight - (i-1)*(colorBoxesSep+colorBoxesHeight))]
            end
        end
        on(ax.scene.px_area, priority = 9) do _
            # Get the size of the axis in pixels
            plot_widthsTuple = ax.scene.px_area[].widths
            plot_widths[] = collect(plot_widthsTuple)
            # Get the current limits of the axis
            new_global_delta_h(ax)
            notifyComponents()
            notify(ax.finallimits)
        end
        # Event handler for keyboard events
        on(events(ax.scene).keyboardbutton, priority=2) do event

            if Int(event.key) == 341 || Int(event.key) == 345 # left_control
                if event.action == Keyboard.press
                    is_ctrl_pressed[] = true
                elseif event.action == Keyboard.release
                    is_ctrl_pressed[] = false
                end
            end
        end
        # Event handler for mouse button events
        on(events(fig).mousebutton, priority = 2) do event

            mouse_pos = events(ax).mouseposition[]
            plot_origin = pixelarea(ax.scene)[].origin
            plot_widths = pixelarea(ax.scene)[].widths
            mouse_pos_loc = mouse_pos .- plot_origin
            clickOutsidePlot = any(mouse_pos_loc .< 0) || any(mouse_pos_loc .- plot_widths .> 0)
            if clickOutsidePlot
                return
            end
            if event.button == Mouse.left
                if event.action == Mouse.press
                    if !is_ctrl_pressed[]
                        clear_selection(design)
                    end

                    # if Keyboard.s in events(fig).keyboardstate
                    # Delete marker
                    plt, i = pick(fig)

                    if isnothing(plt)
                        clear_selection(design)
                    else
                        selected_system = EnergyModelsGUI.EnergySystemDesign[]
                        system_found = false
                        for component ∈ design.components
                            for plotObj ∈ component.plotObj
                                if plotObj === plt || plotObj === plt.parent || plotObj === plt.parent.parent
                                    selected_system = push!(selected_system,component)
                                    system_found = true
                                    break
                                end
                            end
                            if system_found 
                                break
                            end
                        end
                        if !isempty(selected_system)
                            selected_system[1].color[] = selection_color
                        end
                    end
                    dragging[] = true
                    Consume(true)
                elseif event.action == Mouse.release

                    dragging[] = false
                    Consume(true)
                end
            end
            if event.button == Mouse.right
                if event.action == Mouse.press
                    clear_selection(design)
                    Consume(true)
                elseif event.action == Mouse.release
                end
            end

            return Consume(false)
        end

        on(events(ax).mouseposition, priority = 2) do mouse_pos
            if dragging[]
                for sub_design in design.components
                    if sub_design.color[] == selection_color
                        xy_widths = collect(ax.finallimits[].widths)
                        xy_origin = collect(ax.finallimits[].origin)
                        plot_origin = collect(pixelarea(ax.scene)[].origin)
                        plot_widths = collect(pixelarea(ax.scene)[].widths)
                        mouse_pos_loc = mouse_pos .- plot_origin
                        xy = xy_origin .+ mouse_pos_loc .* xy_widths ./ plot_widths

                        # Make sure box is within the x- and y-limits
                        for i = 1:2
                            if xy[i] < xy_origin[i]
                                xy[i] = xy_origin[i]
                            end
                        end
                        outOfSceneMin = xy .< xy_origin
                        outOfSceneMax = xy .> xy_origin .+ xy_widths

                        xy[outOfSceneMin] = xy_origin[outOfSceneMin]
                        xy[outOfSceneMax] = xy_origin[outOfSceneMax] .+ xy_widths[outOfSceneMax]
                        updateSubSystemLocations!(sub_design, Tuple(xy .- sub_design.xy[]))
                        sub_design.xy[] = Tuple(xy)

                        notifyComponents()
                        break #only move onedd system for mouse drag
                    end
                end

                return Consume(true)
            end

            return Consume(false)
        end

        on(events(fig).keyboardbutton) do event
            if event.action == Keyboard.press

                change = get_change(Val(event.key))

                if change != (0.0, 0.0)
                    for sub_design in design.components
                        if sub_design.color[] == selection_color

                            xc = sub_design.xy[][1]
                            yc = sub_design.xy[][2]

                            sub_design.xy[] = (xc + change[1], yc + change[2])

                            updateSubSystemLocations!(sub_design, Tuple(change))
                        end
                    end

                    reset_limits!(ax)

                    notifyComponents()
                    return Consume(true)
                end
            end
        end

        on(align_horizontal_button.clicks, priority=10) do clicks
            align(design, :horizontal)
        end

        on(align_vertical_button.clicks, priority=10) do clicks
            align(design, :vertical)
        end

        on(open_button.clicks, priority=10) do clicks
            for component in design.components
                if component.color[] == selection_color && component.parent == :Toplevel
                    view_design = component
                    view_design.parent = if haskey(design.system,:name) design.system[:name]
                    else Symbol("TopLevel")
                    end
                    view(component,root_design)
                    break
                end
            end
        end

        on(up_button.clicks, priority=10) do clicks
            view(root_design)
        end
        on(save_button.clicks, priority=10) do clicks
            save_design(design)
        end
        on(resetView_button.clicks, priority=10) do clicks
            min_x, max_x, min_y, max_y = new_global_delta_h(design)
            min_x, max_x, min_y, max_y = adjustLimits(min_x,max_x,min_y,max_y)
            xlims!(ax, min_x, max_x)
            ylims!(ax, min_y, max_y)
            notify(ax.finallimits)
        end
    end

    notify(ax.scene.px_area)
    display(fig)
    return fig
end