"""
    toggle_selection_color!(gui::GUI, selection::EnergySystemDesign, selected::Bool)
    toggle_selection_color!(gui::GUI, selection::Connection, selected::Bool)
    toggle_selection_color!(gui::GUI, selection::Dict{Symbol,Any}, selected::Bool)

Set the color of selection to `get_selection_color(gui)` if selected, and its original
color otherwise using the argument `selected`.
"""
function toggle_selection_color!(gui::GUI, selection::EnergySystemDesign, selected::Bool)
    selection.color[] = selected ? get_selection_color(gui) : BLACK
end
function toggle_selection_color!(gui::GUI, selection::Connection, selected::Bool)
    plots = get_plots(selection)
    if selected
        for plot ∈ plots
            selection_color = get_selection_color(gui)
            if isa(plot.color[], Vector)
                plot.color = fill(selection_color, length(plot.color[]))
            else
                plot.color = selection_color
            end
        end
    else
        colors = get_colors(selection)
        no_colors = length(colors)
        i::Int64 = 0
        for plot ∈ plots
            if isa(plot.color[], Vector)
                plot.color = colors
            else
                plot.color = colors[((i-1)%no_colors)+1]
                i += 1
            end
        end
    end
end
function toggle_selection_color!(gui::GUI, selection::Dict{Symbol,Any}, selected::Bool)
    selection[:plot].color = selected ? get_selection_color(gui) : selection[:color]
    update_legend!(gui)
end

"""
    get_EMGUI_obj(plt)

Get the `EnergySystemDesign`/`Connection` assosiated with `plt`. Note that due to the nested
structure of Makie, we must iteratively look through up to three nested layers to find where
this object is stored.
"""
function get_EMGUI_obj(plt)
    !isa(plt, AbstractPlot) && return nothing

    # Check current level
    obj = get(plt.kw, :EMGUI_obj, nothing)
    !isnothing(obj) && return obj

    # Check parent levels (up to 3 levels deep)
    current = plt.parent
    for _ ∈ 1:3
        !isa(current, AbstractPlot) && break
        obj = get(current.kw, :EMGUI_obj, nothing)
        !isnothing(obj) && return obj
        current = current.parent
    end

    return nothing
end

"""
    pick_component!(gui::GUI, ax_type::Symbol)
    pick_component!(gui::GUI, plt::AbstractPlot, ax_type::Symbol)
    pick_component!(gui::GUI, element::AbstractGUIObj, ::Symbol)
    pick_component!(gui::GUI, element::Dict, ::Symbol)
    pick_component!(gui::GUI, ::Nothing, ax_type::Symbol)

Check if a system is found under the mouse pointer and if it is an `AbstractGUIObj` (for
objects in the topology axis) or a `Dict` (for objects in the results axis). If found, 
state variables are updated. Results in the topology axis are only cleared if `ax_type = :topo`
and in the results axis if `ax_type = :results`.
"""
function pick_component!(gui::GUI, ax_type::Symbol)
    plt, _ = pick(get_fig(gui))
    pick_component!(gui, plt, ax_type)
end
function pick_component!(gui::GUI, plt::AbstractPlot, ax_type::Symbol)
    pick_component!(gui, get_EMGUI_obj(plt), ax_type)
end
function pick_component!(gui::GUI, element::AbstractGUIObj, ::Symbol)
    push!(gui.vars[:selected_systems], element)
    toggle_selection_color!(gui, element, true)
end
function pick_component!(gui::GUI, element::Dict, ::Symbol)
    element[:selected] = true
    toggle_selection_color!(gui, element, true)
end
function pick_component!(gui::GUI, ::Nothing, ax_type::Symbol)
    clear_selection(gui, ax_type)
end

"""
    clear_selection(gui::GUI, ax_type::Symbol)

Clear the color selection of the topology axis if `ax_type = :topo`, and of the results axis 
if `ax_type = :results`.
"""
function clear_selection(gui::GUI, ax_type::Symbol)
    if ax_type == :topo
        selected_systems = get_selected_systems(gui)
        for selection ∈ selected_systems
            toggle_selection_color!(gui, selection, false)
        end
        empty!(selected_systems)
        update_available_data_menu!(gui, nothing) # Make sure the menu is updated
    elseif ax_type == :results
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
        update!(gui, selected_systems[end]; updateplot = updateplot)
    else
        update!(gui, nothing; updateplot = updateplot)
    end
end

"""
    update!(gui::GUI, element; updateplot::Bool=true)

Based on `element`, update the text in `get_axes(gui)[:info]` and update plot in
`get_axes(gui)[:results]` if `updateplot = true`.
"""
function update!(gui::GUI, element; updateplot::Bool = true)
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
function update!(gui::GUI, connection::Connection; updateplot::Bool = true)
    return update!(gui, get_element(connection); updateplot)
end

"""
    update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool=true)

Based on `design`, update the text in `get_axes(gui)[:info]`
and update plot in `get_axes(gui)[:results]` if `updateplot = true`.
"""
function update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool = true)
    return update!(gui, get_element(design); updateplot)
end

"""
    get_mode_to_transmission_map(::System)

Dispatchable function to get the mapping between modes and transmissions for a `GeoSystem`.
"""
function get_mode_to_transmission_map(::System)
    return Dict()
end

"""
    results_available(model::Model)
    results_available(model::String)

Check if the model has a feasible solution.
"""
function results_available(model::Model)
    return termination_status(model) == MOI.OPTIMAL
end
function results_available(model::Dict)
    return !isempty(model) && model[:metadata][:termination_status] == string(MOI.OPTIMAL)
end

"""
    initialize_available_data!(gui)

For all plotable objects, initialize the available data menu with items.
"""
function initialize_available_data!(gui)
    design = get_root_design(gui)
    system = get_system(design)
    model = get_model(gui)
    plotables = [nothing; vcat(get_elements_vec(system))...] # `nothing` here represents no selection
    gui.vars[:available_data] = Dict{Any,Vector{PlotContainer}}(
        element => Vector{PlotContainer}() for element ∈ plotables
    )

    # Find appearances of node/area/link/transmission in the model
    if results_available(model)
        T = get_time_struct(gui)
        mode_to_transmission = get_mode_to_transmission_map(system)
        for sym ∈ get_JuMP_names(gui)
            var = model[sym]
            if isempty(var)
                continue
            end
            i_T, type = get_time_axis(var)
            if isnothing(type) # No time dimension found
                continue
            end
            periods = get_periods(T, type)

            for combination ∈ get_combinations(var, i_T)
                selection = collect(combination)
                field_data = extract_data_selection(var, selection, i_T, periods)
                element = getfirst(x -> !isa(x, Resource), selection)
                if !isa(element, AbstractElement) && !isnothing(element) # it must be a transmission
                    element = mode_to_transmission[element]
                end

                container = JuMPContainer(
                    string(sym),
                    selection,
                    field_data,
                    create_description(gui, "variables.$sym"),
                )
                push!(get_available_data(gui)[element], container)
            end
        end

        # Add total quantities
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
                opex = vec(get_total_sum_time(model[opex_key], collect(𝒯ᴵⁿᵛ)))
                tot_opex_unscaled .+= opex
                if scale_tot_opex
                    opex .*= sp_dur
                    description *= " (scaled to strategic period)"
                end
                tot_opex .+= opex

                # add opex_field to available data
                container = GlobalDataContainer(
                    "opex_strategic",
                    [element],
                    StrategicProfile(opex),
                    description,
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
                capex = vec(get_total_sum_time(model[capex_key], collect(𝒯ᴵⁿᵛ)))
                tot_capex_unscaled .+= capex
                if scale_tot_capex
                    capex ./= sp_dur
                    description *= " (scaled to year)"
                end

                tot_capex .+= capex

                # add opex_field to available data
                container = GlobalDataContainer(
                    "capex_strategic",
                    [element],
                    StrategicProfile(capex),
                    description,
                )
                push!(get_available_data(gui)[element], container)
            end
        end

        # add total operational cost to available data
        description = "Total operational cost"
        if scale_tot_opex
            description *= " (scaled to strategic period)"
        end
        container = GlobalDataContainer(
            "tot_opex",
            [element],
            StrategicProfile(tot_opex),
            description,
        )
        push!(get_available_data(gui)[element], container)

        # add total investment cost to available data
        description = "Total investment cost"
        if scale_tot_capex
            description *= " (scaled to year)"
        end
        container = GlobalDataContainer(
            "tot_capex",
            [element],
            StrategicProfile(tot_capex),
            description,
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
        total_opex = sum(tot_opex_unscaled .* sp_dur)
        total_capex = sum(tot_capex_unscaled)
        io = IOBuffer()
        println(io, "Result summary:\n")
        println(io, "Objective value: $(format_number(get_obj_value(model)))\n")
        println(io, "Investment summary (no values discounted):\n")
        println(io, "Total operational cost: $(format_number(total_opex))")
        println(io, "Total investment cost: $(format_number(total_capex))\n")
        has_investments::Bool = false
        for obj ∈ design
            inv_times = get_inv_times(obj)
            if !isempty(inv_times)
                if !has_investments
                    println(io, "Investment overview (CAPEX):")
                    has_investments = true
                end
                capex = get_capex(obj)
                label = get_element_label(obj)
                println(io, "\t", label, ":")
                for (t, capex) ∈ zip(inv_times, capex)
                    println(io, "\t\t", t, ": ", format_number(capex))
                end
            end
        end
        investment_overview = String(take!(io))
        summary_text = get_var(gui, :summary_text)
        summary_text[] = investment_overview
    else
        if !isempty(model)
            @warn "Total quantities were not computed as model does not contain a feasible solution"
        end
    end

    # Add case input data
    for element ∈ plotables
        # Add timedependent input data (if available)
        if !isnothing(element)
            available_data = PlotContainer[]
            for field_name ∈ fieldnames(typeof(element))
                field = getfield(element, field_name)
                structure = String(nameof(typeof(element)))
                name = "$field_name"
                key_str = "structures.$structure.$name"
                selection = Vector{Any}([element])
                add_description!(field, name, key_str, "", selection, available_data, gui)
            end
            append!(get_available_data(gui)[element], available_data)
        end
    end
end

"""
    extract_data_selection(var::SparseVars, selection::Vector, i_T::Int64, periods::Vector)
    extract_data_selection(var::Jump.Containers.DenseAxisArray, selection::Vector, i_T::Int64, ::Vector)
    extract_data_selection(var::DataFrame, selection::Vector, ::Int64, ::Vector)

Extract data from `var` having its time dimension at index `i_T` for all time periods in `periods`.

!!! warning "Reading model results from CSV-files"
    This function does not support more than three indices for `var::DataFrame` (*i.e.*,
    when model results are read from CSV-files). This implies it is incompatible with
    potential extensions that introduce more than three indices for variables.
"""
function extract_data_selection(
    var::SparseVars, selection::Vector, i_T::Int64, periods::Vector,
)
    return JuMP.Containers.DenseAxisArray(
        [var[vcat(selection[1:(i_T-1)], t, selection[i_T:end])...] for t ∈ periods],
        periods,
    )
end
function extract_data_selection(
    var::JuMP.Containers.DenseAxisArray, selection::Vector, i_T::Int64, ::Vector,
)
    return var[vcat(selection[1:(i_T-1)], :, selection[i_T:end])...]
end
function extract_data_selection(
    var::DataFrame, selection::Vector, ::Int64, ::Vector,
)
    res_idx = findfirst(x -> isa(x, Resource), selection)
    element_idx = findfirst(x -> !isa(x, Resource), selection)
    if !isnothing(res_idx) && !isnothing(element_idx)
        res = selection[res_idx]
        element = selection[element_idx]
        return var[(var.:res .== [res]) .& (var.:element .== [element]), :]
    elseif !isnothing(res_idx)
        res = selection[res_idx]
        return var[var.:res .== [res], :]
    elseif !isnothing(element_idx)
        element = selection[element_idx]
        return var[var.:element .== [element], :]
    end
end

"""
    get_JuMP_names(gui::GUI)

Get all names registered in the model as a vector except the names to be ignored.
"""
function get_JuMP_names(gui::GUI)
    model = get_model(gui)
    ignore_names = Symbol.(get_var(gui, :descriptive_names)[:ignore])
    names = collect(keys(get_JuMP_dict(model)))
    return [name for name ∈ names if !(name ∈ ignore_names)]
end

"""
    get_obj_value(model::Model)
    get_obj_value(model::Dict)

Get the objective value of the model.
"""
function get_obj_value(model::Model)
    return objective_value(model)
end
function get_obj_value(model::Dict)
    return model[:metadata][:objective_value]
end

"""
    get_JuMP_dict(model::Model)
    get_JuMP_dict(model::Dict)

Get the dictionary of the model results. If the model is a JuMP.Model, it returns the object
dictionary.
"""
get_JuMP_dict(model::Dict) = Dict(k => v for (k, v) ∈ model if k != :metadata)
get_JuMP_dict(model::JuMP.Model) = object_dictionary(model)

"""
    get_values(vals::SparseVars)
    get_values(vals::JuMP.Containers.DenseAxisArray)
    get_values(vals::DataFrame)
    get_values(vals::JuMP.Containers.SparseAxisArray, ts::Vector)
    get_values(vals::SparseVariables.IndexedVarArray, ts::Vector)
    get_values(vals::JuMP.Containers.DenseAxisArray, ts::Vector)
    get_values(vals::DataFrame, ts::Vector)

Get the values of the variables in `vals`. If a vector of time periods `ts` is provided, it
returns the values for the times in `ts`.
"""
get_values(vals::SparseVars) = isempty(vals) ? [] : collect(Iterators.flatten(value.(vals)))
get_values(vals::SparseVariables.IndexedVarArray) = collect(value.(values(vals.data)))
get_values(vals::JuMP.Containers.DenseAxisArray) = Array(value.(vals))
get_values(vals::DataFrame) = vals[!, :val]
get_values(vals::JuMP.Containers.SparseAxisArray, ts::Vector) = [value(vals[t]) for t ∈ ts]
get_values(vals::SparseVariables.IndexedVarArray, ts::Vector) =
    isempty(vals) ? [] : value.(vals[ts])
get_values(vals::JuMP.Containers.DenseAxisArray, ts::Vector) = Array(value.(vals[ts]))
get_values(vals::DataFrame, ts::Vector) = vals[in.(vals.t, Ref(ts)), :val]
get_values(vals::TimeProfile, ts::Vector) = vals[ts]

"""
    get_investment_times(gui::GUI, max_inst::Float64)

Calculate when investments has taken place and store the information. An investement is
assumed to have taken place if any `investment_indicators` are larger than get_var(gui,:tol)
relative to `max_inst`.
"""
function get_investment_times(gui::GUI, max_inst::Float64)
    T = get_time_struct(gui)
    𝒯ᴵⁿᵛ = strategic_periods(T)
    investment_indicators = get_var(gui, :descriptive_names)[:investment_indicators]
    capex_fields = get_var(gui, :descriptive_names)[:total][:capex_fields]
    period_labels = get_var(gui, :periods_labels)
    model = get_model(gui)
    for component ∈ get_root_design(gui)
        element = get_element(component)
        investment_times = String[]
        investment_capex = Float64[]
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
    get_combinations(var::SparseVars, i_T::Int)
    get_combinations(var::JuMP.Containers.DenseAxisArray, i_T::Int)
    get_combinations(var::DataFrame, ::Int)

Get an iterator of combinations of unique indices excluding the time index located at index `i_T`.
"""
function get_combinations(var::SparseVars, i_T::Int)
    return unique((key[1:(i_T-1)]..., key[(i_T+1):end]...) for key ∈ keys(var.data))
end
function get_combinations(var::JuMP.Containers.DenseAxisArray, i_T::Int)
    return Iterators.product(axes(var)[vcat(1:(i_T-1), (i_T+1):end)]...)
end
function get_combinations(var::DataFrame, ::Int)
    # Exclude the time and value columns (assumed to be :t and :vals)
    cols = names(var)
    non_time_val_cols = filter(c -> c != "t" && c != "val", cols)
    # Get unique tuples of the non-time/value columns
    return unique(Tuple(row[c] for c ∈ non_time_val_cols) for row ∈ eachrow(var))
end

"""
    update_available_data_menu!(gui::GUI, element)

Update the `get_menus(gui)[:available_data]` with the available data of `element`.
"""
function update_available_data_menu!(gui::GUI, element)
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
        joinpath(@__DIR__, "..", "descriptive_names.yml"); dicttype = Dict{Symbol,Any},
    )

    # Get a dictionary of loaded packages
    loaded_packages = loaded()

    # Filter packages with names matching the pattern "EnergyModels*"
    emx_packages = filter(pkg -> occursin(r"EnergyModels", pkg), loaded_packages)
    # apply inheritances for fetching descriptive names
    # create a dictionary were the keys are all the types defined in emx_packages and the values are the types they inherit from
    emx_supertypes_dict = get_supertypes(emx_packages)
    inherit_descriptive_names_from_supertypes!(descriptive_names, emx_supertypes_dict)
    for package ∈ emx_packages
        package_path::Union{String,Nothing} = dirname(dirname(Base.find_package(package)))
        if !isnothing(package_path)
            # check for presence of file to extend descriptive names
            path_to_descriptive_names_ext = joinpath(
                package_path, "ext", "EMGUIExt", "descriptive_names.yml",
            )
            if isfile(path_to_descriptive_names_ext)
                descriptive_names_dict_ext_file = YAML.load_file(
                    path_to_descriptive_names_ext; dicttype = Dict{Symbol,Any},
                )
                descriptive_names = merge_dicts(
                    descriptive_names, descriptive_names_dict_ext_file,
                )
            end
        end
    end

    # Update the Dict of descriptive names with user defined names from file
    path_to_descriptive_names = get_var(gui, :path_to_descriptive_names)
    if !isempty(path_to_descriptive_names)
        descriptive_names_dict_user_file = YAML.load_file(
            path_to_descriptive_names; dicttype = Dict{Symbol,Any},
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

"""
    select_data!(gui::GUI, name::String)

Select the data with name `name` from the `available_data` menu.
"""
function select_data!(gui::GUI, name::String)
    # Fetch the available data menu object
    menu = get_menu(gui, :available_data)

    # Fetch all menu options
    available_data = [get_name(x[2]) for x ∈ collect(menu.options[])]

    # Find menu number for data with name `name`
    i_selected = findfirst(x -> x == name, available_data)

    # Select data
    menu.i_selected = i_selected
end

"""
    get_total_sum_time(data::JuMP.Containers.DenseAxisArray, ::Vector{<:TS.TimeStructure})
    get_total_sum_time(data::DataFrame, periods::Vector{<:TS.TimeStructure})

Get the total sum of the data for each time period in `data`.
"""
function get_total_sum_time(
    data::JuMP.Containers.DenseAxisArray,
    ::Vector{<:TS.TimeStructure},
)
    return sum(get_values(data), dims = 1)
end
function get_total_sum_time(data::DataFrame, periods::Vector{<:TS.TimeStructure})
    return [sum(data[data.:t .== [t], :val]) for t ∈ periods]
end

"""
    get_all_periods!(vec::Vector, ts::TwoLevel)
    get_all_periods!(vec::Vector, ts::RepresentativePeriods)
    get_all_periods!(vec::Vector, ts::OperationalScenarios)
    get_all_periods!(vec::Vector, ts::Any)

Get all TimeStructures in `ts` and append them to `vec`.
"""
function get_all_periods!(vec::Vector, ts::TwoLevel)
    append!(vec, collect(ts))
    append!(vec, strategic_periods(ts))
    for t ∈ ts.operational
        get_all_periods!(vec, t)
    end
end
function get_all_periods!(vec::Vector, ts::RepresentativePeriods)
    append!(vec, repr_periods(ts))
    for t ∈ ts.rep_periods
        get_all_periods!(vec, t)
    end
end
function get_all_periods!(vec::Vector, ts::OperationalScenarios)
    append!(vec, opscenarios(ts))
    for t ∈ ts.scenarios
        get_all_periods!(vec, t)
    end
end
function get_all_periods!(::Vector, ::Any)
    return nothing
end

"""
    get_repr_dict(vec::AbstractVector{T}) where T

Get a dictionary with the string representation of each element in `vec` as keys.
"""
function get_repr_dict(vec::AbstractVector{T}) where {T}
    return Dict{String,T}(repr(x) => x for x ∈ vec)
end

"""
    convert_array(v::AbstractArray, dict::Dict)

Apply the transformation of the `dict` to the array `v`.
"""
function convert_array(v::AbstractArray, dict::Dict)
    return map(x -> dict[x], v)
end

"""
    transfer_model(model::Model, system::AbstractSystem)
    transfer_model(model::String, system::AbstractSystem)

Convert the model to a DataFrame if it is provided as a path to a directory.
"""
transfer_model(model::Model, ::AbstractSystem) = model
function transfer_model(model::String, system::AbstractSystem)
    data = Dict{Symbol,Any}()
    if isdir(model)
        files = filter(f -> endswith(f, ".csv"), readdir(model, join = true))
        metadata_path = joinpath(model, "metadata.yaml")
        data[:metadata] = YAML.load_file(metadata_path; dicttype = Dict{Symbol,Any})
        𝒯 = get_time_struct(system)

        results = Vector{Pair{Symbol,DataFrame}}(undef, length(files))
        all_periods = Union{TS.TimePeriod,TS.TimeStructure}[]
        get_all_periods!(all_periods, 𝒯)
        periods_dict = get_repr_dict(unique(all_periods))
        products_dict = get_repr_dict(get_products(system))
        plotables_dict = get_repr_dict(get_plotables(system))

        Threads.@threads for i ∈ eachindex(files)
            file = files[i]
            varname = Symbol(basename(file)[1:(end-4)])

            df = CSV.read(file, DataFrame)

            # Rename columns :sp, :op, or :osc to :t if present. Note that the type of the
            # time structure is available through the type of the column.
            for col ∈ (:sp, :rp, :osc)
                if string(col) ∈ names(df)
                    rename!(df, col => :t)
                end
            end

            col_names = names(df)
            df[!, :t] = convert_array(df[!, :t], periods_dict)
            if "res" ∈ col_names
                df[!, :res] = convert_array(df[!, :res], products_dict)
            end
            if "element" ∈ col_names
                df[!, :element] = convert_array(df[!, :element], plotables_dict)
            end

            results[i] = varname => df
        end
        for (k, v) ∈ results
            data[k] = v
        end
    else
        @warn "The model must be a directory containing the results. No results loaded."
    end
    return data
end

"""
    sub_plots_empty(component::EnergySystemDesign)

Check if any sub-component of `component` is missing plots.
"""
function sub_plots_empty(component::EnergySystemDesign)
    return any(
        isempty(get_plots(sub_component)) for sub_component ∈ get_components(component)
    )
end
