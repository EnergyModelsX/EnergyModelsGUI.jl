module EMGExt

using TimeStruct
using EnergyModelsBase
using EnergyModelsInvestments
using EnergyModelsGeography

# Use GLMakie to get the GridLayout type
using GLMakie

using EnergyModelsGUI

using DataFrames

const TS = TimeStruct
const EMG = EnergyModelsGeography
const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const EMGUI = EnergyModelsGUI

"""
    EMG.get_areas(system::SystemGeo)

Returns the `Area`s of a `SystemGeo` `system`.
"""
EMG.get_areas(system::EMGUI.SystemGeo) = EMGUI.get_children(system)

"""
    EMG.get_transmissions(system::EMGUI.SystemGeo)

Returns the `Transmission`s of a `SystemGeo` `system`.
"""
EMG.get_transmissions(system::EMGUI.SystemGeo) = EMGUI.get_connections(system)

"""
    get_modes(system::EMGUI.SystemGeo)

Get all transmission modes of a `SystemGeo` `system`.
"""
function get_modes(system::EMGUI.SystemGeo)
    transmission_modes = Vector{TransmissionMode}()
    for t ∈ get_transmissions(system)
        append!(transmission_modes, modes(t))
    end
    return transmission_modes
end

############################################################################################
## From datastructures.jl
"""
    EMB.get_links(system::EMGUI.SystemGeo)

Returns the `Links`s of a `SystemGeo` `system`.
"""
EMG.get_links(system::EMGUI.SystemGeo) =
    filter(el -> isa(el, Vector{<:Link}), get_elements_vec(system))[1]

"""
    EMB.get_nodes(system::EMGUI.SystemGeo)

Returns the `Node`s of a `SystemGeo` `system`.
"""
EMB.get_nodes(system::EMGUI.SystemGeo) =
    filter(el -> isa(el, Vector{<:EMB.Node}), get_elements_vec(system))[1]

"""
    EMGUI.SystemGeo(case::Case)

Initialize a `SystemGeo` from a `Case`.
"""
function EMGUI.SystemGeo(case::Case)
    areas = get_areas(case)
    ref_element = areas[1]
    return EMGUI.SystemGeo(
        get_time_struct(case),
        get_products(case),
        get_elements_vec(case),
        areas,
        get_transmissions(case),
        EMGUI.NothingElement(),
        ref_element,
    )
end

"""
    EMGUI.get_plotables(system::EMGUI.SystemGeo)

Get all plotable elements of a `SystemGeo` `system`, which includes nodes, links, areas, and modes.
"""
function EMGUI.get_plotables(system::EMGUI.SystemGeo)
    return vcat(
        get_nodes(system),
        get_links(system),
        get_areas(system),
        get_modes(system),
    )
end

############################################################################################
## From structure_utils.jl
"""
    EMGUI.get_resource_colors(l::Vector{Transmission}, id_to_color_map::Dict{Any,Any})

Get the colors linked to the resources in the transmission `l` (from modes(Transmission))
based on the mapping `id_to_color_map`.
"""
function EMGUI.get_resource_colors(l::Transmission, id_to_color_map::Dict{Any,Any})
    resources::Vector{Resource} = [map_trans_resource(mode) for mode ∈ l.modes]
    return EMGUI.get_resource_colors(resources, id_to_color_map)
end

############################################################################################
## From utils.jl
"""
    EMGUI.get_max_installed(m::TransmissionMode, t::Vector{<:TS.TimeStructure})

Get the maximum capacity installable by an investemnt.
"""
function EMGUI.get_max_installed(m::TransmissionMode, t::Vector{<:TS.TimeStructure})
    if EMI.has_investment(m)
        time_profile = EMI.max_installed(EMI.investment_data(m, :cap))
        return maximum(time_profile[t])
    else
        return 0.0
    end
end
function EMGUI.get_max_installed(trans::Transmission, t::Vector{<:TS.TimeStructure})
    return maximum([EMGUI.get_max_installed(m, t) for m ∈ modes(trans)])
end

############################################################################################
## From setup_topology.jl
"""
    EMGUI.sub_system(system::EMGUI.SystemGeo, element::AbstractElement)

Create a sub-system of `system` with the `element` as the availability node.
"""
function EMGUI.sub_system(system::EMGUI.SystemGeo, element::AbstractElement)
    # Get all nodes and links in the area directly or indirectly connected by `Link`s to `element`.
    area_nodes::Vector{EMB.Node}, area_links::Vector{Link} =
        EMG.nodes_in_area(element, get_links(system); n_nodes = length(get_nodes(system)))

    return EMGUI.System(
        get_time_struct(system),
        get_products(system),
        get_elements_vec(system),
        area_nodes,
        area_links,
        element,
        availability_node(element),
    )
end

############################################################################################
## From topo_axis_utils.jl
"""
    EMGUI.get_element_label(element)

Get the label of the element based on its `id` field. If the `id` is a number it returns the
built in Base.display() functionality of node, otherwise, the `id` field is converted to a string.
"""
function EMGUI.get_element_label(element::Union{Area,TransmissionMode})
    return isa(element.id, Number) ? string(element) : string(element.id)
end
function EMGUI.get_element_label(element::Transmission)
    return EMGUI.get_element_label(element.from) * "-" * EMGUI.get_element_label(element.to)
end

"""
    EMGUI.get_linestyle(gui::GUI, transmission::Transmission)

Get the line style for an Transmission `transmission` based on its properties.
"""
function EMGUI.get_linestyle(gui::GUI, transmission::Transmission)
    return [
        EMI.has_investment(m) ? EMGUI.get_var(gui, :investment_lineStyle) : :solid for
        m ∈ modes(transmission)
    ]
end

############################################################################################
## From GUI_utils.jl
"""
    EMGUI.get_mode_to_transmission_map(system::EMGUI.SystemGeo)

Get the mapping between modes and transmissions for a `SystemGeo`.
"""
function EMGUI.get_mode_to_transmission_map(system::EMGUI.SystemGeo)
    mode_to_transmission = Dict()
    for t ∈ get_transmissions(system)
        for m ∈ modes(t)
            mode_to_transmission[m] = t
        end
    end
    return mode_to_transmission
end

"""
    _type_to_header(::Type{<:TransmissionMode})

Map types to header symbols for saving results.
"""
EMGUI._type_to_header(::Type{<:TransmissionMode}) = :element
end
