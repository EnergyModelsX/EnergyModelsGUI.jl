# Set global variables
Δh = Observable(0.05) # Half of sidelength of main box
alternatingColors = true
coarseCoastLines = false
Δh_px = 50
markersize = 15
dragging = Ref(false)
boundary_add = 0.5
linewidth = 2
line_sep_px = 2
repeatColors = 4
connectionLinewidth = 3 
twoWay_sep_px = alternatingColors ? 6 : 10
xlimits = Observable(Vector{Float64}([0.0,1.0]))
ylimits = Observable(Vector{Float64}([0.0,1.0]))
plot_widths = Observable(Vector{Int64}([800,700]))
icon_scale = 0.8 # fraction of Δh


# Create half an arrow to highlight the direction of the energy flow
halfArrow = BezierPath([
    MoveTo(Point(0, 0)),
    LineTo(Point(-1.0, 0.0)),
    LineTo(Point(-1.0,0.5)),
    ClosePath(),
])

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
    Function to find the min max coordinates, this could be use to fix the map focus on the specified region.
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
    Check if 2 tuple values are approximately equal within a specified tolerance.
    Parameters:
    - `a::Tuple{Real, Real}`: The first tuple.
    - `b::Tuple{Real, Real}`: The second tuple to compare.
    - `atol::Real`: The absolute tolerance for the comparison
"""
function is_tuple_approx(a::Tuple{Real,Real}, b::Tuple{Real,Real}; atol)

    r1 = isapprox(a[1], b[1]; atol)
    r2 = isapprox(a[2], b[2]; atol)

    return all([r1, r2])
end


"""
Function to align certain components within an 'EnergySystemDesign' instance either horizontally or vertically.
"""
function align(design::EnergySystemDesign, type)
    xs = Real[]
    ys = Real[]
    for sub_design in design.components
        if sub_design.color[] == :pink
            x, y = sub_design.xy[]
            push!(xs, x)
            push!(ys, y)
        end
    end

    ym = sum(ys) / length(ys)
    xm = sum(xs) / length(xs)

    for sub_design in design.components
        if sub_design.color[] == :pink

            x, y = sub_design.xy[]

            if type == :horrizontal
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
        if topLevel
            linkedToComponent = filter(x -> component.system[:node].id == x[3][:connection].To.id, design.connections)
            linkedFromComponent = filter(x -> component.system[:node].id == x[3][:connection].From.id, design.connections)
        else
            linkedToComponent = filter(x -> component.system[:node].id == x[3][:connection].to.id, design.connections)
            linkedFromComponent = filter(x -> component.system[:node].id == x[3][:connection].from.id, design.connections)
        end
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
            if topLevel
                if connection2Con.To.id == connectionCon.From.id &&
                   connection2Con.From.id == connectionCon.To.id
                    twoWay = true
                end
            else
                if connection2Con.to.id == connectionCon.from.id &&
                   connection2Con.from.id == connectionCon.to.id
                    twoWay = true
                end
            end
        end

        # Plot line for connection with decorations
        connect!(ax, connection, twoWay)
    end
end
# 

"""
     Function to add a line connecting/updating 2 components.
"""
function connect!(ax::Axis, connection::Tuple{EnergySystemDesign,EnergySystemDesign,Dict}, twoWay::Bool)

    colors = connection[3][:colors]
    colorsRep = repeat(colors,repeatColors)
    noColors = length(colors)
    noLinePts = noColors*repeatColors+1
    if alternatingColors
        xs = Observable(zeros(noLinePts))
        ys = Observable(zeros(noLinePts))
    else    
        xs = Observable(zeros(2))
        ys = Observable(zeros(2))
    end

    noArrows = 6 
    placeArrows(x) = range(x[1] + 1.0*(x[2]-x[1])/(noArrows+2), x[2] - 1.1*(x[2]-x[1])/(noArrows+2), noArrows)
    halfArrows = scatter!(placeArrows(xs[]),placeArrows(ys[]),marker = halfArrow,markersize = markersize, rotations = 0, color=:black)
    translate!(halfArrows, 0,0,1000)
    if alternatingColors
        lineConnections = Vector{Any}(undef, noLinePts)
        for i ∈ 1:noLinePts-1
            lineConnections[i] = lines!(ax, xs[][i:i+1], ys[][i:i+1]; color = colorsRep[i], linewidth=connectionLinewidth)
            translate!(lineConnections[i], 0,0,1000)
        end

        update = () -> begin
            for i ∈ 1:noLinePts-1
                lineConnections[i].linestyle = get_style(connection)
            end
            empty!(xs[])
            empty!(ys[])
            xy_start = collect(connection[1].xy[])
            xy_end = collect(connection[2].xy[])
            lineParametrization(t) = xy_start .+ (xy_end .- xy_start).*t 
            for t ∈ range(0,1,noLinePts)
                xy = lineParametrization(t)
                push!(xs[], xy[1])
                push!(ys[], xy[2])
            end
            θ = atan(ys[][end]-ys[][1], xs[][end]-xs[][1])
            twoWay_sep = pixel_to_data(twoWay_sep_px)
            if twoWay
                xs[] .+= twoWay_sep[1]/2*cos(θ+π/2)
                ys[] .+= twoWay_sep[2]/2*sin(θ+π/2)
            end
            for i ∈ 1:noLinePts-1
                lineConnections[i][1] = xs[][i:i+1]
                lineConnections[i][2] = ys[][i:i+1] 
            end
            notify(xs)
            notify(ys)

            # Update the direcitonal arrows along the lines
            halfArrows[:rotations] = θ 
            halfArrows[1] = placeArrows(xs[][[1,end]]) 
            halfArrows[2] = placeArrows(ys[][[1,end]])

        end
    else
        lineConnections = Vector{Any}(undef, noColors)
        for i ∈ 1:noColors
            lineConnections[i] = lines!(ax, xs[], ys[]; color = colorsRep[i], linewidth=connectionLinewidth)
            translate!(lineConnections[i], 0,0,1000)
        end

        update = () -> begin
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
                twoWay_sep = pixel_to_data(twoWay_sep_px)
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
    on(ax.scene.px_area) do val
        update()
    end
    on(ax.finallimits) do _
        update()
    end

    update()

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
    if haskey(system,:node) && hasproperty(system[:node],:Data)
        system_data = system[:node].Data
        for data_element in eachindex(system_data)
            thistype = string(typeof(system_data[data_element]))
            if thistype == "InvData"
                return :dash
            end
        end
    
    elseif haskey(system,:connection) && hasproperty(system[:connection],:Modes)
        system_modes = system[:connection].Modes
        for mode in eachindex(system_modes)
            this_mode = system_modes[mode]
            if hasproperty(this_mode,:Data)
                system_data = this_mode.Data
                for data_element in eachindex(system_data)
                    thistype = string(typeof(system_data[data_element]))
                    if thistype == "TransInvData"
                        return :dash
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
    if style == :dash
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
    translate!(whiteRect, 0,0,1004)

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
        translate!(whiteRect2, 0,0,1002)

        # observe changes in design coordinates and update enlarged box position
        on(design.xy) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, Δh[] * 0.6)
            whiteRect2[1] = [(x, y) for (x, y) in zip(xo2[][1:end-1], yo2[][1:end-1])]
        end


        boxBoundary2 = lines!(ax, xo2, yo2; color = design.color, linewidth=linewidth,linestyle = style)
        translate!(boxBoundary2, 0,0,1001)
    end

    boxBoundary = lines!(ax, xo, yo; color = design.color, linewidth=linewidth,linestyle = style)
    translate!(boxBoundary, 0,0,1005)


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

    if !isnothing(design.icon)
        icon_image = image!(ax, xo, yo, rotr90(load(design.icon)))
        translate!(icon_image, 0,0,2000)
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
        label_text = text!(ax, xo, yo; text = "$(string(component.system[:node]))\n($(typeof(component.system[:node])))", align = alignment)
        translate!(label_text, 0,0,1007)
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

function view(design::EnergySystemDesign,root_design::EnergySystemDesign,interactive = true)
    min_lon, max_lon, min_lat, max_lat = new_global_delta_h(design)
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

    # Create a figure
    fig = Figure(resolution = (1400, 1000))
    source = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
    dest = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
    ax = GeoAxis(
        fig[2:11, 1:10],
        source = source, 
        dest = dest,
        coastlines = coarseCoastLines,  # You can set this to true if you want coastlines
        lonlims = (min_lon-boundary_add, max_lon+boundary_add),
        latlims = (min_lat-boundary_add, max_lat+boundary_add),
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
            download(url, local_file_path)
        end

        # Now read the data from the file
        countries = GeoJSON.read(read(local_file_path, String))
        poly!(ax, countries; color = :honeydew, colormap = :dense,
            strokecolor = :gray50, strokewidth = 0.5,
        )
    end

    if interactive
        align_horrizontal_button = Button(fig[12, 4]; label = "align horz.", fontsize = 12)
        align_vertical_button = Button(fig[12, 5]; label = "align vert.", fontsize = 12)
        open_button = Button(fig[12, 6]; label = "open", fontsize = 12)
        up_button = Button(fig[12, 7]; label = "navigate up", fontsize = 12)
        save_button = Button(fig[12, 8]; label = "save", fontsize = 12)
        Label(fig[1, :], title; halign = :center, fontsize = 11)
    end

    connect!(ax, design)
    
    for component in design.components
        add_component!(ax,component)
    end

    if interactive
        on(ax.finallimits, priority = 9) do finallimits
            widths = finallimits.widths
            origin = finallimits.origin
            xlimits[] = [origin[1], origin[1] + widths[1]]
            ylimits[] = [origin[2], origin[2] + widths[2]]
            new_global_delta_h(ax)
            notifyComponents()
        end
        on(ax.scene.px_area, priority = 9) do _
            # Get the size of the axis in pixels
            plot_widthsTuple = ax.scene.px_area[].widths
            plot_widths[] = collect(plot_widthsTuple)
            # Get the current limits of the axis
            new_global_delta_h(ax)
            notifyComponents()
        end
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

                    # if Keyboard.s in events(fig).keyboardstate
                    # Delete marker
                    plt, i = pick(fig)

                    if isnothing(plt)
                        clear_selection(design)
                        Consume(true)
                    else
                        if plt isa Image

                            image = plt
                            xobservable = image[1]
                            xvalues = xobservable[]
                            yobservable = image[2]
                            yvalues = yobservable[]


                            x = xvalues[1] + Δh[] * icon_scale/2
                            y = yvalues[1] + Δh[] * icon_scale/2
                            selected_system = filtersingle(
                                s -> is_tuple_approx(s.xy[], (x, y); atol = Δh[]),
                                design.components,
                            )

                            if isnothing(selected_system)
                                @warn "clicked an image at ($(round(x; digits=1)), $(round(y; digits=1))), but no system design found!"
                            else
                                selected_system.color[] = :pink
                                dragging[] = true
                            end

                        elseif plt isa Lines

                        elseif plt isa Scatter

                        elseif plt isa GLMakie.Mesh
                            clear_selection(design)
                            Consume(true)
                        end
                    end
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
                    if sub_design.color[] == :pink
                        xyWidths = ax.finallimits[].widths
                        xy_origin = ax.finallimits[].origin
                        plot_origin = pixelarea(ax.scene)[].origin
                        plot_widths = pixelarea(ax.scene)[].widths
                        mouse_pos_loc = mouse_pos .- plot_origin
                        xy = xy_origin .+ mouse_pos_loc .* xyWidths ./ plot_widths
                        sub_design.xy[] = Tuple(xy)

                        notifyComponents()
                        break #only move one system for mouse drag
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
                        if sub_design.color[] == :pink

                            xc = sub_design.xy[][1]
                            yc = sub_design.xy[][2]

                            sub_design.xy[] = (xc + change[1], yc + change[2])

                        end
                    end

                    reset_limits!(ax)

                    notifyComponents()
                    return Consume(true)
                end
            end
        end

        on(align_horrizontal_button.clicks, priority=10) do clicks
            align(design, :horrizontal)
        end

        on(align_vertical_button.clicks, priority=10) do clicks
            align(design, :vertical)
        end

        on(open_button.clicks, priority=10) do clicks
            for component in design.components
                if component.color[] == :pink
                    view_design = component
                        #EnergySystemDesign(component.system, get_design_path(component))
                    view_design.parent = if haskey(design.system,:name) design.system[:name]
                    else Symbol("TopLevel")
                    end
                    view(component,root_design)
                    #fig_ = view(view_design)
                    #display(GLMakie.Screen(), fig_)
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
    end

    notifyComponents = () -> begin
        for component ∈ design.components
            notify(component.xy)
        end
    end
    new_global_delta_h(ax)
    notifyComponents()
    notify(ax.finallimits)
    display(fig)

    return fig
end