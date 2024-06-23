"""
    clear_selection(gui::GUI; clear_topo=true, clear_results=true)

Clear the color selection of components within 'get_design(gui)' instance and reset the
`get_selected_systems(gui)` variable.
"""
function clear_selection(gui::GUI; clear_topo=true, clear_results=true)
    if clear_topo
        selected_systems = get_selected_systems(gui)
        for selection ∈ selected_systems
            toggle_selection_color!(gui, selection, false)
        end
        empty!(selected_systems)
        update_available_data_menu!(gui, nothing) # Make sure the menu is updated
    end
    if clear_results
        selected_plots = get_selected_plots(gui)
        for selection ∈ selected_plots
            toggle_selection_color!(gui, selection, false)
        end
        empty!(selected_plots)
    end
end

"""
    update!(gui::GUI)

Upon release of left mouse button update plots.
"""
function update!(gui::GUI)
    selected_systems = get_selected_systems(gui)
    updateplot = !isempty(selected_systems)

    if updateplot
        update!(gui, selected_systems[end]; updateplot=updateplot)
    else
        update!(gui, nothing; updateplot=updateplot)
    end
end

"""
    update!(gui::GUI, element::Plotable; updateplot::Bool=true)

Based on `element`, update the text in `get_axes(gui)[:info]` and update plot in
`get_axes(gui)[:results]` if `updateplot = true`
"""
function update!(gui::GUI, element::Plotable; updateplot::Bool=true)
    update_info_box!(gui, element)
    update_available_data_menu!(gui, element)
    if updateplot
        update_plot!(gui, element)
    end
end

"""
    update!(gui::GUI, connection::Connection; updateplot::Bool=true)

Based on `connection.connection`, update the text in `get_axes(gui)[:info]`
and update plot in `get_axes(gui)[:results]` if `updateplot = true`
"""
function update!(gui::GUI, connection::Connection; updateplot::Bool=true)
    return update!(gui, get_connection(connection); updateplot)
end

"""
    update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)

Based on `get_system_node(design)`, update the text in `get_axes(gui)[:info]`
and update plot in `get_axes(gui)[:results]` if `updateplot = true`
"""
function update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)
    return update!(gui, get_system_node(design); updateplot)
end

"""
    initialize_available_data!(gui)

For all plotable objects, initialize the available data menu with items.
"""
function initialize_available_data!(gui)
    system = get_root_design(gui).system
    model = get_model(gui)
    plotables = []
    append!(plotables, [nothing]) # nothing here represents no selection
    append!(plotables, system[:nodes])
    if haskey(system, :areas)
        append!(plotables, system[:areas])
    end
    append!(plotables, system[:links])
    if haskey(system, :transmission)
        append!(plotables, system[:transmission])
    end
    for element ∈ plotables
        # Find appearances of node/area/link/transmission in the model
        available_data = Vector{Dict}(undef, 0)
        if termination_status(model) == MOI.OPTIMAL # Plot results if available
            for dict ∈ collect(keys(object_dictionary(model)))
                if isempty(model[dict])
                    continue
                end
                if typeof(model[dict]) <: JuMP.Containers.DenseAxisArray
                    # nodes/areas found in structure
                    if any(eltype.(axes(model[dict])) .<: Union{EMB.Node,Area})
                        # only add dict if used by element (assume element is located at first Dimension)
                        if exists(model[dict], element)
                            if length(axes(model[dict])) > 2
                                for res ∈ model[dict].axes[3]
                                    container = Dict(
                                        :name => string(dict),
                                        :is_jump_data => true,
                                        :selection => [element, res],
                                    )
                                    key_str = "variables.$dict"
                                    add_description!(
                                        available_data, container, gui, key_str
                                    )
                                end
                            else
                                container = Dict(
                                    :name => string(dict),
                                    :is_jump_data => true,
                                    :selection => [element],
                                )
                                key_str = "variables.$dict"
                                add_description!(available_data, container, gui, key_str)
                            end
                        end
                    elseif any(eltype.(axes(model[dict])) .<: TransmissionMode) # element found in structure
                        if isa(element, Transmission)
                            for mode ∈ modes(element)
                                # only add dict if used by element (assume element is located at first Dimension)
                                if exists(model[dict], mode)
                                    # do not include element (<: Transmission) here
                                    # as the mode is unique to this transmission
                                    container = Dict(
                                        :name => string(dict),
                                        :is_jump_data => true,
                                        :selection => [mode],
                                    )
                                    key_str = "variables.$dict"
                                    add_description!(
                                        available_data, container, gui, key_str
                                    )
                                end
                            end
                        end
                    elseif isnothing(element)
                        if length(axes(model[dict])) > 1
                            for res ∈ model[dict].axes[2]
                                container = Dict(
                                    :name => string(dict),
                                    :is_jump_data => true,
                                    :selection => [res],
                                )
                                key_str = "variables.$dict"
                                add_description!(available_data, container, gui, key_str)
                            end
                        else
                            container = Dict(
                                :name => string(dict),
                                :is_jump_data => true,
                                :selection => EMB.Node[],
                            )
                            key_str = "variables.$dict"
                            add_description!(available_data, container, gui, key_str)
                        end
                    end
                elseif typeof(model[dict]) <: SparseVars
                    fieldtypes = typeof.(first(keys(model[dict].data)))
                    if any(fieldtypes .<: Union{EMB.Node,Link,Area}) # nodes/area/links found in structure
                        if exists(model[dict], element) # current element found in structure
                            extract_combinations!(gui, available_data, dict, element)
                        end
                    elseif any(fieldtypes .<: TransmissionMode) # TransmissionModes found in structure
                        if isa(element, Transmission)
                            for mode ∈ modes(element)
                                if exists(model[dict], mode) # current mode found in structure
                                    extract_combinations!(gui, available_data, dict, mode)
                                end
                            end
                        end
                    elseif isnothing(element)
                        extract_combinations!(gui, available_data, dict)
                    end
                end
            end
        end

        # Add timedependent input data (if available)
        if !isnothing(element)
            for field_name ∈ fieldnames(typeof(element))
                field = getfield(element, field_name)
                structure = String(nameof(typeof(element)))
                name = "$field_name"
                key_str = "structures.$structure.$name"
                add_description!(field, name, key_str, "", element, available_data, gui)
            end
        end
        get_available_data(gui)[element] = Dict(
            :container => available_data,
            :container_strings => create_label.(available_data),
        )
    end
end

"""
    update_available_data_menu!(gui::GUI, element::Plotable)

Update the `get_menus(gui)[:available_data]` with the available data of `element`.
"""
function update_available_data_menu!(gui::GUI, element::Plotable)
    available_data = get_available_data(gui)
    container = available_data[element][:container]
    container_strings = available_data[element][:container_strings]
    get_menu(gui, :available_data).options = zip(container_strings, container)
end
