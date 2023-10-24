using GeoMakie
using GLMakie
using CairoMakie
using FilterHelpers
using FileIO
using TOML
Δh = 0.05
#const dragging = Ref(false)

# Extracts the first character of the `wall` field as a `Symbol`.

get_wall(design::EnergySystemDesign) =  Symbol(string(design.wall[])[1])


"""
    This function extract and return the wall order from the `wall` field of an `EnergySystemDesign`.

    Parameters:
    - `design::EnergySystemDesign`: An instance of the `EnergySystemDesign` struct.

    Returns:
    An integer representing the wall order, or 0 if not found.
"""

function get_wall_order(design::EnergySystemDesign)

    wall = string(design.wall[])
    if length(wall) > 1
        order = tryparse(Int, wall[2:end])

        if isnothing(order)
            order = 1
        end

        return order
    else


        return 0

    end


end

"""
    Parameters:
    - `design::EnergySystemDesign`: An instance of the `EnergySystemDesign` struct.

    Returns:
    A boolean indicating whether the system is a pass-through system.
 """

is_pass_thru(design::EnergySystemDesign) = is_pass_thru(design.system)
function is_pass_thru(system::Dict)
    if haskey(system,:type)
        return startswith(system[:type], "PassThru")
    end
    return false
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

"""
    Processes children or components within an energy system design and populates the `children` vector.

    Parameters:
    - `children::Vector{EnergySystemDesign}`: A vector to store child `EnergySystemDesign` instances.
    - `systems::Dict`: The system configuration data represented as a dictionary.
    - `design_dict::Dict`: A dictionary containing design-specific data.
    - `design_path::String`: A file path or identifier related to the design.
    - `parent::Symbol`: A symbol representing the parent of the children.
    - `parent_xy::Observable{Tuple{Float64,Float64}}`: An observable tuple holding the coordinates of the parent.
    - `is_connector::Bool = false`: A boolean indicating whether the children are connectors (default: false).
    - `connectors...`: Additional keyword arguments.
"""

function process_children!(
    children::Vector{EnergySystemDesign},
    systems::Dict,
    design_dict::Dict,
    design_path::String,
    parent::Symbol,
    parent_xy::Observable{Tuple{Float64,Float64}},
    is_connector = false;
    connectors...,
)
    system_iterator = nothing
    if haskey(systems,:areas) && !is_connector
        system_iterator = enumerate(systems[:areas])
    elseif haskey(systems,:nodes) && !is_connector
        system_iterator = enumerate(systems[:nodes])
    elseif haskey(systems,:node) && is_connector
        system_iterator = enumerate([systems[:node]])
    end
    parent_x, parent_y = parent_xy[] # we get these from constructor
    if !isempty(systems) && !isnothing(system_iterator)
        current_node = 1
        for (i, system) in system_iterator
            
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
                if key == "RefArea"
                    if hasproperty(system,:Lon) && hasproperty(system,:Lat)
                        push!(kwargs_pair, :x => system.Lon) #assigning long and lat
                        push!(kwargs_pair, :y => system.Lat)
                    end
                elseif !haskey(kwargs, "x") & !haskey(kwargs, "y") & haskey(systems,:nodes)
                    nodes_count = length(systems[:nodes])
                    
                    if key == "GeoAvailability" # second layer of topology, no need of coordinate inside the region, and make a circle
                        x=parent_x
                        y=parent_y
                    else
                        x,y = place_nodes_in_circle(nodes_count-1,current_node,1,parent_x,parent_y)
                        current_node +=1
                    end
                    push!(kwargs_pair, :x => x)
                    push!(kwargs_pair, :y => y)
                elseif !haskey(kwargs, "x") & !haskey(kwargs, "y") # x=0, y=0. Fallback condition
                    push!(kwargs_pair, :x => i * 3 * Δh)
                    push!(kwargs_pair, :y => i * Δh)
                end
        
                # r => wall for icon rotation
                if haskey(kwargs, "r")
                    push!(kwargs_pair, :wall => kwargs["r"])
                end
            elseif is_connector
                if hasproperty(system,:An)
                    if haskey(connectors, safe_connector_name(Symbol(system.An)))
                        push!(kwargs_pair, :wall => connectors[safe_connector_name(Symbol(system.An))])
                    end
                else
                    if haskey(connectors, safe_connector_name(Symbol(system)))
                        push!(kwargs_pair, :wall => connectors[safe_connector_name(Symbol(system))])
                    end
                end
                x=parent_x
                y=parent_y
                push!(kwargs_pair, :x => x)
                push!(kwargs_pair, :y => y)
            end
        
            for (key, value) in kwargs
                push!(kwargs_pair, Symbol(key) => value)
            end
            if haskey(systems,:areas) && !is_connector
                area_An = systems[:areas][i].An
                area_links = filter(item->getfield(item,:from) == area_An || getfield(item,:to) == area_An,systems[:links]) 
                area_nodes = filter(item -> any(link -> link.from == item || link.to == item, area_links),systems[:nodes])
                this_sys = Dict([(:node, system),(:links,area_links),(:nodes,area_nodes)])
            elseif !is_connector
                this_sys = Dict([(:node, system)])
            elseif is_connector && hasproperty(system,:An)
                this_sys = Dict([(:connector, system.An)])
            elseif is_connector
                this_sys = Dict([(:connector, system)])
            end
            push!(kwargs_pair, :icon => find_icon(this_sys, design_path))
        
            
            push!(
                children,
                EnergySystemDesign(this_sys, design_path; NamedTuple(kwargs_pair)...),
            )
        end
    end
end

"""
    Function to place nodes evenly in a circle
"""

function place_nodes_in_circle(total_nodes::Int, current_node::Int, distance::T, start_x::Float64, start_y::Float64) where T<:Number
    angle = 2π * current_node / total_nodes
    x = start_x + distance * cos(angle)
    y = start_y + distance * sin(angle)
    return x, y
end

safe_connector_name(name::Symbol) = Symbol("_$name")

"""
    Generates a design path based on the type of the `system` field in an `EnergySystemDesign` instance.
"""
function get_design_path(design::EnergySystemDesign)
    type = string(typeof(design.system[:node]))
    parts = split(type, '.')
    path = joinpath(parts[1:end-1]..., "$(parts[end]).toml")
    return replace(design.file, path => "")
end

find_icon(design::EnergySystemDesign) = find_icon(design.system, get_design_path(design))

"""
    Function to find the icon associated with a given system's node type.
"""
function find_icon(system::Dict, design_path::String)
    icon_name = "NotFound"
    if haskey(system,:node)
        icon_name = string(typeof(system[:node]))
    end
    icon = joinpath(@__DIR__, "..", "icons", "$icon_name.png")
    isfile(icon) && return icon
    return joinpath(@__DIR__,"..", "icons", "NotFound.png")
end

"""
    Check if 2 tuple values are approximately equal within a specified tolerance.
    Parameters:
    - `a::Tuple{Float64, Float64}`: The first tuple.
    - `b::Tuple{Float64, Float64}`: The second tuple to compare.
    - `atol::Float64`: The absolute tolerance for the comparison
"""
function is_tuple_approx(a::Tuple{Float64,Float64}, b::Tuple{Float64,Float64}; atol)

    r1 = isapprox(a[1], b[1]; atol)
    r2 = isapprox(a[2], b[2]; atol)

    return all([r1, r2])
end

"""
    Functions handling different keyboard inputs (events) and return changes in x, y coordinates.
"""
get_change(::Val) = (0.0, 0.0)
get_change(::Val{Keyboard.up}) = (0.0, +Δh / 5)
get_change(::Val{Keyboard.down}) = (0.0, -Δh / 5)
get_change(::Val{Keyboard.left}) = (-Δh / 5, 0.0)
get_change(::Val{Keyboard.right}) = (+Δh / 5, 0.0)


"""
    Function to align certain components within an 'EnergySystemDesign' instance either horizontally or vertically.
"""
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

"""
    Function to clear the color selection of components and connectors within 'EnergySystemDesign' instance. 
"""
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

"""
    Connects selected connectors within an `EnergySystemDesign` and adds these connections to the `design.connections` vector.

    Parameters:
    - `ax::Axis`: An instance of the `Axis` (or similar) type for performing the actual connection.
    - `design::EnergySystemDesign`: An instance of the `EnergySystemDesign` struct representing the design.

"""

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
    
    for connector in component.connectors
        min_x, max_x, min_y, max_y = find_min_max_coordinates(connector, min_x, max_x, min_y, max_y)
    end
    
    return min_x, max_x, min_y, max_y
end

function find_min_max_coordinates(root::EnergySystemDesign)
    return find_min_max_coordinates(root, Inf, -Inf, Inf, -Inf)
end
function new_global_delta_h(design::EnergySystemDesign)
    min_x, max_x, min_y, max_y = find_min_max_coordinates(design)
    global Δh = max(0.005*sqrt((max_x-min_x)^2+(max_y-min_y)^2),0.05)
end

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