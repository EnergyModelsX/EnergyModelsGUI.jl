#Based on ModelingToolkitDesigner source code.

using GLMakie
using CairoMakie
#using ModelingToolkit
using FilterHelpers
using FileIO
using TOML

const Δh = 0.05
const dragging = Ref(false)


mutable struct EnergySystemDesign
    # parameters::Vector{Parameter}
    # states::Vector{State}

    parent::Union{Symbol,Nothing}
    system::Dict
    system_color::Symbol
    components::Vector{EnergySystemDesign}
    connectors::Vector{EnergySystemDesign}
    connections::Vector{Tuple{EnergySystemDesign,EnergySystemDesign}}

    xy::Observable{Tuple{Float64,Float64}}
    icon::Union{String,Nothing}
    color::Observable{Symbol}
    wall::Observable{Symbol}

    file::String
end

Base.copy(x::Tuple{EnergySystemDesign,EnergySystemDesign}) = (copy(x[1]), copy(x[2]))


Base.copy(x::EnergySystemDesign) = EnergySystemDesign(
    x.parent,
    x.system,
    x.system_color,
    copy.(x.components),
    copy.(x.connectors),
    copy.(x.connections),
    Observable(x.xy[]),
    x.icon,
    Observable(x.system_color),
    Observable(x.wall[]),
    x.file,
)

function EnergySystemDesign(
    system::Dict,
    design_path::String;
    x = 0.0,
    y = 0.0,
    icon = nothing,
    wall = :E,
    parent = nothing,
    kwargs...,
)
    file = design_file(system, design_path)
    design_dict = if isfile(file)
        TOML.parsefile(file)
    else
        Dict()
    end

    #systems = filter(x -> typeof(x) == ODESystem, ModelingToolkit.get_systems(system))
    #systems = system
    components = EnergySystemDesign[]
    connectors = EnergySystemDesign[]
    connections = Tuple{EnergySystemDesign,EnergySystemDesign}[]
    if haskey(system,:areas)
        parent_arg = Symbol("Toplevel")
    elseif haskey(system,:node)
        parent_arg = Symbol(system[:node])
    else
        parent_arg = Symbol("ParentNotFound")
    end

    if !isempty(system)

        process_children!(
            components,
            system,
            design_dict,
            design_path,
            parent_arg,
            false;
            kwargs...,
        )
    end

    xy = Observable((x, y))
    color = :black

    return EnergySystemDesign(
        parent,
        system,
        color,
        components,
        connectors,
        connections,
        xy,
        icon,
        Observable(color),
        Observable(wall),
        file,
    )
end


function design_file(system::Dict, path::String)
    #@assert !isnothing(system.gui_metadata) "ODESystem must use @component: $(system.name)"

    # path = joinpath(@__DIR__, "designs")
    if !isdir(path)
        mkdir(path)
    end
    if !haskey(system,:node)
        systemName = "TopLevel"
    else
        systemName = string(system[:node])
    end
    #parts = split(string(system.gui_metadata.type), '.')
    #for part in parts[1:end-1]
    #    path = joinpath(path, part)
    #    if !isdir(path)
    #        mkdir(path)
    #    end
    #end
    file = joinpath(path, "$(systemName).toml")

    return file
end

function process_children!(
    children::Vector{EnergySystemDesign},
    systems::Dict,
    design_dict::Dict,
    design_path::String,
    parent::Symbol,
    is_connector = false;
    connectors...,
)

    if haskey(systems,:areas)
        system_iterator = enumerate(systems[:areas])
    elseif haskey(systems,:nodes)
        system_iterator = enumerate(systems[:nodes])
    end
    #systems = filter(x -> ModelingToolkit.isconnector(x) == is_connector, systems)
    if !isempty(systems) && haskey(systems,:nodes)
        for (i, system) in system_iterator
            #println(system)
            key = string(typeof(system))
            kwargs = if haskey(design_dict, key)
                design_dict[key]
            else
                Dict()
            end
        
            kwargs_pair = Pair[]
        
            
            push!(kwargs_pair, :parent => parent)
        
        
            if !is_connector
                #if x and y are missing, add defaults
                if !haskey(kwargs, "x") & !haskey(kwargs, "y")
                    push!(kwargs_pair, :x => i * 3 * Δh)
                    push!(kwargs_pair, :y => i * Δh)
                end
        
                # r => wall for icon rotation
                if haskey(kwargs, "r")
                    push!(kwargs_pair, :wall => kwargs["r"])
                end
            else
                if haskey(connectors, safe_connector_name(system.name))
                    push!(kwargs_pair, :wall => connectors[safe_connector_name(system.name)])
                end
            end
        
            for (key, value) in kwargs
                push!(kwargs_pair, Symbol(key) => value)
            end
            if haskey(systems,:areas)
                area_An = systems[:areas][i].An
                area_links = filter(item->getfield(item,:from) == system_An || getfield(item,:to) == area_An,systems[:links]) 
                area_nodes = filter(item -> any(link -> link.from == item || link.to == item, system_links),systems[:nodes])
                this_sys = Dict([(:node, system),(:links,area_links),(:nodes,area_nodes)])
            else
                this_sys = Dict([(:node, system)])
            end
            push!(kwargs_pair, :icon => find_icon(this_sys, design_path))
        
            
            #println(this_sys)
            push!(
                children,
                EnergySystemDesign(this_sys, design_path; NamedTuple(kwargs_pair)...),
            )
        end
    end
end


function get_design_path(design::EnergySystemDesign)
    type = string(typeof(design.system[:node]))
    parts = split(type, '.')
    path = joinpath(parts[1:end-1]..., "$(parts[end]).toml")
    return replace(design.file, path => "")
end

find_icon(design::EnergySystemDesign) = find_icon(design.system, get_design_path(design))

function find_icon(system::Dict, design_path::String)
    icon_name = "NotFound"
    if haskey(system,:node)
        icon_name = string(typeof(system[:node]))
    end
    icon = joinpath(@__DIR__, "..", "icons", "$icon_name.png")
    #println(icon)
    isfile(icon) && return icon
    return joinpath(@__DIR__,"..", "icons", "NotFound.png")
end


function is_tuple_approx(a::Tuple{Float64,Float64}, b::Tuple{Float64,Float64}; atol)

    r1 = isapprox(a[1], b[1]; atol)
    r2 = isapprox(a[2], b[2]; atol)

    return all([r1, r2])
end

function view(design::EnergySystemDesign, interactive = true)

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

    ax = Axis(
        fig[2:11, 1:10];
        aspect = DataAspect(),
        yticksvisible = false,
        xticksvisible = false,
        yticklabelsvisible = false,
        xticklabelsvisible = false,
        xgridvisible = false,
        ygridvisible = false,
        bottomspinecolor = :transparent,
        leftspinecolor = :transparent,
        rightspinecolor = :transparent,
        topspinecolor = :transparent,
    )

    if interactive
        #connect_button = Button(fig[12, 1]; label = "connect", fontsize = 12)
        clear_selection_button =
            Button(fig[12, 2]; label = "clear selection", fontsize = 12)
        next_wall_button = Button(fig[12, 3]; label = "move node", fontsize = 12)
        align_horrizontal_button = Button(fig[12, 4]; label = "align horz.", fontsize = 12)
        align_vertical_button = Button(fig[12, 5]; label = "align vert.", fontsize = 12)
        open_button = Button(fig[12, 6]; label = "open", fontsize = 12)
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

    for connector in design.connectors
        add_component!(ax, connector)
        notify(connector.xy)
    end

    for connection in design.connections
        connect!(ax, connection)
    end

    if interactive
        on(events(fig).mousebutton, priority = 2) do event

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
                                s -> is_tuple_approx(s.xy[], (x, y); atol = 1e-3),
                                [design.components; design.connectors],
                            )

                            if isnothing(selected_system)

                                x = xvalues[1] + Δh * 0.8 * 0.5
                                y = yvalues[1] + Δh * 0.8 * 0.5
                                selected_system = filterfirst(
                                    s -> is_tuple_approx(s.xy[], (x, y); atol = 1e-3),
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

                        elseif plt isa Mesh



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
                    view_design =
                        EnergySystemDesign(component.system, get_design_path(component))
                    view_design.parent = if haskey(design.system,:name) design.system[:name]
                    else Symbol("TopLevel")
                    end
                    fig_ = view(view_design)
                    display(GLMakie.Screen(), fig_)
                    break
                end
            end
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



function align(design::EnergySystemDesign, type)
    xs = Float64[]
    ys = Float64[]
    for sub_design in [design.components; design.connectors]
        if sub_design.color[] == :pink
            x, y = sub_design.xy[]
            push!(xs, x)
            push!(ys, y)
        end
    end

    ym = sum(ys) / length(ys)
    xm = sum(xs) / length(xs)

    for sub_design in [design.components; design.connectors]
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


function clear_selection(design::EnergySystemDesign)
    for component in design.components
        for connector in component.connectors
            connector.color[] = connector.system_color
        end
        component.color[] = :black
    end
    for connector in design.connectors
        connector.color[] = connector.system_color
    end
end



function add_component!(ax::Axis, design::EnergySystemDesign)

    draw_box!(ax, design)
    draw_nodes!(ax, design)
    draw_icon!(ax, design)
    draw_label!(ax, design)
    #if is_pass_thru(design)
    #    draw_passthru!(ax, design)
    #else
    #    draw_icon!(ax, design)
    #    draw_label!(ax, design)
    #end

end

function draw_box!(ax::Axis, design::EnergySystemDesign)

    xo = Observable(zeros(5))
    yo = Observable(zeros(5))


    Δh_, linewidth = Δh, 1 #if ModelingToolkit.isconnector(design.system)
    #    0.6 * Δh, 2
    #else
    #    Δh, 1
    #end

    on(design.xy) do val
        x = val[1]
        y = val[2]

        xo[], yo[] = box(x, y, Δh_)
    end


    lines!(ax, xo, yo; color = design.color, linewidth)


    if !isempty(design.components)
        xo2 = Observable(zeros(5))
        yo2 = Observable(zeros(5))

        on(design.xy) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, Δh_ * 1.1)
        end


        lines!(ax, xo2, yo2; color = design.color, linewidth)
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



function draw_icon!(ax::Axis, design::EnergySystemDesign)

    xo = Observable(zeros(2))
    yo = Observable(zeros(2))

    scale = 0.8 #if ModelingToolkit.isconnector(design.system)
    #    0.5 * 0.8
    #else
    #    0.8
    #end

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

    scale = 0.925 #if ModelingToolkit.isconnector(design.system)
    #    1 + 0.75 * 0.5
    #else
    #    0.925
    #end

    on(design.xy) do val

        x = val[1]
        y = val[2]

        xo[] = x
        yo[] = y - Δh * scale

    end
    if haskey(design.system,:node)
        text!(ax, xo, yo; text = string(design.system[:node]), align = (:center, :bottom))
    end
end

function box(x, y, Δh = 0.05)

    xs = [x + Δh, x - Δh, x - Δh, x + Δh, x + Δh]
    ys = [y + Δh, y + Δh, y - Δh, y - Δh, y + Δh]

    return xs, ys
end


function save_design(design::EnergySystemDesign)


    design_dict = Dict()

    for component in design.components

        x, y = component.xy[]

        pairs = Pair{Symbol,Any}[
            :x => round(x; digits = 2)
            :y => round(y; digits = 2)
        ]

        if component.wall[] != :E
            push!(pairs, 
                :r => string(component.wall[])
            )
        end

        for connector in component.connectors
            if connector.wall[] != :E  #don't use get_wall() here, need to preserve E1, E2, etc
                push!(pairs, safe_connector_name(connector.system.name) => string(connector.wall[]))
            end
        end

        design_dict[string(component.system[:node])] = Dict(pairs)
    end

    for connector in design.connectors
        x, y = connector.xy[]

        pairs = Pair{Symbol,Any}[
            :x => round(x; digits = 2)
            :y => round(y; digits = 2)
        ]

        design_dict[connector.system.name] = Dict(pairs)
    end

    save_design(design_dict, design.file)

    connection_file = replace(design.file, ".toml" => ".jl")
#    open(connection_file, "w") do io
#        connection_code(io, design)
#    end
end

function save_design(design_dict::Dict, file::String)
    open(file, "w") do io
        TOML.print(io, design_dict; sorted = true) do val
            if val isa Symbol
                return string(val)
            end
        end
    end
end