"""
    run_through_all(gui::GUI)

Loop through all components of gui.root_design and display all available data
"""
function run_through_all(gui::GUI; break_after_first::Bool=true)
    @info "Running through all components"
    return run_through_all(gui, gui.root_design, break_after_first)
end

"""
    run_through_all(gui::GUI, design::EnergySystemDesign)

Loop through all components of design and display all available data
"""
function run_through_all(gui::GUI, design::EnergySystemDesign, break_after_first::Bool)
    for component ∈ design.components
        empty!(gui.vars[:selected_systems])
        push!(gui.vars[:selected_systems], component)
        notify(gui.buttons[:open].clicks) # Open component

        if isempty(component.components) # no sub system found
            update!(gui)
            for i_selected ∈ 1:length(gui.menus[:available_data].options[])
                gui.menus[:available_data].i_selected = i_selected # Select flow_out (CO2)
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
    for connection ∈ design.connections
        empty!(gui.vars[:selected_systems])
        push!(gui.vars[:selected_systems], connection[3])
        notify(gui.buttons[:open].clicks) # Open component
        update!(gui)
        for i_selected ∈ 1:length(gui.menus[:available_data].options[])
            gui.menus[:available_data].i_selected = i_selected # Select flow_out (CO2)
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
