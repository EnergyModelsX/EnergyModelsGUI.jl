"""
    run_through_all(gui::GUI)

Loop through all components of get_root_design(gui) and display all available data
"""
function run_through_all(gui::GUI; break_after_first::Bool=true)
    @info "Running through all components"
    return run_through_all(gui, get_root_design(gui), break_after_first)
end

"""
    run_through_all(gui::GUI, design::EnergySystemDesign)

Loop through all components of design and display all available data
"""
function run_through_all(gui::GUI, design::EnergySystemDesign, break_after_first::Bool)
    for component ∈ get_components(design)
        empty!(get_selected_systems(gui))
        push!(get_selected_systems(gui), component)
        notify(get_buttons(gui)[:open].clicks) # Open component

        if isempty(component.components) # no sub system found
            update!(gui)
            for i_selected ∈ 1:length(get_menus(gui)[:available_data].options[])
                get_menus(gui)[:available_data].i_selected = i_selected # Select flow_out (CO2)
                if break_after_first
                    break
                end
                #sleep(0.1)
            end
        else
            run_through_all(gui, component, break_after_first)
        end
        if break_after_first
            break
        end
    end
    for connection ∈ get_connections(design)
        empty!(get_selected_systems(gui))
        push!(get_selected_systems(gui), connection[3])
        notify(get_buttons(gui)[:open].clicks) # Open component
        update!(gui)
        for i_selected ∈ 1:length(get_menus(gui)[:available_data].options[])
            get_menus(gui)[:available_data].i_selected = i_selected # Select flow_out (CO2)
            #sleep(0.1)
            if break_after_first
                break
            end
        end
        if break_after_first
            break
        end
    end
end
