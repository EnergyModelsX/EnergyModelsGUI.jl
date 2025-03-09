module EMGExt

using TimeStruct
using EnergyModelsBase
using EnergyModelsInvestments
using EnergyModelsGeography

# Use GLMakie to get the GridLayout type
using GLMakie

using EnergyModelsGUI

const TS = TimeStruct
const EMG = EnergyModelsGeography
const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const EMGUI = EnergyModelsGUI

############################################################################################
## From datastructures.jl
"""
    EMGUI.get_transmissions(system::System)

Returns the `Transmission`s of a `System` `system`.
"""
EMGUI.get_transmissions(system::EMGUI.SystemGeo) =
    filter(el -> isa(el, Vector{<:Transmission}), EMGUI.get_elements_vec(system))[1]

"""
    EMGUI.SystemGeo(case::Case)

Initialize a `SystemGeo` from a `Case`.
"""
function EMGUI.SystemGeo(case::Case)
    areas = EMG.get_areas(case)
    ref_element = areas[1]
    return EMGUI.SystemGeo(
        EMB.get_time_struct(case),
        EMB.get_products(case),
        EMB.get_elements_vec(case),
        areas,
        EMG.get_transmissions(case),
        EMGUI.NothingElement(),
        ref_element,
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
    EMGUI.get_max_installed(m::EMG.TransmissionMode, t::Vector{<:TS.TimeStructure})

Get the maximum capacity installable by an investemnt.
"""
function EMGUI.get_max_installed(m::EMG.TransmissionMode, t::Vector{<:TS.TimeStructure})
    if EMI.has_investment(m)
        time_profile = EMI.max_installed(EMI.investment_data(m, :cap))
        return maximum(time_profile[t])
    else
        return 0.0
    end
end
function EMGUI.get_max_installed(trans::EMG.Transmission, t::Vector{<:TS.TimeStructure})
    return maximum([EMGUI.get_max_installed(m, t) for m ∈ modes(trans)])
end

############################################################################################
## From setup_topology.jl
"""
    EMGUI.sub_system(system::EMGUI.SystemGeo, element::AbstractElement)

Create a sub-system of `system` with the `element` as the availability node.
"""
function EMGUI.sub_system(system::EMGUI.SystemGeo, element::AbstractElement)
    area_an::EMB.Node = availability_node(element)

    # Allocate redundantly large vector (for efficiency) to collect all links and nodes
    links::Vector{Link} = EMGUI.get_links(system)
    area_links::Vector{Link} = Vector{Link}(undef, length(links))
    area_nodes::Vector{EMB.Node} = Vector{EMB.Node}(
        undef, length(EMGUI.get_nodes(system)),
    )

    area_nodes[1] = area_an

    # Create counting indices for area_links and area_nodes respectively
    indices::Vector{Int} = [1, 2]

    EMGUI.get_linked_nodes!(area_an, links, area_links, area_nodes, indices)
    resize!(area_links, indices[1] - 1)
    resize!(area_nodes, indices[2] - 1)
    return EMGUI.System(
        EMGUI.get_time_struct(system),
        EMGUI.get_products(system),
        EMGUI.get_elements_vec(system),
        area_nodes,
        area_links,
        element,
        area_an,
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
    for t ∈ EMGUI.get_transmissions(system)
        for m ∈ modes(t)
            mode_to_transmission[m] = t
        end
    end
    return mode_to_transmission
end
end
