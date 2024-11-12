"""
    define_event_functions(gui::GUI)

Define event functions (handling button clicks, plot updates, etc.) for the GUI `gui`.
"""
function define_event_functions(gui::GUI)
    # Create a function that notifies all components (and thus updates graphics
    # when the observables are notified)
    notify_components = () -> begin
        for component ∈ get_root_design(gui).components
            notify(component.xy)
            if !isempty(component.components)
                for sub_component ∈ component.components
                    notify(sub_component.xy)
                end
            end
        end
    end

    ax_topo = get_ax(gui, :topo)
    ax_results = get_ax(gui, :results)
    ax_info = get_ax(gui, :info)
    ax_summary = get_ax(gui, :summary)

    # On zooming, make sure all graphics are adjusted acordingly
    on(ax_topo.finallimits; priority=10) do finallimits
        @debug "Changes in finallimits"
        widths::Vec = finallimits.widths
        origin::Vec = finallimits.origin
        get_vars(gui)[:xlimits] = [origin[1], origin[1] + widths[1]]
        get_vars(gui)[:ylimits] = [origin[2], origin[2] + widths[2]]
        update_distances!(gui)
        notify_components()
        get_var(gui, :topo_title_loc_x)[] = origin[1] + widths[1] / 100
        get_var(gui, :topo_title_loc_y)[] =
            origin[2] + widths[2] - widths[2] / 100 -
            pixel_to_data(gui, get_var(gui, :fontsize))[2]
        return Consume(false)
    end

    # Capture the final limits after a zoom operation
    on(ax_results.finallimits; priority=0) do finallimits
        time_axis = time_menu.selection[]
        gui.vars[:finallimits][time_axis] = finallimits
        return Consume(false)
    end

    # If the window is resized, make sure all graphics are adjusted acordingly
    fig = get_fig(gui)
    on(fig.scene.events.window_area; priority=3) do val
        @debug "Changes in window_area"
        get_vars(gui)[:plot_widths] = Tuple(fig.scene.viewport.val.widths)
        get_vars(gui)[:ax_aspect_ratio] =
            get_var(gui, :plot_widths)[1] /
            (get_var(gui, :plot_widths)[2] - get_var(gui, :taskbar_height)) / 2
        notify(ax_topo.finallimits)
        return Consume(false)
    end

    # Handle case when user is pressing/releasing any ctrl key (in order to select multiple components)
    on(events(ax_topo.scene).keyboardbutton; priority=3) do event
        # For more integers: using GLMakie; typeof(events(ax_topo.scene).keyboardbutton[].key)

        is_ctrl(key::Makie.Keyboard.Button) = Int(key) == 341 || Int(key) == 345 # any of the ctrl buttons is clicked
        if event.action == Keyboard.press
            ctrl_is_pressed = get_var(gui, :ctrl_is_pressed)[]
            if is_ctrl(event.key)
                # Register if any ctrl-key has been pressed
                get_var(gui, :ctrl_is_pressed)[] = true
            elseif Int(event.key) ∈ [262, 263, 264, 265] # arrow right, arrow left, arrow down or arrow up
                # move a component(s) using the arrow keys

                # get changes
                change::Tuple{Float64,Float64} = get_change(gui, Val(event.key))

                # check if any changes where made
                if change != (0.0, 0.0)
                    for sub_design ∈ get_selected_systems(gui)
                        xc::Real = sub_design.xy[][1]
                        yc::Real = sub_design.xy[][2]

                        sub_design.xy[] = (xc + change[1], yc + change[2])

                        update_sub_system_locations!(sub_design, change)
                    end

                    notify_components()
                end
            elseif Int(event.key) == 256 # Esc used to move up a level in the topology
                notify(get_button(gui, :up).clicks)
            elseif Int(event.key) == 32 # Space used to open up a sub-system
                notify(get_button(gui, :open).clicks)
            elseif Int(event.key) == 261 # Delete used to delete selected plot
                notify(get_button(gui, :remove_plot).clicks)
            elseif Int(event.key) == 82 # ctrl+r: Reset view
                if ctrl_is_pressed
                    notify(get_button(gui, :reset_view).clicks)
                end
            elseif Int(event.key) == 83 # ctrl+s: Save
                if ctrl_is_pressed
                    notify(get_button(gui, :save).clicks)
                end
            elseif Int(event.key) == 87 # ctrl+w: Close
                if ctrl_is_pressed
                    Threads.@spawn GLMakie.closeall()
                end
                #elseif Int(event.key) == 340 # Shift
                #elseif Int(event.key) == 342 # Alt
            end
        elseif event.action == Keyboard.release
            if is_ctrl(event.key)
                # Register if any ctrl-key has been released
                get_var(gui, :ctrl_is_pressed)[] = false
            end
        end
        return Consume(true)
    end

    last_click_time = Ref(Dates.now())

    # Define the double-click threshold
    double_click_threshold = Dates.Millisecond(500) # Default value in Windows

    # Alter scrolling functionality in text areas such that it does not zoom but translates in the y-direction
    on(events(ax_info).scroll; priority=4) do val
        mouse_pos::Tuple{Float64,Float64} = events(ax_info).mouseposition[]
        if mouse_within_axis(ax_info, mouse_pos)
            scroll_ylim(ax_info, val[2] * 0.1)
            return Consume(true)
        end
        if mouse_within_axis(ax_summary, mouse_pos)
            scroll_ylim(ax_summary, val[2] * 0.1)
            return Consume(true)
        end
        if mouse_within_axis(ax_results, mouse_pos)
            time_axis = time_menu.selection[]
            gui.vars[:autolimits][time_axis] = false
        end
        return Consume(false)
    end

    # Handle cases for mousebutton input
    on(events(ax_topo).mousebutton; priority=4) do event
        if event.button == Mouse.left
            current_click_time = Dates.now()
            time_difference = current_click_time - last_click_time[]
            dragging = get_var(gui, :dragging)
            if event.action == Mouse.press
                mouse_pos = events(ax_topo).mouseposition[]

                # Check if mouseclick is outside the ax_topo area (and return if so)
                ctrl_is_pressed = get_var(gui, :ctrl_is_pressed)[]
                if mouse_within_axis(ax_topo, mouse_pos)
                    if !ctrl_is_pressed && !isempty(get_selected_systems(gui))
                        clear_selection(gui; clear_results=false)
                    end

                    pick_component!(gui; pick_topo_component=true)
                    if time_difference < double_click_threshold
                        notify(get_button(gui, :open).clicks)
                        return Consume(true)
                    end
                    last_click_time[] = current_click_time

                    dragging[] = true
                    return Consume(true)
                end

                if mouse_within_axis(ax_results, mouse_pos)
                    time_axis = time_menu.selection[]
                    if !ctrl_is_pressed && !isempty(get_selected_plots(gui, time_axis))
                        clear_selection(gui; clear_topo=false)
                    end
                    pick_component!(gui; pick_results_component=true)
                    gui.vars[:autolimits][time_axis] = false
                    return Consume(false)
                end
                if mouse_within_axis(ax_info, mouse_pos)
                    return Consume(true)
                end
                if mouse_within_axis(ax_summary, mouse_pos)
                    return Consume(true)
                end
                return Consume(false)
            elseif event.action == Mouse.release
                if dragging[]
                    dragging[] = false
                    update!(gui::GUI)
                end
                return Consume(false)
            end
        elseif event.button == Mouse.button_4
            if event.action == Mouse.press
                notify(get_button(gui, :up).clicks)
                return Consume(true)
            end
        end
        if event.button == Mouse.right
            # Disable pan in text areas
            mouse_pos = events(ax_topo).mouseposition[]
            if mouse_within_axis(ax_info, mouse_pos)
                return Consume(true)
            end
            if mouse_within_axis(ax_results, mouse_pos)
                time_axis = time_menu.selection[]
                gui.vars[:autolimits][time_axis] = false
            end
            if mouse_within_axis(ax_summary, mouse_pos)
                return Consume(true)
            end
        end

        return Consume(false)
    end

    # Handle mouse movement
    on(events(ax_topo).mouseposition; priority=2) do mouse_pos # priority ≥ 2 in order to suppress GLMakie left-click and drag zoom feature
        if get_var(gui, :dragging)[]
            origin::Vec2{Int64} = pixelarea(ax_topo.scene)[].origin
            widths::Vec2{Int64} = pixelarea(ax_topo.scene)[].widths
            mouse_pos_loc::Vec2{Float64} = mouse_pos .- origin

            xy_widths::Vec2 = ax_topo.finallimits[].widths
            xy_origin::Vec2 = ax_topo.finallimits[].origin

            xy::Vec2{Float64} = xy_origin .+ mouse_pos_loc .* xy_widths ./ widths
            selected_systems = get_selected_systems(gui)
            if !isempty(selected_systems) && isa(selected_systems[1], EnergySystemDesign) # Only nodes/area can be moved (connections will update correspondinlgy)
                sub_design::EnergySystemDesign = selected_systems[1]

                update_sub_system_locations!(sub_design, Tuple(xy .- sub_design.xy[]))
                sub_design.xy[] = Tuple(xy)
            end
            return Consume(true)
        end

        return Consume(false)
    end

    # Align horizontally button: Handle click on the align horizontal button
    on(get_button(gui, :align_horizontal).clicks; priority=10) do clicks
        align(gui, :horizontal)
        return Consume(false)
    end

    # Align vertically button: Handle click on the align vertical button
    on(get_button(gui, :align_vertical).clicks; priority=10) do clicks
        align(gui, :vertical)
        return Consume(false)
    end

    # Open button: Handle click on the open button (open a sub system)
    on(get_button(gui, :open).clicks; priority=10) do clicks
        if !isempty(get_selected_systems(gui))
            get_vars(gui)[:expand_all] = false
            component = get_selected_systems(gui)[end] # Choose the last selected node
            if isa(component, EnergySystemDesign)
                if component.parent == :top_level
                    component.parent = if haskey(get_design(gui).system, :name)
                        get_design(gui).system[:name]
                    else
                        :top_level
                    end
                    plot_design!(
                        gui,
                        get_design(gui);
                        visible=false,
                        expand_all=get_var(gui, :expand_all),
                    )
                    gui.design = component
                    plot_design!(
                        gui,
                        get_design(gui);
                        visible=true,
                        expand_all=get_var(gui, :expand_all),
                    )
                    update_title!(gui)
                    clear_selection(gui)
                    notify(get_button(gui, :reset_view).clicks)
                end
            end
        end
        return Consume(false)
    end

    # Navigate up button: Handle click on the navigate up button (go back to the root_design)
    on(get_button(gui, :up).clicks; priority=10) do clicks
        if !isnothing(get_design(gui).parent)
            get_vars(gui)[:expand_all] = get_toggle(gui, :expand_all).active[]
            plot_design!(
                gui, get_design(gui); visible=false, expand_all=get_var(gui, :expand_all)
            )
            gui.design = get_root_design(gui)
            plot_design!(
                gui, get_design(gui); visible=true, expand_all=get_var(gui, :expand_all)
            )
            update_title!(gui)
            adjust_limits!(gui)
            notify(get_button(gui, :reset_view).clicks)
        end
        return Consume(false)
    end

    # Reset results view
    on(get_button(gui, :reset_view_results).clicks; priority=10) do _
        update_limits!(ax_results)
        time_axis = time_menu.selection[]
        gui.vars[:finallimits][time_axis] = ax_results.finallimits[]
        gui.vars[:autolimits][time_axis] = true
        return Consume(false)
    end

    # Pin current plot (the last plot added)
    time_menu = get_menu(gui, :time)
    on(get_button(gui, :pin_plot).clicks; priority=10) do _
        time_axis = time_menu.selection[]
        for plot_obj ∈ get_visible_data(gui, time_axis)
            if !plot_obj[:pinned]
                plot_obj[:pinned] = true
                @info "Current plot pinned"
                return Consume(true)
            end
        end
        @info "Plots already pinned"
        return Consume(false)
    end

    # Remove selected plot
    on(get_button(gui, :remove_plot).clicks; priority=10) do _
        time_axis = time_menu.selection[]
        if isempty(get_selected_plots(gui, time_axis))
            return Consume(false)
        end
        for selection ∈ get_selected_plots(gui, time_axis)
            selection[:plot].visible = false
            selection[:visible] = false
            selection[:pinned] = false
            toggle_selection_color!(gui, selection, false)
            @info "Removing plot with label: $(selection[:plot].label[])"
        end
        update_legend!(gui)
        update_barplot_dodge!(gui)
        if get_var(gui, :autolimits)[time_axis]
            update_limits!(ax_results)
            gui.vars[:finallimits][time_axis] = ax_results.finallimits[]
        end
        return Consume(false)
    end

    # Clear all plots
    on(get_button(gui, :clear_all).clicks; priority=10) do _
        @info "Clearing plots"
        time_axis = time_menu.selection[]
        for selection ∈ get_visible_data(gui, time_axis)
            selection[:plot].visible = false
            selection[:visible] = false
            selection[:pinned] = false
        end
        clear_selection(gui; clear_topo=false)
        update_legend!(gui)
        return Consume(false)
    end

    # Toggle expansion of all systems
    on(get_toggle(gui, :expand_all).active; priority=10) do val
        # Plot the topology
        get_vars(gui)[:expand_all] = val
        plot_design!(gui, get_design(gui); expand_all=val)
        update_distances!(gui)
        notify_components()
        return Consume(false)
    end

    # Save button: Handle click on the save button (save the altered coordinates)
    on(get_button(gui, :save).clicks; priority=10) do clicks
        save_design(get_design(gui))
        return Consume(false)
    end

    # Reset button: Reset view to the original view
    on(get_button(gui, :reset_view).clicks; priority=10) do clicks
        adjust_limits!(gui)
        notify(ax_topo.finallimits)
        return Consume(false)
    end

    # Export button: Export ax_results to file (format given by export_type_menu.selection[])
    on(get_button(gui, :export).clicks; priority=10) do _
        if get_menu(gui, :export_type).selection[] == "REPL"
            axes_str::String = get_menu(gui, :axes).selection[]
            if axes_str == "Plots"
                time_axis = time_menu.selection[]
                vis_plots = get_visible_data(gui, time_axis)
                if !isempty(vis_plots) # Check if any plots exist
                    t = vis_plots[1][:t]
                    data = Matrix{Any}(undef, length(t), length(vis_plots) + 1)
                    data[:, 1] = t
                    header = (
                        Vector{Any}(undef, length(vis_plots) + 1),
                        Vector{Any}(undef, length(vis_plots) + 1),
                    )
                    header[1][1] = "t"
                    header[2][1] = "(" * string(nameof(eltype(t))) * ")"
                    for (j, vis_plot) ∈ enumerate(vis_plots)
                        data[:, j + 1] = vis_plot[:y]
                        header[1][j + 1] = vis_plots[j][:name]
                        header[2][j + 1] = join(
                            [string(x) for x ∈ vis_plots[j][:selection]], ", "
                        )
                    end
                    println("\n")  # done in order to avoid the prompt shifting the topspline of the table
                    pretty_table(data; header=header)
                end
            elseif axes_str == "All"
                model = get_model(gui)
                for sym ∈ get_JuMP_names(gui)
                    container = model[sym]
                    if isempty(container)
                        continue
                    end
                    if typeof(container) <: JuMP.Containers.DenseAxisArray
                        axis_types = nameof.([eltype(a) for a ∈ JuMP.axes(model[sym])])
                    elseif typeof(container) <: SparseVars
                        axis_types = collect(nameof.(typeof.(first(keys(container.data)))))
                    end
                    header = vcat(axis_types, [:value])
                    pretty_table(JuMP.Containers.rowtable(value, container; header=header))
                end
            end
        else
            export_to_file(gui)
        end
        return Consume(false)
    end

    # Time menu: Handle menu selection (selecting time)
    on(time_menu.selection; priority=10) do time_axis
        plotted_data = get_plotted_data(gui)
        if !isempty(plotted_data)
            for x ∈ plotted_data
                if x[:time_axis] == time_axis && x[:visible]
                    x[:plot].visible[] = true
                else
                    x[:plot].visible[] = false
                end
            end
            update_legend!(gui)
            time_axis = time_menu.selection[]
            update_limits!(ax_results, get_var(gui, :finallimits)[time_axis])
            update_axis!(gui, time_axis)
        end
        return Consume(false)
    end

    T = get_design(gui).system[:T]

    # Period menu: Handle menu selection (selecting period)
    period_menu = get_menu(gui, :period)
    scenario_menu = get_menu(gui, :scenario)
    representative_period_menu = get_menu(gui, :representative_period)
    on(period_menu.selection; priority=10) do _
        # Initialize representative_periods to be the representative_periods of the first operational period
        current_representative_period = representative_period_menu.selection[]
        representative_periods_in_sp = get_representative_period_indices(
            T, period_menu.selection[]
        )
        representative_period_menu.options = zip(
            get_var(gui, :representative_periods_labels)[representative_periods_in_sp],
            representative_periods_in_sp,
        )

        # If previously chosen representative_period is out of range, update it to be the largest number available
        if length(representative_periods_in_sp) < current_representative_period
            representative_period_menu.i_selected = length(representative_periods_in_sp)
        end

        current_scenario = scenario_menu.selection[]
        scenarios_in_rp = get_scenario_indices(
            T, period_menu.selection[], representative_period_menu.selection[]
        )
        scenario_menu.options = zip(
            get_var(gui, :scenarios_labels)[scenarios_in_rp], scenarios_in_rp
        )

        # If previously chosen scenario is out of range, update it to be the largest number available
        if length(scenarios_in_rp) < current_scenario
            scenario_menu.i_selected = length(scenarios_in_rp)
        end
        update_plot!(gui)
        return Consume(false)
    end

    # Representative period menu: Handle menu selection
    on(representative_period_menu.selection; priority=10) do _
        # Initialize representative_periods to be the representative_periods of the first operational period
        current_representative_period = representative_period_menu.selection[]
        if isnothing(current_representative_period)
            return Consume(false)
        end
        current_scenario = scenario_menu.selection[]
        scenarios_in_rp = get_scenario_indices(
            T, period_menu.selection[], current_representative_period
        )
        scenario_menu.options = zip(
            get_var(gui, :scenarios_labels)[scenarios_in_rp], scenarios_in_rp
        )

        # If previously chosen scenario is out of range, update it to be the largest number available
        if length(scenarios_in_rp) < current_scenario
            scenario_menu.i_selected = length(scenarios_in_rp)
        end
        update_plot!(gui)
        return Consume(false)
    end

    # Scenario menu: Handle menu selection
    on(scenario_menu.selection; priority=10) do _
        current_scenario = scenario_menu.selection[]
        if isnothing(current_scenario)
            return Consume(false)
        end
        update_plot!(gui)
        return Consume(false)
    end

    # Available data menu: Handle menu selection (selecting available data)
    on(get_menu(gui, :available_data).selection; priority=10) do val
        if !isnothing(val)
            update_plot!(gui)
        end
        return Consume(false)
    end
end
