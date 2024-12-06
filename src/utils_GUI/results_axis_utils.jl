"""
    create_description(
        gui::GUI,
        key_str::String;
        pre_desc::String="",
    )

Create description from `get_var(gui,:descriptive_names)` if available
"""
function create_description(gui::GUI, key_str::String; pre_desc::String="")
    description = pre_desc
    try
        description *= String(get_nested_value(get_var(gui, :descriptive_names), key_str))
    catch
        description = key_str[(findfirst('.', key_str) + 1):end]
        @warn "Could't find a description for $description. \
            Using the string $description instead. \
            You can customize the descriptions as explained here: \
            https://energymodelsx.github.io/EnergyModelsGUI.jl/stable/how-to/customize-descriptive_names/"
    end
    return description
end

"""
    add_description!(
        field::TS.TimeProfile,
        name::String,
        key_str::String,
        pre_desc::String,
        element::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

Create a container with a description, and add `container` to `available_data`.
"""
function add_description!(
    field::TS.TimeProfile,
    name::String,
    key_str::String,
    pre_desc::String,
    element::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    container = Dict(
        :name => name,
        :is_jump_data => false,
        :selection => [element],
        :field_data => field,
        :description => create_description(gui, key_str; pre_desc),
    )
    push!(available_data, container)
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

Loop through all `dictnames` for a `field` of type `Dict` (*e.g.* for the field `penalty`
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
    key_str::String,
    pre_desc::String,
    element::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    structure = get_nth_field(key_str, '.', 3)
    if structure == "to" || structure == "from" # don't add `to` and `from` fields
        return nothing
    end
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
    field_data = selection[:field_data]
    if selection[:is_jump_data]
        sym = Symbol(selection[:name])
        i_T, type = get_time_axis(model[sym])
    else
        type = nested_eltype(field_data)
    end
    periods, time_axis = get_periods(T, type, sp, rp, sc)
    if selection[:is_jump_data]
        if isa(field_data, JuMP.Containers.SparseAxisArray)
            y_values = [value(field_data[t]) for t ∈ periods]
        else
            y_values = Array(value.(field_data[periods]))
        end
    else
        y_values = field_data[periods]
    end
    return periods, y_values, time_axis
end

"""
    get_periods(T::TS.TimeStructure, type::Type, sp::Int64, rp::Int64, sc::Int64)

Get the periods for a given TimePeriod/TimeProfile `type` (*e.g.*, TS.StrategicPeriod,
TS.RepresentativePeriod, TS.OperationalPeriod) restricted to
the strategic period `sp`, representative period `rp` and the scenario `sc`.
"""
function get_periods(T::TS.TimeStructure, type::Type, sp::Int64, rp::Int64, sc::Int64)
    if type <: StrategicProfile ||
        type <: FixedProfile ||
        type <: TS.AbstractStrategicPeriod
        return collect(TS.strat_periods(T)), :results_sp
    elseif type <: TS.RepresentativeProfile || type <: TS.AbstractRepresentativePeriod
        return [t for t ∈ TS.repr_periods(T) if t.sp == sp], :results_rp
    elseif type <: TS.ScenarioProfile || type <: TS.ScenarioPeriod
        if eltype(T.operational) <: TS.RepresentativePeriods
            return [t for t ∈ TS.opscenarios(T) if t.sp == sp && t.rp == rp], :results_sc
        else
            return [t for t ∈ TS.opscenarios(T) if t.sp == sp], :results_sc
        end
    else
        if eltype(T.operational) <: TS.RepresentativePeriods
            if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
                return [
                    t for
                    t ∈ T if t.sp == sp && t.period.rp == rp && t.period.period.osc == sc
                ],
                :results_op
            else
                return [t for t ∈ T if t.sp == sp && t.period.rp == rp], :results_op
            end
        elseif eltype(T.operational) <: TS.OperationalScenarios
            return [t for t ∈ T if t.sp == sp && t.period.osc == sc], :results_op
        else
            return [t for t ∈ T if t.sp == sp], :results_op
        end
    end
end
function get_periods(T::TS.TimeStructure, ::Type{<:TS.AbstractStrategicPeriod})
    return collect(TS.strat_periods(T))
end
function get_periods(T::TS.TimeStructure, ::Type{<:TS.AbstractRepresentativePeriod})
    return collect(TS.repr_periods(T))
end
function get_periods(T::TS.TimeStructure, ::Type{<:TS.ScenarioPeriod})
    return collect(TS.opscenarios(T))
end
function get_periods(T::TS.TimeStructure, ::Type{<:Any})
    return collect(T)
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
    label::String =
        (selection[:is_jump_data] || isempty(selection[:name])) ? "" : "Case data: "
    if haskey(selection, :description)
        if isempty(selection[:name])
            label *= selection[:description]
        else
            label *= selection[:description] * " ($(selection[:name]))"
        end
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
    return update_plot!(gui, get_element(connection))
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `design` update plots.
"""
function update_plot!(gui::GUI, design::EnergySystemDesign)
    return update_plot!(gui, get_element(design))
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
            label *= " for strategic period $sp"
        elseif time_axis == :results_sc
            xlabel *= " (Scenarios)"

            if eltype(T.operational) <: TS.RepresentativePeriods
                label *= " for strategic period $sp and representative period $rp"
            else
                label *= " for strategic period $sp"
            end
        elseif time_axis == :results_op
            xlabel *= " (OperationalPeriods)"

            if eltype(T.operational) <: TS.RepresentativePeriods
                if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
                    label *= " for strategic period $sp, representative period $rp and scenario $sc"
                else
                    label *= " for strategic period $sp and representative period $rp"
                end
            elseif eltype(T.operational) <: TS.OperationalScenarios
                label *= " for strategic period $sp and scenario $sc"
            else
                label *= " for strategic period $sp"
            end
        end

        no_pts = length(periods)
        if time_axis == :results_op
            x_values = get_op.(periods)
            points = [Point{2,Float64}(x, y) for (x, y) ∈ zip(x_values, y_values)]
            custom_ticks = (1:no_pts, string.(1:no_pts))
            time_menu.i_selected[] = 4
        else
            points = [Point{2,Float64}(x, y) for (x, y) ∈ zip(1:no_pts, y_values)]
            custom_ticks = (1:no_pts, [string(t) for t ∈ periods])
            if time_axis == :results_sp
                time_menu.i_selected[] = 1

                # Use customized labels for strategic periods if provided
                periods_labels = get_var(gui, :periods_labels)
                if !isempty(periods_labels)
                    custom_ticks = (1:no_pts, periods_labels[1:no_pts])
                end
            elseif time_axis == :results_rp
                time_menu.i_selected[] = 2

                # Use customized labels for representative periods if provided
                repr_periods_labels = get_var(gui, :representative_periods_labels)
                if !isempty(repr_periods_labels)
                    custom_ticks = (1:no_pts, repr_periods_labels[1:no_pts])
                end
            elseif time_axis == :results_sc
                time_menu.i_selected[] = 3

                # Use customized labels for scenarios if provided
                scenarios_labels = get_var(gui, :scenarios_labels)
                if !isempty(scenarios_labels)
                    custom_ticks = (1:no_pts, scenarios_labels[1:no_pts])
                end
            end
        end
        if time_axis == :results_op
            xticks = Makie.automatic
        else
            xticks = custom_ticks
        end
        plotted_data = get_plotted_data(gui)

        overwritable = getfirst(
            x -> !x[:pinned] && x[:time_axis] == time_axis, plotted_data
        ) # get first non-pinned plot

        ax = get_ax(gui, :results)
        finallimits = gui.vars[:finallimits][time_axis]
        if isnothing(overwritable)
            @debug "Could not find anything to overwrite, creating new plot instead"
            n_visible = length(get_visible_data(gui, time_axis)) + 1
            colormap = get_var(gui, :colormap)
            i = (n_visible - 1 % length(colormap)) + 1
            color = Observable(parse(Colorant, colormap[i]))
            if time_axis == :results_op
                plot = stairs!(ax, points; step=:pre, label=label, color=color)
                plot.color = color
                plot.plots[1].color = color
            else
                plot = barplot!(
                    ax,
                    points;
                    dodge=n_visible * ones(Int, length(points)),
                    n_dodge=n_visible,
                    strokecolor=:black,
                    strokewidth=1,
                    label=label,
                    color=color,
                )
            end
            new_data = Dict(
                :plot => plot,
                :name => selection[:name],
                :selection => selection[:selection],
                :t => periods,
                :y => y_values,
                :color => color[],
                :color_obs => color,
                :pinned => false,
                :visible => true,
                :selected => false,
                :time_axis => time_axis,
                :xlabel => xlabel,
                :ylabel => ylabel,
                :xticks => xticks,
            )
            plot.kw[:EMGUI_obj] = new_data
            push!(plotted_data, new_data)
        else
            plot = overwritable[:plot]
            plot[1][] = points
            plot.visible[] = true # If it has been hidden after a "Remove Plot" action
            plot.label[] = label
            overwritable[:name] = selection[:name]
            overwritable[:selection] = selection[:selection]
            overwritable[:t] = periods
            overwritable[:y] = y_values
            overwritable[:pinned] = false
            overwritable[:visible] = true
            overwritable[:selected] = false
            overwritable[:time_axis] = time_axis
            overwritable[:xlabel] = xlabel
            overwritable[:ylabel] = ylabel
            overwritable[:xticks] = xticks
        end
        update_barplot_dodge!(gui)
        if all(y_values .≈ 0) && !(time_axis == :results_op)
            # Deactivate inspector for bars to avoid issue with wireframe when selecting
            # a bar with values being zero
            toggle_inspector!(plot, false)
        else
            toggle_inspector!(plot, true)
        end

        if isnothing(get_results_legend(gui)) # Initialize the legend box
            gui.legends[:results] = axislegend(
                ax, [plot], [label]; labelsize=get_var(gui, :fontsize)
            )
        else
            update_legend!(gui)
        end

        update_axis!(gui, time_axis)
        if get_var(gui, :autolimits)[time_axis]
            update_limits!(ax)
        else
            update_limits!(ax, finallimits)
        end
    end
end

"""
    update_axislabels!(gui::GUI, time_axis::Symbol)

Update the xlabel, ylabel and ticks of the :results axis
"""
function update_axis!(gui::GUI, time_axis::Symbol)
    selection = get_visible_data(gui, time_axis)
    if !isempty(selection)
        ax = get_ax(gui, :results)

        # Use data from last available visible data for time_axis
        ax.xlabel = selection[end][:xlabel]
        ax.ylabel = selection[end][:ylabel]
        ax.xticks = selection[end][:xticks]
    end
end

"""
    update_legend!(gui::GUI)

Update the legend based on the visible plots of type `time_axis`.
"""
function update_legend!(gui::GUI)
    time_axis = get_menu(gui, :time).selection[]
    legend = get_results_legend(gui)
    if !isnothing(legend)
        legend_defaults = Makie.block_defaults(
            :Legend, Dict{Symbol,Any}(), get_ax(gui, :results).scene
        )
        visible_data = get_visible_data(gui, time_axis)
        labels = [x[:plot].label[] for x ∈ visible_data]
        contents = [x[:plot] for x ∈ visible_data]
        title = nothing
        entry_groups = Makie.to_entry_group(
            Attributes(legend_defaults), contents, labels, title
        )
        legend.entrygroups[] = entry_groups
    end
end

"""
    get_vis_plots(ax::Axis)

Get visible BarPlots and Stairs plots.
"""
function get_vis_plots(ax::Axis)
    return [p for p ∈ ax.scene.plots if (isa(p, Stairs) || isa(p, BarPlot)) && p.visible[]]
end

"""
    update_limits!(ax::Axis)

Adjust limits automatically to take into account legend and machine epsilon issues.
"""
function update_limits!(ax::Axis)
    # Fetch all y-values in the axis
    barplots = getfirst(x -> isa(x, Makie.BarPlot) && x.visible[], ax.scene.plots)
    if isnothing(barplots)
        xy = vcat([p[1][] for p ∈ get_vis_plots(ax)]...)
        y = [pt[2] for pt ∈ xy]
        if isempty(y)
            return nothing
        end
        x = [pt[1] for pt ∈ xy]

        # Calculate the width of distribution of the data in the vertical direction
        max_x = maximum(x)
        min_x = minimum(x)
        max_y = maximum(y)
        min_y = minimum(y)
        ywidth = max_y - min_y
        xwidth = max_x - min_x

        # Do the following for data with machine epsilon precision noice around zero that causes
        # the warning "Warning: No strict ticks found" and the the bug related to issue #4266 in Makie
        if abs(ywidth) < 1e-13
            ywidth = 2.0
            yorigin = min_y - 1.0
        else
            yorigin = min_y - ywidth * 0.04
            ywidth += 2 * ywidth * 0.04
        end

        xlims!(ax, min_x - xwidth * 0.04, max_x + xwidth * 0.04)
    else
        autolimits!(ax)
        yorigin = ax.finallimits[].origin[2]
        ywidth = ax.finallimits[].widths[2]
    end
    # try to avoid legend box overlapping data
    ylims!(ax, yorigin, yorigin + ywidth * 1.1)
end

"""
    update_limits!(ax::Axis, limits::GLMakie.HyperRectangle)

Set the limits based on limits.
"""
function update_limits!(ax::Axis, limits::GLMakie.HyperRectangle)
    xmin = limits.origin[1]
    xmax = limits.origin[1] + limits.widths[1]
    ymin = limits.origin[2]
    ymax = limits.origin[2] + limits.widths[2]
    limits!(ax, xmin, xmax, ymin, ymax)
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
