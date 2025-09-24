"""
    run_through_all(gui::GUI)

Loop through all components of get_root_design(gui) and display all available data.
"""
function run_through_all(
    gui::GUI;
    break_after_first::Bool = true,
    sleep_time::Float64 = 0.1,
)
    @info "Running through all components"

    run_through_all(
        gui,
        EMGUI.get_root_design(gui),
        break_after_first,
        1,
        sleep_time,
    )
end

"""
    run_through_all(gui::GUI, design::EnergySystemDesign)

Loop through all components of design and display all available data.
"""
function run_through_all(
    gui::GUI,
    design::EnergySystemDesign,
    break_after_first::Bool,
    level::Int,
    sleep_time::Float64,
)
    indent_spacing = "  "
    available_data_menu = EMGUI.get_menu(gui, :available_data)
    for component ∈ EMGUI.get_components(design)
        @info indent_spacing^level *
              "Running through component $(EMGUI.get_ref_element(component))"
        EMGUI.clear_selection(gui; clear_topo = true)
        EMGUI.pick_component!(gui, component; pick_topo_component = true)

        EMGUI.update!(gui)
        run_through_menu(
            available_data_menu,
            indent_spacing,
            level,
            break_after_first,
            sleep_time,
        )
        if !isempty(component.components) # no sub system found
            notify(EMGUI.get_button(gui, :open).clicks)
            run_through_all(gui, component, break_after_first, level + 1, sleep_time)
            notify(EMGUI.get_button(gui, :up).clicks)
        end
        if break_after_first
            break
        end
    end
    for connection ∈ EMGUI.get_connections(design)
        @info indent_spacing^level *
              "Running through connection $(EMGUI.get_element(connection))"
        EMGUI.clear_selection(gui; clear_topo = true)
        EMGUI.pick_component!(gui, connection; pick_topo_component = true)
        EMGUI.update!(gui)
        run_through_menu(
            available_data_menu,
            indent_spacing,
            level,
            break_after_first,
            sleep_time,
        )
        if break_after_first
            break
        end
    end
end

function run_through_menu(
    available_data_menu::EMGUI.Menu,
    indent_spacing::String,
    level::Int,
    break_after_first::Bool,
    sleep_time::Float64,
)
    for i_selected ∈ 1:length(available_data_menu.options[])
        available_data_menu.i_selected = i_selected
        sleep(sleep_time)
        if break_after_first
            break
        end
    end
end
