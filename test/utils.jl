import EnergyModelsGUI:
    get_root_design,
    get_component,
    get_components,
    get_connections,
    get_selection_color,
    get_ref_element,
    get_element,
    get_menu,
    get_button,
    update!,
    BLACK,
    Connection,
    pick_component!,
    clear_selection!,
    toggle_selection_color!,
    get_plots,
    get_selected_systems,
    get_selected_plots,
    get_visible_data,
    get_simplified_plots,
    get_vars,
    get_var,
    get_xy,
    get_toggle,
    get_ax,
    update_info_box!,
    update_available_data_menu!,
    update_sub_system_locations!,
    get_design,
    get_vis_plots,
    get_plotted_data,
    select_data!

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
        get_root_design(gui),
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
    available_data_menu = get_menu(gui, :available_data)
    for component ∈ get_components(design)
        @info indent_spacing^level *
              "Running through component $(get_ref_element(component))"
        clear_selection!(gui, :topo)
        pick_component!(gui, component, :topo)
        update!(gui)
        run_through_menu(
            available_data_menu,
            indent_spacing,
            level,
            break_after_first,
            sleep_time,
        )
        if !isempty(get_components(component)) # no sub system found
            notify(get_button(gui, :open).clicks)
            run_through_all(gui, component, break_after_first, level + 1, sleep_time)
            notify(get_button(gui, :up).clicks)
        end
        if break_after_first
            break
        end
    end
    for connection ∈ get_connections(design)
        @info indent_spacing^level *
              "Running through connection $(get_element(connection))"
        clear_selection!(gui, :topo)
        pick_component!(gui, connection, :topo)
        update!(gui)
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

function test_connection_colors(gui::GUI, connection::Connection, type::Symbol)
    plt_connection = get_plots(connection)
    if type == :black || type == :selection_color
        expected_color = type == :black ? BLACK : get_selection_color(gui)

        @test all(
            all(plot.color[] .== expected_color) for plot ∈ plt_connection
        )
    elseif type == :regular_colors
        i::Int64 = 1
        no_colors::Int64 = length(connection.colors)
        for plot ∈ plt_connection
            if isa(plot.color[], Vector)
                @test plot.color[] == connection.colors
            else
                @test plot.color[] == connection.colors[((i-1)%no_colors)+1]
                i += 1
            end
        end
    end
end

function test_connections_colors(gui::GUI, connections::Vector{Connection}, type::Symbol)
    for connection ∈ connections
        test_connection_colors(gui, connection, type)
    end
end

function test_connections_colors(
    gui::GUI,
    components::Vector{EnergySystemDesign},
    type::Symbol,
)
    for component ∈ components
        test_connections_colors(gui, get_connections(component), type)
    end
end

function test_all_connection_colors(gui::GUI, type::Symbol)
    design = get_root_design(gui)
    components = get_components(design)
    connections = get_connections(design)

    test_connections_colors(gui, connections, type)
    for component ∈ components
        test_connections_colors(gui, get_connections(component), type)
    end
end

"""
    fetch_element(elements::Vector, id)

Fetch the element with the given `id` from the `elements` array.
"""
function fetch_element(elements::Vector, id)
    for element ∈ elements
        if element.id == id
            return element
        end
    end
    error("Element with id $id not found")
end
