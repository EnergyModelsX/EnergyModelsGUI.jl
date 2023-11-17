using Observables
using FilterHelpers
using FileIO
using TOML
Δh = 0.05
#const dragging = Ref(false)

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