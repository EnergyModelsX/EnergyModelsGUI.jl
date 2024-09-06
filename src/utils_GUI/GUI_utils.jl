"""
    toggle_selection_color!(gui::GUI, selection, selected::Bool)

Set the color of selection to `get_selection_color(gui)` if selected, and its original
color otherwise using the argument `selected`.
"""
function toggle_selection_color!(gui::GUI, selection::EnergySystemDesign, selected::Bool)
    if selected
        selection.color[] = get_selection_color(gui)
    else
        selection.color[] = :black
    end
end
function toggle_selection_color!(gui::GUI, selection::Connection, selected::Bool)
    plots = selection.plots
    if selected
        for plot ∈ plots
            for plot_sub ∈ plot[]
                plot_sub.color = get_selection_color(gui)
            end
        end
    else
        colors::Vector{RGB} = selection.colors
        no_colors::Int64 = length(colors)
        for plot ∈ plots
            for (i, plot_sub) ∈ enumerate(plot[])
                plot_sub.color = colors[((i - 1) % no_colors) + 1]
            end
        end
    end
end
function toggle_selection_color!(gui::GUI, selection::Dict{Symbol,Any}, selected::Bool)
    color = selected ? parse(Colorant, get_selection_color(gui)) : selection[:color]
    plot = selection[:plot]
    plot.color[] = color

    # Implement ugly hack to resolve bug in Makie for barplots due to legend updates
    while !isempty(plot.plots)
        plot = plot.plots[1]
        plot.color[] = color
    end

    # Implement hack to resolve bug in Makie for stairs/lines due to legend updates
    selection[:color_obs][] = color
end

"""
    get_EMGUI_obj(plt)

Get the `EnergySystemDesign`/`Connection` assosiated with `plt`. Note that due to the nested
structure of Makie, we must iteratively look through up to three nested layers to find where
this object is stored.
"""
function get_EMGUI_obj(plt)
    if isa(plt, AbstractPlot)
        if haskey(plt.kw, :EMGUI_obj)
            return plt.kw[:EMGUI_obj]
        elseif isa(plt.parent, AbstractPlot)
            if haskey(plt.parent.kw, :EMGUI_obj)
                return plt.parent.kw[:EMGUI_obj]
            elseif isa(plt.parent.parent, AbstractPlot)
                if haskey(plt.parent.parent.kw, :EMGUI_obj)
                    return plt.parent.parent.kw[:EMGUI_obj]
                elseif isa(plt.parent.parent.parent, AbstractPlot) &&
                    haskey(plt.parent.parent.parent.kw, :EMGUI_obj)
                    return plt.parent.parent.parent.kw[:EMGUI_obj]
                end
            end
        end
    end
end

"""
    pick_component!(gui::GUI)

Check if a system is found under the mouse pointer and if it is an `EnergySystemDesign`
or a `Connection` and update state variables.
"""
function pick_component!(gui::GUI; pick_topo_component=false, pick_results_component=false)
    plt, _ = pick(get_fig(gui))

    pick_component!(gui, plt; pick_topo_component, pick_results_component)
end
function pick_component!(
    gui::GUI, plt::AbstractPlot; pick_topo_component=false, pick_results_component=false
)
    if pick_topo_component || pick_results_component
        element = get_EMGUI_obj(plt)
        pick_component!(gui, element; pick_topo_component, pick_results_component)
    end
end
function pick_component!(
    gui::GUI,
    element::Union{EnergySystemDesign,Connection};
    pick_topo_component=false,
    pick_results_component=false,
)
    if isnothing(element)
        clear_selection(
            gui; clear_topo=pick_topo_component, clear_results=pick_results_component
        )
    else
        push!(gui.vars[:selected_systems], element)
        toggle_selection_color!(gui, element, true)
    end
end
function pick_component!(
    gui::GUI, element::Dict; pick_topo_component=false, pick_results_component=false
)
    if isnothing(element)
        clear_selection(
            gui; clear_topo=pick_topo_component, clear_results=pick_results_component
        )
    else
        element[:selected] = true
        toggle_selection_color!(gui, element, true)
    end
end
function pick_component!(
    gui::GUI, ::Nothing; pick_topo_component=false, pick_results_component=false
)
    clear_selection(
        gui; clear_topo=pick_topo_component, clear_results=pick_results_component
    )
end

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
        time_axis = get_menu(gui, :time).selection[]
        for selection ∈ get_selected_plots(gui, time_axis)
            selection[:selected] = false
            toggle_selection_color!(gui, selection, false)
        end
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
`get_axes(gui)[:results]` if `updateplot = true`.
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

Based on `Connection`, update the text in `get_axes(gui)[:info]`
and update plot in `get_axes(gui)[:results]` if `updateplot = true`.
"""
function update!(gui::GUI, connection::Connection; updateplot::Bool=true)
    return update!(gui, get_element(connection); updateplot)
end

"""
    update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)

Based on `design`, update the text in `get_axes(gui)[:info]`
and update plot in `get_axes(gui)[:results]` if `updateplot = true`.
"""
function update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)
    return update!(gui, get_element(design); updateplot)
end

"""
    initialize_available_data!(gui)

For all plotable objects, initialize the available data menu with items.
"""
function initialize_available_data!(gui)
    design = get_root_design(gui)
    system = get_system(design)
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
        mode_to_transmission = Dict()
        for t ∈ system[:transmission]
            for m ∈ modes(t)
                mode_to_transmission[m] = t
            end
        end
    end
    gui.vars[:available_data] = Dict{Plotable,Vector{Dict{Symbol,Any}}}(
        element => Vector{Dict{Symbol,Any}}() for element ∈ plotables
    )

    # Find appearances of node/area/link/transmission in the model
    if termination_status(model) == MOI.OPTIMAL # Plot results if available
        T = gui.design.system[:T]
        for sym ∈ get_JuMP_names(gui)
            var = model[sym]
            if isempty(var)
                continue
            end
            i_T, type = get_time_axis(model[sym])
            periods = get_periods(T, type)

            for combination ∈ get_combinations(var, i_T)
                selection = collect(combination)
                if isa(var, SparseVars) # Slicing for SparseVars performs worse than the following
                    field_data = JuMP.Containers.DenseAxisArray(
                        [
                            var[vcat(selection[1:(i_T - 1)], t, selection[i_T:end])...] for
                            t ∈ periods
                        ],
                        periods,
                    )
                else # For DenseAxisArrays, slicing performs best
                    field_data = var[vcat(selection[1:(i_T - 1)], :, selection[i_T:end])...]
                end
                element::Plotable = getfirst(
                    x -> isa(x, Union{EMB.Node,Link,Area,TransmissionMode}), selection
                )
                if isa(element, TransmissionMode)
                    element = mode_to_transmission[element]
                end

                container = Dict(
                    :name => string(sym),
                    :is_jump_data => true,
                    :selection => selection,
                    :field_data => field_data,
                    :description => create_description(gui, "variables.$sym"),
                )
                push!(get_available_data(gui)[element], container)
            end
        end
    end

    # Add total quantities
    if termination_status(model) == MOI.OPTIMAL
        element = nothing
        # Calculate total OPEX for each strategic period
        scale_tot_opex = get_var(gui, :scale_tot_opex)
        scale_tot_capex = get_var(gui, :scale_tot_capex)
        𝒯ᴵⁿᵛ = strategic_periods(T)
        sp_dur = duration_strat.(𝒯ᴵⁿᵛ)
        tot_opex = zeros(T.len)
        tot_opex_unscaled = zeros(T.len)
        for opex_field ∈ get_var(gui, :descriptive_names)[:total][:opex_fields]
            opex_key = Symbol(opex_field[1])
            description = opex_field[2]
            if haskey(model, opex_key)
                opex = vec(sum(Array(value.(model[opex_key])), dims=1))
                tot_opex_unscaled .+= opex
                if scale_tot_opex
                    opex .*= sp_dur
                    description *= " (scaled to strategic period)"
                end
                tot_opex .+= opex

                # add opex_field to available data
                container = Dict(
                    :name => "opex_strategic",
                    :is_jump_data => false,
                    :selection => [element],
                    :field_data => StrategicProfile(opex),
                    :description => description,
                )
                push!(get_available_data(gui)[element], container)
            end
        end

        # Calculate the total investment cost (CAPEX) for each strategic period
        tot_capex = zeros(T.len)
        tot_capex_unscaled = zeros(T.len)
        capex_fields = get_var(gui, :descriptive_names)[:total][:capex_fields]
        for capex_field ∈ capex_fields
            capex_key = Symbol(capex_field[1])
            description = capex_field[2]
            if haskey(model, capex_key)
                capex = vec(sum(Array(value.(model[capex_key])), dims=1))
                tot_capex_unscaled .+= capex
                if scale_tot_capex
                    capex ./= sp_dur
                    description *= " (scaled to year)"
                end

                tot_capex .+= capex

                # add opex_field to available data
                container = Dict(
                    :name => "capex_strategic",
                    :is_jump_data => false,
                    :selection => [element],
                    :field_data => StrategicProfile(capex),
                    :description => description,
                )
                push!(get_available_data(gui)[element], container)
            end
        end

        # add total operational cost to available data
        description = "Total operational cost"
        if scale_tot_opex
            description *= " (scaled to strategic period)"
        end
        container = Dict(
            :name => "tot_opex",
            :is_jump_data => false,
            :selection => [element],
            :field_data => StrategicProfile(tot_opex),
            :description => description,
        )
        push!(get_available_data(gui)[element], container)

        # add total investment cost to available data
        description = "Total investment cost"
        if scale_tot_capex
            description *= " (scaled to year)"
        end
        container = Dict(
            :name => "tot_capex",
            :is_jump_data => false,
            :selection => [element],
            :field_data => StrategicProfile(tot_capex),
            :description => description,
        )
        push!(get_available_data(gui)[element], container)

        # Find a reference value to be used for considering the magnitude of an investment
        max_installed_arr = []
        for element ∈ plotables
            push!(max_installed_arr, get_max_installed(element, [t for t ∈ 𝒯ᴵⁿᵛ]))
        end
        max_inst::Float64 = maximum(max_installed_arr)
        if max_inst == 0
            max_inst = 1.0 # In case of all values set to zero
        end

        # Calculate when investments has taken place and store the information
        get_investment_times(gui, max_inst)

        # Create investment overview in the information box
        investment_overview = "Result summary:\n\n"
        total_opex = sum(tot_opex_unscaled .* sp_dur)
        total_capex = sum(tot_capex_unscaled)
        investment_overview *= "Total operational cost: $(format_number(total_opex))\n"
        investment_overview *= "Total investment cost: $(format_number(total_capex))\n\n"
        inv_overview_components = ""
        for obj ∈ design
            inv_times = get_inv_times(obj)
            if !isempty(inv_times)
                capex = get_capex(obj)
                label = get_element_label(obj)
                inv_overview_components *= "\t$label:\n"
                for (t, capex) ∈ zip(inv_times, capex)
                    inv_overview_components *= "\t\t$t: $(format_number(capex))\n"
                end
            end
        end
        if !isempty(inv_overview_components)
            investment_overview *= "Investment overview:\n"
            investment_overview *= inv_overview_components
        end
        gui.vars[:investment_overview] = investment_overview
    else
        @warn "Total quantities were not computed as model does not contain a feasible solution"
    end

    # Add case input data
    for element ∈ plotables
        # Add timedependent input data (if available)
        if !isnothing(element)
            available_data = Vector{Dict}(undef, 0)
            for field_name ∈ fieldnames(typeof(element))
                field = getfield(element, field_name)
                structure = String(nameof(typeof(element)))
                name = "$field_name"
                key_str = "structures.$structure.$name"
                add_description!(field, name, key_str, "", element, available_data, gui)
            end
            append!(get_available_data(gui)[element], available_data)
        end
    end
end
"""
    get_JuMP_names(gui::GUI)

Get all names registered in the model as a vector except the names to be ignored.
"""
function get_JuMP_names(gui::GUI)
    model = get_model(gui)
    ignore_names = Symbol.(get_var(gui, :descriptive_names)[:ignore])
    names = collect(keys(object_dictionary(model)))
    return [name for name ∈ names if !(name ∈ ignore_names)]
end

"""
    get_investment_times(gui::GUI, max_inst::Float64)

Calculate when investments has taken place and store the information. An investement is
assumed to have taken place if any `investment_indicators` are larger than get_var(gui,:tol)
relative to `max_inst`.
"""
function get_investment_times(gui::GUI, max_inst::Float64)
    T = gui.design.system[:T]
    𝒯ᴵⁿᵛ = strategic_periods(T)
    investment_indicators = get_var(gui, :descriptive_names)[:investment_indicators]
    capex_fields = get_var(gui, :descriptive_names)[:total][:capex_fields]
    period_labels = get_var(gui, :periods_labels)
    model = get_model(gui)
    for component ∈ get_root_design(gui)
        element = get_element(component)
        investment_times::Vector{String} = Vector{String}[]
        investment_capex::Vector{Float64} = Vector{Float64}[]
        for (i, t) ∈ enumerate(𝒯ᴵⁿᵛ)
            for investment_indicator ∈ investment_indicators # important not to use shorthand loop syntax here due to the break command (exiting both loops in that case)
                sym = Symbol(investment_indicator)
                if haskey(model, sym) &&
                    !isempty(model[sym]) &&
                    element ∈ axes(model[sym])[1]
                    val = value(model[sym][element, t])
                    if val > get_var(gui, :tol) * max_inst
                        capex::Float64 = 0.0
                        for capex_field ∈ capex_fields
                            capex_key = Symbol(capex_field[1])
                            if haskey(model, capex_key) &&
                                element ∈ axes(model[capex_key])[1]
                                capex += value(model[capex_key][element, t])
                            end
                        end
                        t_str = split(period_labels[i], " ")[1]
                        push!(investment_times, t_str)
                        push!(investment_capex, capex)
                        break # Do not add the capex again for other elements in investment_indicators
                    end
                end
            end
        end
        if !isempty(investment_times)
            component.inv_data = ProcInvData(investment_times, investment_capex, true)
        end
    end
end

"""
    get_combinations(var, i_T::Int)

Get an iterator of combinations of unique indices excluding the time index located at index `i_T`.
"""
function get_combinations(var::SparseVars, i_T::Int)
    return unique((key[1:(i_T - 1)]..., key[(i_T + 1):end]...) for key ∈ keys(var.data))
end
function get_combinations(var::JuMP.Containers.DenseAxisArray, i_T::Int)
    return Iterators.product(axes(var)[vcat(1:(i_T - 1), (i_T + 1):end)]...)
end

"""
    update_available_data_menu!(gui::GUI, element::Plotable)

Update the `get_menus(gui)[:available_data]` with the available data of `element`.
"""
function update_available_data_menu!(gui::GUI, element::Plotable)
    available_data = get_available_data(gui)
    container = available_data[element]
    container_strings = create_label.(container)
    if !isempty(container) # needed to resolve bug introduced in Makie
        get_menu(gui, :available_data).options = zip(container_strings, container)
    end
end

"""
    update_descriptive_names!(gui::GUI)

Update the dictionary of `descriptive_names` where the Dict is appended/overwritten in the
following order:

- The default descriptive names found in `src/descriptive_names.yml`.
- Any descriptive_names.yml file found in the ext/EMGUIExt folder of any other EMX package.
- Descriptive names from a user defined file (from the GUI input argument `path_to_descriptive_names`).
- Descriptive names from a user defined Dict (from the GUI input argument `descriptive_names_dict`).
"""
function update_descriptive_names!(gui::GUI)
    descriptive_names = YAML.load_file(
        joinpath(@__DIR__, "..", "descriptive_names.yml"); dicttype=Dict{Symbol,Any}
    )

    # Get a dictionary of installed packages
    installed_packages = installed()

    # Filter packages with names matching the pattern "EnergyModels*"
    emx_packages = filter(pkg -> occursin(r"EnergyModels", pkg), keys(installed_packages))

    # Search through EMX packages if icons are available there
    for package ∈ emx_packages
        package_path::Union{String,Nothing} = Base.find_package(package)
        if !isnothing(package_path)
            path_to_descriptive_names_ext = joinpath(
                package_path, "ext", "EMGUIExt", "descriptive_names.yml"
            )
            if isfile(path_to_descriptive_names_ext)
                descriptive_names_dict_ext_file = YAML.load_file(
                    path_to_descriptive_names_ext; dicttype=Dict{Symbol,Any}
                )
                descriptive_names = merge_dicts(
                    descriptive_names, descriptive_names_dict_ext_file
                )
            end
        end
    end

    # Update the Dict of descriptive names with user defined names from file
    path_to_descriptive_names = get_var(gui, :path_to_descriptive_names)
    if !isempty(path_to_descriptive_names)
        descriptive_names_dict_user_file = YAML.load_file(
            path_to_descriptive_names; dicttype=Dict{Symbol,Any}
        )
        descriptive_names = merge_dicts(descriptive_names, descriptive_names_dict_user_file)
    end

    # Update the Dict of descriptive names with user defined names from Dict
    descriptive_names_dict = get_var(gui, :descriptive_names_dict)
    if !isempty(descriptive_names_dict)
        descriptive_names = merge_dicts(descriptive_names, descriptive_names_dict)
    end
    get_vars(gui)[:descriptive_names] = descriptive_names
end
