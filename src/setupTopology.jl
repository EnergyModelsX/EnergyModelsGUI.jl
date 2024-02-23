# Create convenient alias for connections
const Connection = Tuple{EnergySystemDesign, EnergySystemDesign, Dict{Symbol,Any}}

# Set default color when color is not provided through idToColorMap
missingColor::Symbol = :black

"""
Create and initialize an instance of the `EnergySystemDesign` struct, representing energy system designs.

# Parameters:
    - **`system::Dict`**: A dictionary containing system-related data stored as key-value pairs.
    - **`design_path::String`**: A file path or identifier related to the design.
    - **`x::Real`**: Initial x-coordinate of the system (default: 0.0).
    - **`y::Real`**: Initial y-coordinate of the system (default: 0.0).
    - **`icon::Union{String, Nothing}`**: An icon associated with the system (default: nothing).
    - **`wall::Symbol`**: An initial wall value (default: :E).
    - **`parent::Union{Symbol, Nothing}`**: An parent reference or indicator (default: nothing).
    - **`kwargs...`**: Additional keyword arguments.

The function reads system configuration data from a TOML file specified by `design_path` (if it exists), initializes various internal fields,
and processes connections and wall values. It constructs and returns an `EnergySystemDesign` instance.
"""
function EnergySystemDesign(
    system::Dict;
    design_path::String = "",
    idToColorMap::Dict{Any,Any} = Dict{Any, Any}(),
    idToIconMap::Dict{Any,Any} = Dict{Any, Any}(),
    x::Real = 0.0,
    y::Real = 0.0,
    icon::String = "",
    wall::Symbol = :E,
    parent::Union{Symbol, Nothing} = nothing,
    kwargs...,
)
    file::String = design_file(system, design_path)
    design_dict::Dict = if isfile(file)
        TOML.parsefile(file)
    else
        Dict()
    end
    if isempty(idToColorMap)
        products = system[:products]
        seed::Vector{RGB} = [parse(Colorant, hex_color) for hex_color ∈ values(getDefaultColors())]
        productsColors = distinguishable_colors(length(products), seed, dropseed=false)
        idToColorMap = setColors(products, productsColors)
    end

    components::Vector{EnergySystemDesign} = EnergySystemDesign[]
    connections::Vector{Connection} = Tuple{EnergySystemDesign,EnergySystemDesign,Dict}[]

    parent_arg::Symbol = if haskey(system,:areas)
        :TopLevel
    elseif haskey(system,:node)
        Symbol(system[:node])
    else
        :ParentNotFound
    end
    xy::Observable{Tuple{Real, Real}} = Observable((x, y)) #extracting coordinates
    plotObj::Vector{AbstractPlot} = []
    if !isempty(system)
        process_children!(
            components,
            system,
            design_dict,
            design_path,
            idToColorMap,
            idToIconMap,
            parent_arg,
            xy,
            plotObj,
        )
    end
    color::Symbol = :black

    if haskey(system,:areas) && haskey(system,:transmission)
        for transmission ∈ system[:transmission]
            connector_design_from::EnergySystemDesign = filtersingle(
                            x -> x.system[:node].node == transmission.from.node,
                            components,
                        )
            connector_design_to::EnergySystemDesign = filtersingle(
                            x -> x.system[:node].node == transmission.to.node,
                            components,
                        )
            
            if !isnothing(connector_design_from) && !isnothing(connector_design_to)
                colors::Vector{RGB} = getResourceColors(transmission.modes, idToColorMap)
                connection_sys::Dict{Symbol, Any} = Dict(:connection => transmission, :colors => colors, :plotObj => [])
                push!(connections, (connector_design_from, connector_design_to, connection_sys))
            end
        end
    elseif haskey(system,:nodes) && haskey(system,:links)
        for link ∈ system[:links]
            connector_design_from::EnergySystemDesign = filtersingle(
                            x -> x.system[:node] == link.from,
                            components,
                        )
            connector_design_to::EnergySystemDesign = filtersingle(
                            x -> x.system[:node] == link.to,
                            components,
                        )
            if !isnothing(connector_design_from) && !isnothing(connector_design_to)
                resources::Vector{EMB.Resource} = EMB.link_res(link)
                colors::Vector{RGB} = getResourceColors(resources, idToColorMap)
                connection_sys::Dict{Symbol, Any} = Dict(:connection => link, :colors => colors, :plotObj => [])
    
                push!(connections, (connector_design_from, connector_design_to, connection_sys))
            end
        end
    end

    return EnergySystemDesign(
        parent,
        system,
        idToColorMap,
        idToIconMap,
        components,
        connections,
        xy,
        icon,
        Observable(color),
        Observable(wall),
        file,
        plotObj,
    )
end

"""
    process_children!(...)

Processes children or components within an energy system design and populates the `children` vector.

# Parameters:
    - **`children::Vector{EnergySystemDesign}`**: A vector to store child `EnergySystemDesign` instances.
    - **`systems::Dict`**: The system configuration data represented as a dictionary.
    - **`design_dict::Dict`**: A dictionary containing design-specific data.
    - **`design_path::String`**: A file path or identifier related to the design.
    - **`parent::Symbol`**: A symbol representing the parent of the children.
    - **`parent_xy::Observable{Tuple{T,T}}`**: An observable tuple holding the coordinates of the parent, where T is a subtype of Real.
    - **`kwargs...`**: Additional keyword arguments.
"""
function process_children!(
    children::Vector{EnergySystemDesign},
    systems::Dict,
    design_dict::Dict,
    design_path::String,
    idToColorMap::Dict{Any,Any},
    idToIconMap::Dict{Any,Any},
    parent::Symbol,
    parent_xy::Observable{Tuple{T,T}},
    plotObj::Vector{AbstractPlot},
) where T <: Real
    system_iterator::Union{Iterators.Enumerate{Vector{EMB.Node}}, Iterators.Enumerate{Vector{EMG.Area}}, Nothing} = if haskey(systems,:areas)
        enumerate(systems[:areas])
    elseif haskey(systems,:nodes)
        enumerate(systems[:nodes])
    end
    parent_x, parent_y = parent_xy[] # we get these from constructor
    if !isempty(systems) && !isnothing(system_iterator)
        current_node::Int64 = 1
        if haskey(systems,:nodes)
            nodes_count::Int64 = length(systems[:nodes])
        end
        parentNodeFound::Bool = false
        for (i, system) in system_iterator
            key::String = string(system)
            kwargs::Dict = if haskey(design_dict, key)
                design_dict[key]
            else
                Dict()
            end
        
            kwargs_pair::Vector{Pair} = Pair[]
        
            
            push!(kwargs_pair, :idToColorMap => idToColorMap)
            push!(kwargs_pair, :idToIconMap => idToIconMap)
            push!(kwargs_pair, :parent => parent)
        
            #if x and y are missing, add defaults
            if system isa EMG.Area
                if hasproperty(system,:lon) && hasproperty(system,:lat)
                    push!(kwargs_pair, :x => system.lon) #assigning long and lat
                    push!(kwargs_pair, :y => system.lat)
                end
            elseif !haskey(kwargs, "x") && !haskey(kwargs, "y") && haskey(systems,:nodes)
                
                if !parentNodeFound && ((haskey(systems,:node) && system == systems[:node].node) || (parent == :ParentNotFound && typeof(system) <: EMB.Availability))  # use the parent coordinate for the RefArea node or an availability node
                    x::Real = parent_x
                    y::Real = parent_y
                    nodes_count -= 1
                    parentNodeFound = true
                else
                    x,y = place_nodes_in_circle(nodes_count,current_node,1,parent_x,parent_y)
                    current_node += 1
                end
                push!(kwargs_pair, :x => x)
                push!(kwargs_pair, :y => y)
            elseif !haskey(kwargs, "x") && !haskey(kwargs, "y") # x=0, y=0. Fallback condition
                push!(kwargs_pair, :x => i * 3)
                push!(kwargs_pair, :y => i)
            end
    
            # r => wall for icon rotation
            if haskey(kwargs, "r")
                push!(kwargs_pair, :wall => kwargs["r"])
            end

            for (key, value) in kwargs
                push!(kwargs_pair, Symbol(key) => value)
            end
            this_sys::Dict{Symbol, Any} = Dict()
            if haskey(systems,:areas)
                area_An::EMB.Node = systems[:areas][i].node

                # Allocate redundantly large vector (for efficiency) to collect all links and nodes
                area_links::Vector{EMB.Link} = Vector{EMB.Link}(undef,length(systems[:links]))
                area_nodes::Vector{EMB.Node} = Vector{EMB.Node}(undef,length(systems[:nodes])) 

                area_nodes[1] = area_An

                indices::Vector{Int} = [1,2] # Create counting indeces for area_links and area_nodes respectively

                getLinkedNodes!(area_An, systems, area_links, area_nodes, indices)
                resize!(area_links, indices[1]-1)
                resize!(area_nodes, indices[2]-1)
                this_sys = Dict(:node => system,:links => area_links, :nodes => area_nodes)
            else
                this_sys = Dict(:node => system)
            end
            push!(kwargs_pair, :icon => find_icon(this_sys, idToIconMap))
            push!(kwargs_pair, :plotObj => plotObj)
        
            
            push!(
                children,
                EnergySystemDesign(this_sys; design_path, NamedTuple(kwargs_pair)...),
            )
        end
    end
end