"""
    add_description!(
        available_data::Vector{Dict},
        container::Dict{Symbol,Any},
        gui::GUI,
        key_str::String;
        pre_desc::String="",
    )

Update the `container` with a description (from `get_var(gui,:descriptive_names)` if available),
and add `container` to `available_data`.
"""
function add_description!(
    available_data::Vector{Dict},
    container::Dict{Symbol,Any},
    gui::GUI,
    key_str::String;
    pre_desc::String="",
)
    structure = get_nth_field(key_str, '.', 3)
    if structure == "to" || structure == "from" # don't add `to` and `from` fields
        return nothing
    end
    description = pre_desc
    try
        description *= String(get_nested_value(get_var(gui, :descriptive_names), key_str))
    catch
        description = key_str[(findfirst('.', key_str) + 1):end]
        @warn "Could't find a description for $description. \
            Using the string $description instead"
    end
    container[:description] = description
    push!(available_data, container)
end

"""
    add_description!(
        field::T,
        name::String,
        key_str::String,
        pre_desc::String,
        element::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    ) where {T<:TS.TimeProfile}

Create a container with a description, and add `container` to `available_data`.
"""
function add_description!(
    field::T,
    name::String,
    key_str::String,
    pre_desc::String,
    element::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
) where {T<:TS.TimeProfile}
    container = Dict(
        :name => name, :is_jump_data => false, :selection => [element], :field_data => field
    )
    add_description!(available_data, container, gui, key_str; pre_desc)
end

"""
    add_description!(
        field::Dict,
        name::String,
        key_str::String,
        pre_desc::String,
        element::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

Loop through all `dictnames` for a `field` of type `Dict` (i.e. for the field `penalty`
having the keys :deficit and surplus) and update `available_data` with an added description.
"""
function add_description!(
    field::Dict,
    name::String,
    key_str::String,
    pre_desc::String,
    element::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    for (dictname, dictvalue) ∈ field
        name_field = "$name.$dictname"
        key_str_field = "$key_str.$dictname"
        add_description!(
            dictvalue, name_field, key_str_field, pre_desc, element, available_data, gui
        )
    end
end

"""
    add_description!(
        field::Vector,
        name::String,
        key_str::String,
        pre_desc::String,
        element::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

Loop through all elements of `field` of type `Vector` (i.e. for the field `data`)
and update `available_data` with an added description.
"""
function add_description!(
    field::Vector,
    name::String,
    key_str::String,
    pre_desc::String,
    element::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    for data ∈ field
        data_type = nameof(typeof(data))
        name_field = "$name.$data_type"
        key_str_field = "$key_str.$data_type"
        add_description!(
            data, name_field, key_str_field, pre_desc, element, available_data, gui
        )
    end
end

"""
    add_description!(
        field::Any,
        name::String,
        ::String,
        pre_desc::String,
        element::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

Loop through all struct fieldnames of `field` (i.e. for the field `level` of type `NoStartInvData`)
and update `available_data` with an added description.
"""
function add_description!(
    field::Any,
    name::String,
    ::String,
    pre_desc::String,
    element::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    field_type = typeof(field)
    for sub_field_name ∈ fieldnames(field_type)
        sub_field = getfield(field, sub_field_name)
        name_field_type = nameof(field_type)
        name_field = "$name.$sub_field_name"
        pre_desc_sub = "$pre_desc$name_field_type: "
        key_str = "structures.$name_field_type.$sub_field_name"
        add_description!(
            sub_field, name_field, key_str, pre_desc_sub, element, available_data, gui
        )
    end
end

"""
    add_description!(
        available_data::Vector{Dict},
        var::JuMP.Containers.DenseAxisArray,
        sym::Symbol,
        element::Plotable,
        gui::GUI,
    )

Add description to `available_data` for the JuMP variable `var` (with name `sym`) for `element`.
"""
function add_description!(
    available_data::Vector{Dict},
    var::JuMP.Containers.DenseAxisArray,
    sym::Symbol,
    element::Plotable,
    gui::GUI,
)
    # nodes/areas found in structure
    if any(eltype.(axes(var)) .<: Union{EMB.Node,Area})
        # only add var if used by element (assume element is located at first Dimension)
        if exists(var, element)
            if length(axes(var)) > 2
                for res ∈ var.axes[3]
                    container = Dict(
                        :name => string(sym),
                        :is_jump_data => true,
                        :selection => [element, res],
                    )
                    key_str = "variables.$sym"
                    add_description!(available_data, container, gui, key_str)
                end
            else
                container = Dict(
                    :name => string(sym), :is_jump_data => true, :selection => [element]
                )
                key_str = "variables.$sym"
                add_description!(available_data, container, gui, key_str)
            end
        end
    elseif any(eltype.(axes(var)) .<: TransmissionMode) # element found in structure
        if isa(element, Transmission)
            for mode ∈ modes(element)
                # only add dict if used by element (assume element is located at first Dimension)
                if exists(var, mode)
                    # do not include element (<: Transmission) here
                    # as the mode is unique to this transmission
                    container = Dict(
                        :name => string(sym), :is_jump_data => true, :selection => [mode]
                    )
                    key_str = "variables.$sym"
                    add_description!(available_data, container, gui, key_str)
                end
            end
        end
    elseif isnothing(element)
        if length(axes(var)) > 1
            for res ∈ var.axes[2]
                container = Dict(
                    :name => string(sym), :is_jump_data => true, :selection => [res]
                )
                key_str = "variables.$sym"
                add_description!(available_data, container, gui, key_str)
            end
        else
            container = Dict(
                :name => string(sym), :is_jump_data => true, :selection => EMB.Node[]
            )
            key_str = "variables.$sym"
            add_description!(available_data, container, gui, key_str)
        end
    end
end

"""
    add_description!(
        available_data::Vector{Dict},
        var::SparseVars,
        sym::Symbol,
        element::Plotable,
        gui::GUI,
    )

Add description to `available_data` for the JuMP variable `var` (with name `sym`) for `element`.
"""
function add_description!(
    available_data::Vector{Dict}, var::SparseVars, sym::Symbol, element::Plotable, gui::GUI
)
    fieldtypes = typeof.(first(keys(var.data)))
    if any(fieldtypes .<: Union{EMB.Node,Link,Area}) # nodes/area/links found in structure
        if exists(var, element) # current element found in structure
            extract_combinations!(gui, available_data, sym, element)
        end
    elseif any(fieldtypes .<: TransmissionMode) # TransmissionModes found in structure
        if isa(element, Transmission)
            for mode ∈ modes(element)
                if exists(var, mode) # current mode found in structure
                    extract_combinations!(gui, available_data, sym, mode)
                end
            end
        end
    elseif isnothing(element)
        extract_combinations!(gui, available_data, sym)
    end
end

"""
    extract_combinations!(gui::GUI, available_data::Vector{Dict}, sym::Symbol)

Extract all combinations of available resources in `model[sym]`, add descriptions to
`container`, and add `container` to `available_data`.
"""
function extract_combinations!(gui::GUI, available_data::Vector{Dict}, sym::Symbol)
    model = get_model(gui)
    resources::Vector{Resource} = unique([key[2] for key ∈ keys(model[sym].data)])
    for res ∈ resources
        sym_str = string(sym)
        container = Dict(:name => sym_str, :is_jump_data => true, :selection => [res])
        add_description!(available_data, container, gui, "variables.$sym_str")
    end
end

"""
    extract_combinations!(
        gui::GUI, available_data::Vector{Dict}, sym::Symbol, element::Plotable
    )

Extract all combinations of available resources in `model[sym]` for a given `element`, add
descriptions to `container`, and add `container` to `available_data`.
"""
function extract_combinations!(
    gui::GUI, available_data::Vector{Dict}, sym::Symbol, element::Plotable
)
    model = get_model(gui)
    if isa(model[sym], SparseVariables.IndexedVarArray)
        sym_str = string(sym)
        container = Dict(:name => sym_str, :is_jump_data => true, :selection => [element])
        add_description!(available_data, container, gui, "variables.$sym_str")
    else
        resources = unique([key[2] for key ∈ keys(model[sym][element, :, :].data)])
        for res ∈ resources
            sym_str = string(sym)
            container = Dict(
                :name => sym_str, :is_jump_data => true, :selection => [element, res]
            )
            add_description!(available_data, container, gui, "variables.$sym_str")
        end
    end
end

"""
    get_data(
        model::JuMP.Model,
        selection::Dict{Symbol, Any},
        T::TS.TimeStructure,
        sp::Int64,
        rp::Int64
        sc::Int64,
    )

Get the values from the JuMP `model`, or the input data, at `selection` for all periods in `T`
restricted to strategic period `sp`, representative period `rp`, and scenario `sc`.
"""
function get_data(
    model::JuMP.Model, selection::Dict, T::TS.TimeStructure, sp::Int64, rp::Int64, sc::Int64
)
    if selection[:is_jump_data]
        sym = Symbol(selection[:name])
        i_T, type = get_time_axis(model[sym])
    else
        field_data = selection[:field_data]
        type = typeof(field_data)
    end
    periods, time_axis = get_periods(T, type, sp, rp, sc)
    if selection[:is_jump_data]
        y_values = get_jump_values(model, sym, selection[:selection], periods, i_T)
    else
        y_values = field_data[periods]
    end
    return periods, y_values, time_axis
end

"""
    get_jump_values(
        model::JuMP.Model, sym::Symbol, selection::Vector, periods::Vector, i_T::Int64
    )

Get the values from the JuMP `model` for a JuMP variable `sym` at `selection` containing all
indices except for the time index from which we want to extract all values in the vector `periods`).
The time dimension is located at `i_T` of `model[sym]`.
"""
function get_jump_values(
    model::JuMP.Model, sym::Symbol, selection::Vector, periods::Vector, i_T::Int64
)
    return [
        value(model[sym][vcat(selection[1:(i_T - 1)], t, selection[i_T:end])...]) for
        t ∈ periods
    ]
end

"""
    get_periods(
        T::TS.TimeStructure, type::Type, sp::Int64, rp::Int64, sc::Int64
    )

Get the periods for a given TimePeriod `type` (TS.StrategicPeriod, TS.RepresentativePeriod
or TS.OperationalPeriod) restricted to the strategic period `sp`, representative period `rp`
and the scenario `sc`.
"""
function get_periods(T::TS.TimeStructure, type::Type, sp::Int64, rp::Int64, sc::Int64)
    if type <: TS.StrategicPeriod
        return [t for t ∈ TS.strat_periods(T)], :results_sp
    elseif type <: TS.TimeStructure{T} where {T}
        return [t for t ∈ TS.repr_periods(T)], :results_rp
    else
        if eltype(T.operational) <: TS.RepresentativePeriods
            if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
                return [
                    t for
                    t ∈ T if t.sp == sp && t.period.rp == rp && t.period.period.sc == sc
                ],
                :results_op
            else
                return [t for t ∈ T if t.sp == sp && t.period.rp == rp], :results_op
            end
        elseif eltype(T.operational) <: TS.OperationalScenarios
            return [t for t ∈ T if t.sp == sp && t.period.sc == sc], :results_op
        else
            return [t for t ∈ T if t.sp == sp], :results_op
        end
    end
end

"""
    get_time_axis(
        data::Union{
            JuMP.Containers.DenseAxisArray,
            JuMP.Containers.SparseAxisArray,
            SparseVariables.IndexedVarArray,
        },
    )

Get the index of the axis/column of `data` (i.e. from a JuMP variable) corresponding to
TS.TimePeriod and return this index (`i_T`) alongside its TimeStruct type.
"""
function get_time_axis(
    data::Union{
        JuMP.Containers.DenseAxisArray,
        JuMP.Containers.SparseAxisArray,
        SparseVariables.IndexedVarArray,
    },
)
    types::Vector{Type} = collect(get_jump_axis_types(data))
    i_T::Union{Int64,Nothing} = findfirst(
        x -> x <: TS.TimePeriod || x <: TS.TimeStructure{T} where {T}, types
    )
    if isnothing(i_T)
        return i_T, nothing
    else
        return i_T, types[i_T]
    end
end

"""
    get_jump_axis_types(data::JuMP.Containers.DenseAxisArray)

Get the types for each axis in the data.
"""
function get_jump_axis_types(data::JuMP.Containers.DenseAxisArray)
    return eltype.(axes(data))
end
function get_jump_axis_types(data::SparseVars)
    return typeof.(first(keys(data.data)))
end

"""
    create_label(selection::Vector{Any})

Return a label for a given `selection` to be used in the get_menus(gui)[:available_data] menu.
"""
function create_label(selection::Dict{Symbol,Any})
    label::String = selection[:is_jump_data] ? "" : "Case data: "
    if haskey(selection, :description)
        label *= selection[:description] * " ($(selection[:name]))"
    else
        label *= selection[:name]
    end
    otherRes::Bool = false
    if length(selection) > 1
        for select ∈ selection[:selection]
            if !isa(select, Plotable)
                if !otherRes
                    label *= " ("
                    otherRes = true
                end
                label *= "$(select)"
                if select != selection[:selection][end]
                    label *= ", "
                end
            end
        end
        if otherRes
            label *= ")"
        end
    end
    return label
end

"""
    update_plot!(gui::GUI, element)

Based on `element` update the results in `get_axes(gui)[:results]`.
"""
function update_plot!(gui::GUI, element::Plotable)
    # Get global time structure
    T = get_root_design(gui).system[:T]

    # Extract menu objects from gui
    time_menu = get_menu(gui, :time)
    period_menu = get_menu(gui, :period)
    representative_period_menu = get_menu(gui, :representative_period)
    scenario_menu = get_menu(gui, :scenario)
    available_data_menu = get_menu(gui, :available_data)

    # Get data selection
    selection = available_data_menu.selection[]
    if !isnothing(selection) && selection != "no options"
        xlabel = "Time"
        if haskey(selection, :description)
            ylabel = selection[:description]
        else
            ylabel = selection[:name]
        end
        sp = period_menu.selection[]
        rp = representative_period_menu.selection[]
        sc = scenario_menu.selection[]

        periods, y_values, time_axis = get_data(get_model(gui), selection, T, sp, rp, sc)

        label::String = create_label(selection)
        if !isnothing(element)
            label *= " for $element"
        end
        if time_axis == :results_sp
            xlabel *= " (StrategicPeriods)"
        elseif time_axis == :results_rp
            xlabel *= " (RepresentativePeriods)"
        elseif time_axis == :results_op
            xlabel *= " (OperationalPeriods)"

            if eltype(T.operational) <: TS.RepresentativePeriods
                if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
                    label *= " for strategic period $sp, representative period $rp and scenario $sc"
                else
                    label *= " for strategic period $sp and representative period $rp"
                end
            elseif eltype(T.operational) <: TS.RepresentativePeriods
                label *= " for strategic period $sp and representative period $rp"
            else
                label *= " for strategic period $sp"
            end
        end

        no_pts = length(periods)
        # For FixedProfiles, make sure the y_values are extended correspondingly to the x_values
        if no_pts > length(y_values)
            y_values = vcat(y_values, fill(y_values[end], no_pts - length(y_values)))
        end
        if time_axis == :results_op
            x_values = get_op.(periods)
            x_values_step, y_values_step = stepify(vec(x_values), vec(y_values))
            # For FixedProfile, make values constant over the operational period
            points = [Point{2,Float64}(x, y) for (x, y) ∈ zip(x_values_step, y_values_step)]
            custom_ticks = (0:no_pts, string.(0:no_pts))
            time_menu.i_selected[] = 3
        else
            points = [Point{2,Float64}(x, y) for (x, y) ∈ zip(1:no_pts, y_values)]
            custom_ticks = (1:no_pts, [string(t) for t ∈ periods])
            if time_axis == :results_sp
                time_menu.i_selected[] = 1
            else
                time_menu.i_selected[] = 2
            end
        end
        notify(time_menu.selection) # In case the new plot is on an other time type
        pinned_plots = [x[:plot] for x ∈ get_pinned_data(gui, time_axis)]
        visible_plots = [x[:plot] for x ∈ get_visible_data(gui, time_axis)]
        plots = filter(
            x ->
                (isa(x, Combined) || isa(x, Lines)) &&
                    !isa(x, Wireframe) &&
                    !(x ∈ pinned_plots),
            get_axes(gui)[time_axis].scene.plots,
        ) # Extract non-pinned plots. Only extract Lines and Combined (bars). Done to avoid Wireframe-objects

        plot = getfirst(x -> x ∈ visible_plots, plots) # get first non-pinned visible plots
        if isnothing(plot)
            @debug "Could not find a visible plot to overwrite, try to find a hidden plot to overwrite"
            plot = getfirst(
                x ->
                    (isa(x, Combined) || isa(x, Lines)) &&
                        !isa(x, Wireframe) &&
                        !x.visible[],
                plots,
            ) # Extract non-visible plots that can be replaced
            if !isnothing(plot) # Overwrite a hidden plots
                @debug "Found a hidden plot to overwrite"
                push!(
                    get_visible_data(gui, time_axis),
                    Dict(
                        :plot => plot,
                        :name => selection[:name],
                        :selection => selection[:selection],
                        :t => periods,
                        :y => y_values,
                        :color => plot.color[],
                    ),
                )
            end
        else # Overwrite the non-pinned visible plot
            @debug "Found a visible plot to overwrite"
            # remove the plot to be overwritten
            filter!(x -> x[:plot] != plot, get_visible_data(gui, time_axis))

            push!(
                get_visible_data(gui, time_axis),
                Dict(
                    :plot => plot,
                    :name => selection[:name],
                    :selection => selection[:selection],
                    :t => periods,
                    :y => y_values,
                    :color => plot.color[],
                ),
            )
        end
        ax = get_ax(gui, time_axis)
        if !isnothing(plot)
            plot[1][] = points
            plot.visible = true # If it has been hidden after a "Remove Plot" action
            plot.label = label
        else
            @debug "Could not find anything to overwrite, creating new plot instead"
            if time_axis == :results_op
                plot = lines!(ax, points; label=label)
            else
                n_visible = length(get_visible_data(gui, time_axis)) + 1
                plot = barplot!(
                    ax,
                    points;
                    dodge=n_visible * ones(Int, length(points)),
                    n_dodge=n_visible,
                    strokecolor=:black,
                    strokewidth=1,
                    label=label,
                )
            end
            push!(
                get_visible_data(gui, time_axis),
                Dict(
                    :plot => plot,
                    :name => selection[:name],
                    :selection => selection[:selection],
                    :t => periods,
                    :y => y_values,
                    :color => plot.color[],
                ),
            )
            plot.kw[:EMGUI_obj] = get_visible_data(gui, time_axis)[end]
        end
        update_barplot_dodge!(gui)
        if all(y_values .≈ 0)
            # Deactivate inspector for bars to avoid issue with wireframe when selecting
            # a bar with values being zero
            toggle_inspector!(plot, false)
        end

        legend = get_results_legend(gui)
        if isempty(legend) # Initialize the legend box
            push!(
                legend, axislegend(ax, [plot], [label]; labelsize=get_var(gui, :fontsize))
            ) # Add legends inside axes[:results] area
        else
            update_legend!(gui)
        end

        if time_axis == :results_op
            ax.xticks = Makie.automatic
        else
            ax.xticks = custom_ticks
        end
        ax.xlabel = xlabel
        ax.ylabel = ylabel
    end
end

"""
    update_plot!(gui::GUI)

Based on `selected_systems` update plots.
"""
function update_plot!(gui)
    selected_systems = get_selected_systems(gui)
    if isempty(selected_systems)
        update_plot!(gui, nothing)
    else
        update_plot!(gui, selected_systems[end])
    end
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `connection` update plots.
"""
function update_plot!(gui::GUI, connection::Connection)
    return update_plot!(gui, get_connection(connection))
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `design` update plots.
"""
function update_plot!(gui::GUI, design::EnergySystemDesign)
    return update_plot!(gui, get_system_node(design))
end

"""
    update_legend!(gui::GUI)

Update the legend based on the visible plots of type `time_axis`.
"""
function update_legend!(gui::GUI)
    time_axis = get_menu(gui, :time).selection[]
    legend = get_results_legend(gui)
    if !isempty(legend)
        legend_defaults = Makie.block_defaults(
            :Legend, Dict{Symbol,Any}(), get_ax(gui, time_axis).scene
        )
        labels = [x[:plot].label for x ∈ get_visible_data(gui, time_axis)]
        contents = [x[:plot] for x ∈ get_visible_data(gui, time_axis)]
        title = nothing
        entry_groups = Makie.to_entry_group(
            Attributes(legend_defaults), contents, labels, title
        )
        legend[1].entrygroups[] = entry_groups
    end
end

"""
    update_limits!(gui::GUI)

Update the limits based on the visible plots of type `time_axis`.
"""
function update_limits!(ax::Axis)
    autolimits!(ax)
    yorigin = ax.finallimits[].origin[2]
    ywidth = ax.finallimits[].widths[2]

    # ensure that the legend box does not overlap the data
    ylims!(ax, yorigin, yorigin + ywidth * 1.1)
end

"""
    update_barplot_dodge!(gui::GUI)

Update the barplot of the state of the GUI (such that the bars are dodged away from each other).
"""
function update_barplot_dodge!(gui::GUI)
    time_axis = get_menu(gui, :time).selection[]
    if time_axis != :results_op
        visible_data = get_visible_data(gui, time_axis)
        n_visible = length(visible_data)
        for (i, x) ∈ enumerate(visible_data)
            x[:plot].n_dodge = n_visible
            x[:plot].dodge = i * ones(Int, length(x[:plot].dodge[]))
        end
    end
end
