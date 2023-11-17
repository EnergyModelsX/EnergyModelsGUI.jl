# Module to view the topology using GeoMakie, CairoMakie and GLMakie

using GeoMakie
using GLMakie
using CairoMakie
using FilterHelpers
using FileIO
using TOML
Δh = 0.05
const dragging = Ref(false)
boundary_add = 0.5

"""
    Functions handling different keyboard inputs (events) and return changes in x, y coordinates.
"""
get_change(::Val) = (0.0, 0.0)
get_change(::Val{Keyboard.up}) = (0.0, +Δh / 5)
get_change(::Val{Keyboard.down}) = (0.0, -Δh / 5)
get_change(::Val{Keyboard.left}) = (-Δh / 5, 0.0)
get_change(::Val{Keyboard.right}) = (+Δh / 5, 0.0)

function connect!(ax::Axis, design::EnergySystemDesign)
    all_connectors = vcat([s.connectors for s in design.components]...)
    push!(all_connectors, design.connectors...)
    selected_connectors = EnergySystemDesign[]

    for connector in all_connectors
        if connector.color[] == :pink
            push!(selected_connectors, connector)
            connector.color[] = connector.system_color
        end
    end

    if length(selected_connectors) > 1
        connect!(ax, (selected_connectors[1], selected_connectors[2]))
        push!(design.connections, (selected_connectors[1], selected_connectors[2]))
    end
end

"""
     Function to add a line connecting/updating 2 connectors.
"""
function connect!(ax::Axis, connection::Tuple{EnergySystemDesign,EnergySystemDesign,Dict})

    xs = Observable(Float64[])
    ys = Observable(Float64[])

    update = () -> begin
        empty!(xs[])
        empty!(ys[])
        for connector in connection[1:2]
            push!(xs[], connector.xy[][1])
            push!(ys[], connector.xy[][2])
        end
        notify(xs)
        notify(ys)
    end

    style = :solid
    for connector in connection[1:2]
        s = get_style(connector)
        if s != :solid
            style = s
        end

        on(connector.xy) do val
            update()
        end
    end

    style=get_style(connection[3])
    update()

    lines!(ax, xs, ys; color = connection[1].color[], linestyle = style)
end

"""
    Positioning nodes and their labels based on specific directions.
"""
get_node_position(w::Symbol, delta, i) = get_node_position(Val(w), delta, i)
get_node_label_position(w::Symbol, x, y) = get_node_label_position(Val(w), x, y)

get_node_position(::Val{:N}, delta, i) = (delta * i - Δh, +Δh)
get_node_label_position(::Val{:N}, x, y) = (x + Δh / 10, y + Δh / 5)

get_node_position(::Val{:S}, delta, i) = (delta * i - Δh, -Δh)
get_node_label_position(::Val{:S}, x, y) = (x + Δh / 10, y - Δh / 5)

get_node_position(::Val{:E}, delta, i) = (+Δh, delta * i - Δh)
get_node_label_position(::Val{:E}, x, y) = (x + Δh / 5, y)

get_node_position(::Val{:W}, delta, i) = (-Δh, delta * i - Δh)
get_node_label_position(::Val{:W}, x, y) = (x - Δh / 5, y)


"""
    Adding components
"""
function add_component!(ax::Axis, design::EnergySystemDesign)

    draw_box!(ax, design)
    draw_nodes!(ax, design)
    if is_pass_thru(design)
        #draw_passthru!(ax, design)
    #if is_parent_connector(design)

    else
        draw_icon!(ax, design)
        draw_label!(ax, design)
    end

end

"""
    Text allignment
"""
get_text_alignment(wall::Symbol) = get_text_alignment(Val(wall))
get_text_alignment(::Val{:E}) = (:left, :top)
get_text_alignment(::Val{:W}) = (:right, :top)
get_text_alignment(::Val{:S}) = (:left, :top)
get_text_alignment(::Val{:N}) = (:left, :bottom)

"""
    Get the line style for an `EnergySystemDesign` object based on its system properties.   
"""
get_style(design::EnergySystemDesign) = get_style(design.system)
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


"""
    Function for drawing a box and it's appearance, including style, color, size. 
"""
function draw_box!(ax::Axis, design::EnergySystemDesign)

    xo = Observable(zeros(5))
    yo = Observable(zeros(5))

    Δh_, linewidth = if haskey(design.system,:connector)
        0.6 * Δh, 2
    else
        Δh, 1
    end

    # Observe changes in design coordinates and update box position
    on(design.xy) do val
        x = val[1]
        y = val[2]
        xo[], yo[] = box(x, y, Δh_)
    end

    style = get_style(design)
    lines!(ax, xo, yo; color = design.color, linewidth,linestyle = style)

    # if the design has components, draw an enlarged box around it. 
    if !isempty(design.components)
        xo2 = Observable(zeros(5))
        yo2 = Observable(zeros(5))
        
        # observe changes in design coordinates and update enlarged box position
        on(design.xy) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, Δh_ * 1.2)
        end


        lines!(ax, xo2, yo2; color = design.color, linewidth,linestyle = style)
    end


end


function draw_nodes!(ax::Axis, design::EnergySystemDesign)

    xo = Observable(0.0)
    yo = Observable(0.0)

    on(design.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y

    end

    update =
        (connector) -> begin

            connectors_on_wall =
                filter(x -> get_wall(x) == get_wall(connector), design.connectors)

            n_items = length(connectors_on_wall)
            delta = 2 * Δh / (n_items + 1)

            sort!(connectors_on_wall, by=x->x.wall[])

            for i = 1:n_items
                x, y = get_node_position(get_wall(connector), delta, i)
                connectors_on_wall[i].xy[] = (x + xo[], y + yo[])
            end
        end


    for connector in design.connectors

        on(connector.wall) do val
            update(connector)
        end

        on(design.xy) do val
            update(connector)
        end

        draw_node!(ax, connector)
        draw_node_label!(ax, connector)
    end

end

function draw_node!(ax::Axis, connector::EnergySystemDesign)
    xo = Observable(0.0)
    yo = Observable(0.0)

    on(connector.xy) do val

        x = val[1]
        y = val[2]
        xo[] = x
        yo[] = y

    end
    scatter!(ax, xo, yo; marker = :rect, color = connector.color, markersize = 15)
end


function draw_node_label!(ax::Axis, connector::EnergySystemDesign)
    xo = Observable(0.0)
    yo = Observable(0.0)
    alignment = Observable((:left, :top))

    on(connector.xy) do val

        x = val[1] 
        y = val[2]

        xt, yt = get_node_label_position(get_wall(connector), x, y)

        xo[] = xt
        yo[] = yt

        alignment[] = get_text_alignment(get_wall(connector))
    end

    scene = GLMakie.Makie.parent_scene(ax)
    current_font_size = theme(scene, :fontsize)

    text!(
        ax,
        xo,
        yo;
        text = string(connector.system[:connector]),
        color = connector.color,
        align = alignment,
        fontsize = current_font_size[] * 0.9,
    )
end

"""
    Function to find the min max coordinates, this could be use to fix the map focus on the specified region.
"""

function draw_icon!(ax::Axis, design::EnergySystemDesign)

    xo = Observable(zeros(2))
    yo = Observable(zeros(2))

    scale = if haskey(design.system,:connector)
        0.5 * 0.8
    else
        0.8
    end

    on(design.xy) do val

        x = val[1]
        y = val[2]

        xo[] = [x - Δh * scale, x + Δh * scale]
        yo[] = [y - Δh * scale, y + Δh * scale]

    end


    if !isnothing(design.icon)
        img = load(design.icon)
        w = get_wall(design)
        imgd = if w == :E
            rotr90(img)
        elseif w == :S
            rotr90(rotr90(img))
        elseif w == :W
            rotr90(rotr90(rotr90(img)))
        elseif w == :N
            img
        end

        image!(ax, xo, yo, imgd)
    end
end

get_wall(design::EnergySystemDesign) =  Symbol(string(design.wall[])[1])


function draw_label!(ax::Axis, design::EnergySystemDesign)

    xo = Observable(0.0)
    yo = Observable(0.0)

    scale = if haskey(design.system,:connector)
        1 + 0.75 * 0.5
    else
        1.1
    end

    on(design.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y + Δh * scale

    end
    if haskey(design.system,:node)
        text!(ax, xo, yo; text = "$(string(design.system[:node]))\n($(typeof(design.system[:node])))", align = (:center, :bottom))
    end
end


function box(x, y, Δh = 0.05)

    xs = [x + Δh, x - Δh, x - Δh, x + Δh, x + Δh]
    ys = [y + Δh, y + Δh, y - Δh, y - Δh, y + Δh]

    return xs, ys
end

"""
    Define the main function to view the topology
"""
function view(design::EnergySystemDesign) 
    view(design,design,true)
end

function view(design::EnergySystemDesign,root_design::EnergySystemDesign,interactive = true)
    new_global_delta_h(design)
    if interactive
        GLMakie.activate!(inline=false)
    else
        CairoMakie.activate!()
    end



    fig = Figure()

    title = if isnothing(design.parent)
        "TopLevel [$(design.file)]"
    else
        "$(design.parent).$(string(design.system[:node])) [$(design.file)]"
    end


    min_lon, max_lon, min_lat, max_lat = find_min_max_coordinates(design)
    
    # Create a figure
    fig = Figure()

    # Create a GeoAxis with specific settings and set the bounding box for Norway
    ax = GeoAxis(
        fig[2:11, 1:10],
        dest = "+proj=eqearth",
        coastlines = true,  # You can set this to true if you want coastlines
        lonlims = (min_lon-boundary_add, max_lon+boundary_add),
        latlims = (min_lat-boundary_add, max_lat+boundary_add),
    )

    
    # Display the map
    display(fig)


    if interactive
        #connect_button = Button(fig[12, 1]; label = "connect", fontsize = 12)
        clear_selection_button =
            Button(fig[12, 2]; label = "clear selection", fontsize = 12)
        next_wall_button = Button(fig[12, 3]; label = "move node", fontsize = 12)
        align_horrizontal_button = Button(fig[12, 4]; label = "align horz.", fontsize = 12)
        align_vertical_button = Button(fig[12, 5]; label = "align vert.", fontsize = 12)
        open_button = Button(fig[12, 6]; label = "open", fontsize = 12)
        up_button = Button(fig[12, 7]; label = "navigate up", fontsize = 12)
        #mode_toggle = Toggle(fig[12, 7])

        save_button = Button(fig[12, 10]; label = "save", fontsize = 12)


        Label(fig[1, :], title; halign = :left, fontsize = 11)
    end
    
    for component in design.components
        add_component!(ax, component)
        for connector in component.connectors
            notify(connector.wall)
        end
        notify(component.xy)
    end

    for connection in design.connections
        connect!(ax, connection)
    end

    if interactive
        on(events(fig).mousebutton, priority = 2) do event
            new_global_delta_h(design)
            if event.button == Mouse.left
                if event.action == Mouse.press

                    # if Keyboard.s in events(fig).keyboardstate
                    # Delete marker
                    plt, i = pick(fig)

                    if !isnothing(plt)

                        if plt isa Image

                            image = plt
                            xobservable = image[1]
                            xvalues = xobservable[]
                            yobservable = image[2]
                            yvalues = yobservable[]


                            x = xvalues[1] + Δh * 0.8
                            y = yvalues[1] + Δh * 0.8
                            selected_system = filtersingle(
                                s -> is_tuple_approx(s.xy[], (x, y); atol = Δh),
                                [design.components; design.connectors],
                            )

                            if isnothing(selected_system)

                                x = xvalues[1] + Δh * 0.8 * 0.5
                                y = yvalues[1] + Δh * 0.8 * 0.5
                                selected_system = filterfirst(
                                    s -> is_tuple_approx(s.xy[], (x, y); atol = Δh),
                                    [design.components; design.connectors],
                                )

                                if isnothing(selected_system)
                                    @warn "clicked an image at ($(round(x; digits=1)), $(round(y; digits=1))), but no system design found!"
                                else
                                    selected_system.color[] = :pink
                                    dragging[] = true
                                end
                            else
                                selected_system.color[] = :pink
                                dragging[] = true
                            end



                        elseif plt isa Lines

                        elseif plt isa Scatter

                            point = plt
                            observable = point[1]
                            values = observable[]
                            geometry_point = Float64.(values[1])

                            x = geometry_point[1]
                            y = geometry_point[2]

                            selected_component = filtersingle(
                                c -> is_tuple_approx(c.xy[], (x, y); atol = 1e-3),
                                design.components,
                            )
                            if !isnothing(selected_component)
                                selected_component.color[] = :pink
                            else
                                all_connectors =
                                    vcat([s.connectors for s in design.components]...)
                                selected_connector = filtersingle(
                                    c -> is_tuple_approx(c.xy[], (x, y); atol = 1e-3),
                                    all_connectors,
                                )
                                selected_connector.color[] = :pink
                            end

                        elseif plt isa GLMakie.Mesh



                        end


                    end
                    Consume(true)
                elseif event.action == Mouse.release

                    dragging[] = false
                    Consume(true)
                end
            end

            if event.button == Mouse.right
                clear_selection(design)
                Consume(true)
            end

            return Consume(false)
        end

        on(events(fig).mouseposition, priority = 2) do mp
            if dragging[]
                for sub_design in [design.components; design.connectors]
                    if sub_design.color[] == :pink
                        position = mouseposition(ax)
                        sub_design.xy[] = (position[1], position[2])
                        break #only move one system for mouse drag
                    end
                end

                return Consume(true)
            end

            return Consume(false)
        end

        on(events(fig).keyboardbutton) do event
            new_global_delta_h(design)
            if event.action == Keyboard.press

                change = get_change(Val(event.key))

                if change != (0.0, 0.0)
                    for sub_design in [design.components; design.connectors]
                        if sub_design.color[] == :pink

                            xc = sub_design.xy[][1]
                            yc = sub_design.xy[][2]

                            sub_design.xy[] = (xc + change[1], yc + change[2])

                        end
                    end

                    reset_limits!(ax)

                    return Consume(true)
                end
            end
        end

        #on(connect_button.clicks) do clicks
        #    connect!(ax, design)
        #end

        on(clear_selection_button.clicks) do clicks
            clear_selection(design)
        end

        #TODO: fix the ordering too
        on(next_wall_button.clicks) do clicks
            for component in design.components
                for connector in component.connectors


                    if connector.color[] == :pink

                        current_wall = get_wall(connector)
                        current_order = get_wall_order(connector)

                        

                        if current_order > 1
                            connectors_on_wall = filter(x -> get_wall(x) == current_wall, component.connectors)
                            for cow in connectors_on_wall

                                order = max(get_wall_order(cow), 1)
                                
                                if order == current_order - 1
                                    cow.wall[] = Symbol(current_wall, current_order)
                                end
                                
                                if order == current_order
                                    cow.wall[] = Symbol(current_wall, current_order - 1)
                                end
                            end
                            
                        else

                            next_wall = if current_wall == :N
                                :E
                            elseif current_wall == :W
                                :N
                            elseif current_wall == :S
                                :W
                            elseif current_wall == :E
                                :S
                            end

                            connectors_on_wall = filter(x -> get_wall(x) == next_wall, component.connectors)
                            
                            # connector is added to wall, need to fix any un-ordered connectors
                            for cow in connectors_on_wall
                                order = get_wall_order(cow)
                                
                                if order == 0
                                    cow.wall[] = Symbol(next_wall, 1)
                                end
                            end
                            
                            
                            current_order = length(connectors_on_wall) + 1
                            if current_order > 1
                                connector.wall[] = Symbol(next_wall, current_order) 
                            else
                                connector.wall[] = next_wall
                            end

                            


                            # connector is leaving wall, need to reduce the order
                            connectors_on_wall = filter(x -> get_wall(x) == current_wall, component.connectors)
                            if length(connectors_on_wall) > 1
                                for cow in connectors_on_wall
                                    order = get_wall_order(cow)
                                    
                                    if order == 0
                                        cow.wall[] = Symbol(current_wall, 1)
                                    else
                                        cow.wall[] = Symbol(current_wall, order - 1)
                                    end
                                end
                            else
                                for cow in connectors_on_wall
                                    cow.wall[] = current_wall
                                end
                            end

                        end                        
                    end
                end
            end
        end

        on(align_horrizontal_button.clicks) do clicks
            align(design, :horrizontal)
        end

        on(align_vertical_button.clicks) do clicks
            align(design, :vertical)
        end

        on(open_button.clicks) do clicks
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

        on(up_button.clicks) do clicks
            view(root_design)
        end
        on(save_button.clicks) do clicks
            save_design(design)
        end

        #on(mode_toggle.active) do val
        #    toggle_pass_thrus(design, val)
        #end
    end

    #toggle_pass_thrus(design, !interactive)

    return fig
end

