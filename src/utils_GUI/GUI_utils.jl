"""
    clear_selection(gui::GUI; clear_topo=true, clear_results=true)

Clear the color selection of components within 'gui.design' instance and reset the
`gui.vars[:selected_systems]` variable.
"""
function clear_selection(gui::GUI; clear_topo=true, clear_results=true)
    if clear_topo
        for selection ∈ gui.vars[:selected_systems]
            toggle_selection_color!(gui, selection, false)
        end
        empty!(gui.vars[:selected_systems])
        update_available_data_menu!(gui, nothing) # Make sure the menu is updated
    end
    if clear_results
        for selection ∈ gui.vars[:selected_plots]
            toggle_selection_color!(gui, selection, false)
        end
        empty!(gui.vars[:selected_plots])
    end
end

"""
    update!(gui::GUI)

Upon release of left mouse button update plots.
"""
function update!(gui::GUI)
    selected_systems = gui.vars[:selected_systems]
    updateplot = !isempty(selected_systems)

    if updateplot
        update!(gui, selected_systems[end]; updateplot=updateplot)
    else
        update!(gui, nothing; updateplot=updateplot)
    end
end

"""
    update!(gui::GUI, node::Plotable; updateplot::Bool=true)

Based on `node`, update the text in `gui.axes[:info]` and update plot in
`gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, node::Plotable; updateplot::Bool=true)
    update_info_box!(gui, node)
    update_available_data_menu!(gui, node)
    if updateplot
        update_plot!(gui, node)
    end
end

"""
    update!(gui::GUI, connection::Connection; updateplot::Bool=true)

Based on `connection.connection`, update the text in `gui.axes[:info]`
and update plot in `gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, connection::Connection; updateplot::Bool=true)
    return update!(gui, connection.connection; updateplot)
end

"""
    update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)

Based on `design.system[:node]`, update the text in `gui.axes[:info]`
and update plot in `gui.axes[:results]` if `updateplot = true`
"""
function update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)
    return update!(gui, design.system[:node]; updateplot)
end

"""
    initialize_available_data!(gui)

For all plotable objects, initialize the available data menu with items.
"""
function initialize_available_data!(gui)
    system = gui.root_design.system
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
    for node ∈ plotables
        # Find appearances of node/area/link/transmission in the model
        available_data = Vector{Dict}(undef, 0)
        if termination_status(gui.model) == MOI.OPTIMAL # Plot results if available
            for dict ∈ collect(keys(object_dictionary(gui.model)))
                if isempty(gui.model[dict])
                    continue
                end
                if typeof(gui.model[dict]) <: JuMP.Containers.DenseAxisArray
                    # nodes/areas found in structure
                    if any(eltype.(axes(gui.model[dict])) .<: Union{EMB.Node,EMG.Area})
                        # only add dict if used by node (assume node are located at first Dimension)
                        if exists(gui.model[dict], node)
                            if length(axes(gui.model[dict])) > 2
                                for res ∈ gui.model[dict].axes[3]
                                    container = Dict(
                                        :name => string(dict),
                                        :is_jump_data => true,
                                        :selection => [node, res],
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
                                    :selection => [node],
                                )
                                key_str = "variables.$dict"
                                add_description!(available_data, container, gui, key_str)
                            end
                        end
                    elseif any(eltype.(axes(gui.model[dict])) .<: EMG.TransmissionMode) # nodes found in structure
                        if isa(node, EMG.Transmission)
                            for mode ∈ modes(node)
                                # only add dict if used by node (assume node are located at first Dimension)
                                if exists(gui.model[dict], mode)
                                    # do not include node (<: EMG.Transmission) here
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
                    elseif isnothing(node)
                        if length(axes(gui.model[dict])) > 1
                            for res ∈ gui.model[dict].axes[2]
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
                elseif typeof(gui.model[dict]) <: SparseVars
                    fieldtypes = typeof.(first(keys(gui.model[dict].data)))
                    if any(fieldtypes .<: Union{EMB.Node,EMB.Link,EMG.Area}) # nodes/area/links found in structure
                        if exists(gui.model[dict], node) # current node found in structure
                            extract_combinations!(
                                gui, available_data, dict, node, gui.model
                            )
                        end
                    elseif any(fieldtypes .<: EMG.TransmissionMode) # TransmissionModes found in structure
                        if isa(node, EMG.Transmission)
                            for mode ∈ modes(node)
                                if exists(gui.model[dict], mode) # current mode found in structure
                                    extract_combinations!(
                                        gui, available_data, dict, mode, gui.model
                                    )
                                end
                            end
                        end
                    elseif isnothing(node)
                        extract_combinations!(gui, available_data, dict, gui.model)
                    end
                end
            end
        end

        # Add timedependent input data (if available)
        if !isnothing(node)
            for field_name ∈ fieldnames(typeof(node))
                field = getfield(node, field_name)
                structure = String(nameof(typeof(node)))
                name = "$field_name"
                key_str = "structures.$structure.$name"
                add_description!(field, name, key_str, "", node, available_data, gui)
            end
        end
        gui.vars[:available_data][node] = Dict(
            :container => available_data,
            :container_strings => create_label.(available_data),
        )
    end
end

"""
    update_available_data_menu!(gui::GUI, node::Plotable)

Update the `gui.menus[:available_data]` with the available data of `node`.
"""
function update_available_data_menu!(gui::GUI, node::Plotable)
    container = gui.vars[:available_data][node][:container]
    container_strings = gui.vars[:available_data][node][:container_strings]
    return gui.menus[:available_data].options = zip(container_strings, container)
end
