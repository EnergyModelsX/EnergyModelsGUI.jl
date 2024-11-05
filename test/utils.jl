"""
    run_through_all(gui::GUI)

Loop through all components of get_root_design(gui) and display all available data.
"""
function run_through_all(gui::GUI; break_after_first::Bool=true)
    @info "Running through all components"
    return run_through_all(gui, get_root_design(gui), break_after_first)
end

"""
    run_through_all(gui::GUI, design::EnergySystemDesign)

Loop through all components of design and display all available data.
"""
function run_through_all(gui::GUI, design::EnergySystemDesign, break_after_first::Bool)
    available_data_menu = get_menu(gui, :available_data)
    for component ∈ get_components(design)
        clear_selection(gui; clear_topo=true)
        pick_component!(gui, component; pick_topo_component=true)

        if isempty(component.components) # no sub system found
            update!(gui)
            for i_selected ∈ 1:length(available_data_menu.options[])
                available_data_menu.i_selected = i_selected
                if break_after_first
                    break
                end
            end
        else
            run_through_all(gui, component, break_after_first)
        end
        if break_after_first
            break
        end
    end
    for connection ∈ get_connections(design)
        clear_selection(gui; clear_topo=true)
        pick_component!(gui, connection; pick_topo_component=true)
        update!(gui)
        for i_selected ∈ 1:length(available_data_menu.options[])
            available_data_menu.i_selected = i_selected
            if break_after_first
                break
            end
        end
        if break_after_first
            break
        end
    end
end
