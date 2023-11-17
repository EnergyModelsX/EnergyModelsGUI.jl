using Observables
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