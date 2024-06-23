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

    # On zooming, make sure all graphics are adjusted acordingly
    on(get_ax(gui, :topo).finallimits; priority=10) do finallimits
        @debug "Changes in finallimits"
        widths::Vec{2,Float32} = finallimits.widths
        origin::Vec{2,Float32} = finallimits.origin
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

    # If the window is resized, make sure all graphics are adjusted acordingly
    fig = get_fig(gui)
    on(fig.scene.events.window_area; priority=3) do val
        @debug "Changes in window_area"
        get_vars(gui)[:plot_widths] = Tuple(fig.scene.px_area.val.widths)
        get_vars(gui)[:ax_aspect_ratio] =
            get_var(gui, :plot_widths)[1] /
            (get_var(gui, :plot_widths)[2] - get_var(gui, :taskbar_height)) / 2
        notify(get_ax(gui, :topo).finallimits)
        return Consume(false)
    end

    # Handle case when user is pressing/releasing any ctrl key (in order to select multiple components)
    on(events(get_ax(gui, :topo).scene).keyboardbutton; priority=3) do event
        # For more integers: using GLMakie; typeof(events(get_ax(gui,:topo).scene).keyboardbutton[].key)

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

                        update_sub_system_locations!(sub_design, Tuple(change))
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
                get_vars(gui, :ctrl_is_pressed)[] = false
            end
        end
        return Consume(true)
    end

    last_click_time = Ref(Dates.now())

    # Define the double-click threshold
    double_click_threshold = Dates.Millisecond(500) # Default value in Windows

    # Handle cases for mousebutton input
    on(events(get_ax(gui, :topo)).mousebutton; priority=4) do event
        if event.button == Mouse.left
            current_click_time = Dates.now()
            time_difference = current_click_time - last_click_time[]
            dragging = get_var(gui, :dragging)
            if event.action == Mouse.press
                # Make sure selections are not removed when left-clicking outside axes[:topo]
                mouse_pos::Tuple{Float64,Float64} = events(get_ax(gui, :topo)).mouseposition[]

                origin::Vec2{Int64} = pixelarea(get_ax(gui, :topo).scene)[].origin
                widths::Vec2{Int64} = pixelarea(get_ax(gui, :topo).scene)[].widths
                mouse_pos_loc::Vec2{Float64} = mouse_pos .- origin

                # Check if mouseclick is outside the get_ax(gui,:topo) area (and return if so)
                ctrl_is_pressed = get_var(gui, :ctrl_is_pressed)[]
                if all(mouse_pos_loc .> 0.0) && all(mouse_pos_loc .- widths .< 0.0)
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
                else
                    time_axis = get_menu(gui, :time).selection[]
                    origin = pixelarea(get_ax(gui, time_axis).scene)[].origin
                    widths = pixelarea(get_ax(gui, time_axis).scene)[].widths
                    mouse_pos_loc = mouse_pos .- origin

                    if all(mouse_pos_loc .> 0.0) && all(mouse_pos_loc .- widths .< 0.0)
                        if !ctrl_is_pressed && !isempty(get_selected_plots(gui))
                            clear_selection(gui; clear_topo=false)
                        end
                        pick_component!(gui; pick_results_component=true)
                        return Consume(true)
                    end
                    return Consume(false)
                end
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

        return Consume(false)
    end

    # Handle mouse movement
    on(events(get_ax(gui, :topo)).mouseposition; priority=2) do mouse_pos # priority ≥ 2 in order to suppress GLMakie left-click and drag zoom feature
        if get_var(gui, :dragging)[]
            origin::Vec2{Int64} = pixelarea(get_ax(gui, :topo).scene)[].origin
            widths::Vec2{Int64} = pixelarea(get_ax(gui, :topo).scene)[].widths
            mouse_pos_loc::Vec2{Float64} = mouse_pos .- origin

            xy_widths::Vec2{Float32} = get_ax(gui, :topo).finallimits[].widths
            xy_origin::Vec2{Float32} = get_ax(gui, :topo).finallimits[].origin

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

    # Pin current plot (the last plot added)
    time_menu = get_menu(gui, :time)
    on(get_button(gui, :pin_plot).clicks; priority=10) do _
        @info "Current plot pinned"
        time_axis = get_var(gui, :time_axes)[time_menu.i_selected[]]
        plots = get_ax(gui, time_axis).scene.plots
        if !isempty(plots) # Check if any plots exist
            pinned_data = get_pinned_data(gui, time_axis)
            pinned_plots = [x[:plot] for x ∈ pinned_data]
            plot = getfirst(
                x ->
                    !(x[:plot] ∈ pinned_plots) &&
                        (isa(x[:plot], Lines) || isa(x[:plot], Combined)),
                get_visible_data(gui, time_axis),
            )
            if !isnothing(plot)
                push!(pinned_data, plot)
            end
        end
        return Consume(false)
    end

    # Remove selected plot
    on(get_button(gui, :remove_plot).clicks; priority=10) do _
        if isempty(get_selected_plots(gui))
            return Consume(false)
        end
        time_axis = get_var(gui, :time_axes)[time_menu.i_selected[]]
        for plot_selected ∈ get_selected_plots(gui)
            plot_selected[:plot].visible = false
            toggle_selection_color!(gui, plot_selected, false)
            filter!(x -> x[:plot] != plot_selected[:plot], get_visible_data(gui, time_axis))
            filter!(x -> x[:plot] != plot_selected[:plot], get_visible_data(gui, time_axis))
            @info "Removing plot with label: $(plot_selected[:plot].label[])"
        end
        update_legend!(gui)
        update_barplot_dodge!(gui)
        update_limits!(get_ax(gui, time_menu.selection[]))
        empty!(get_selected_plots(gui))
        return Consume(false)
    end

    # Clear all plots
    on(get_button(gui, :clear_all).clicks; priority=10) do _
        time_axis = get_var(gui, :time_axes)[time_menu.i_selected[]]
        for data_selected ∈ get_visible_data(gui, time_axis)
            data_selected[:plot].visible = false
            toggle_selection_color!(gui, data_selected, false)
        end
        @info "Clearing plots"
        empty!(get_selected_plots(gui))
        empty!(get_visible_data(gui, time_axis))
        empty!(get_pinned_data(gui, time_axis))
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
        notify(get_ax(gui, :topo).finallimits)
        return Consume(false)
    end

    # Export button: Export get_ax(gui,:results) to file (format given by export_type_menu.selection[])
    on(get_button(gui, :export).clicks; priority=10) do _
        if get_menu(gui, :export_type).selection[] == "REPL"
            axes_str::String = get_menu(gui, :axes).selection[]
            if axes_str == "Plots"
                time_axis = get_var(gui, :time_axes)[time_menu.i_selected[]]
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
                for dict ∈ collect(keys(object_dictionary(model)))
                    container = model[dict]
                    if isempty(container)
                        continue
                    end
                    if typeof(container) <: JuMP.Containers.DenseAxisArray
                        axis_types = nameof.([eltype(a) for a ∈ JuMP.axes(model[dict])])
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
    on(time_menu.selection; priority=10) do selection
        for (_, time_axis) ∈ time_menu.options[]
            if time_axis == selection
                showdecorations!(get_ax(gui, time_axis))
                showspines!(get_ax(gui, time_axis))
                showplots!([x[:plot] for x ∈ get_visible_data(gui, time_axis)])
            else
                ax = get_ax(gui, time_axis)
                hidedecorations!(ax)
                hidespines!(ax)
                hideplots!(ax.scene.plots)
            end
        end
        update_legend!(gui)
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
            representative_period_menu.i_selection = length(representative_periods_in_sp)
        end
        update_plot!(gui)
        return Consume(false)
    end

    # Representative period menu: Handle menu selection
    on(representative_period_menu.selection; priority=10) do _
        # Initialize representative_periods to be the representative_periods of the first operational period
        representative_period_menu = get_menu(gui, :period)
        current_scenario = scenario_menu.selection[]
        scenarios_in_rp = get_scenario_indices(
            T, period_menu.selection[], representative_period_menu.selection[]
        )
        scenario_menu.options = zip(
            get_var(gui, :scenarios_labels)[scenarios_in_rp], scenarios_in_rp
        )

        # If previously chosen scenario is out of range, update it to be the largest number available
        if length(scenarios_in_rp) < current_scenario
            scenario_menu.i_selection = length(scenarios_in_rp)
        end
        update_plot!(gui)
        return Consume(false)
    end

    # Scenario menu: Handle menu selection
    on(scenario_menu.selection; priority=10) do _
        selected_systems = get_selected_systems(gui)
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
