"""
    extract_combinations!(
        gui::GUI,
        available_data::Vector{Dict},
        dict::Symbol,
        model
    )

Extract all available resources in `model[dict]`
"""
function extract_combinations!(gui::GUI, available_data::Vector{Dict}, dict::Symbol, model)
    resources::Vector{Resource} = unique([key[2] for key ∈ keys(model[dict].data)])
    for res ∈ resources
        dict_str = string(dict)
        container = Dict(:name => dict_str, :is_jump_data => true, :selection => [res])
        add_description!(available_data, container, gui, "variables.$dict_str")
    end
end

"""
    extract_combinations!(available_data::Vector{Dict}, dict::Symbol, node::Plotable, model)

Extract all available resources in `model[dict]` for a given `node`.
"""
function extract_combinations!(
    gui::GUI, available_data::Vector{Dict}, dict::Symbol, node::Plotable, model
)
    if isa(model[dict], SparseVariables.IndexedVarArray)
        dict_str = string(dict)
        container = Dict(:name => dict_str, :is_jump_data => true, :selection => [node])
        add_description!(available_data, container, gui, "variables.$dict_str")
    else
        resources = unique([key[2] for key ∈ keys(model[dict][node, :, :].data)])
        for res ∈ resources
            dict_str = string(dict)
            container = Dict(
                :name => dict_str, :is_jump_data => true, :selection => [node, res]
            )
            add_description!(available_data, container, gui, "variables.$dict_str")
        end
    end
end

"""
    add_description!(
        field::Dict,
        name::String,
        key_str::String,
        pre_desc::String,
        node::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

Update the container with a description if available, and add description to available_data.
"""
function add_description!(
    field::Dict,
    name::String,
    key_str::String,
    pre_desc::String,
    node::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    for (dictname, dictvalue) ∈ field
        name_field = "$name.$dictname"
        key_str_field = "$key_str.$dictname"
        add_description!(
            dictvalue, name_field, key_str_field, pre_desc, node, available_data, gui
        )
    end
end

"""
    add_description!(
        field::Vector,
        name::String,
        key_str::String,
        pre_desc::String,
        node::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

If field is a vector, loop through the vector and update the container with a description
if available, and add description to available_data.
"""
function add_description!(
    field::Vector,
    name::String,
    key_str::String,
    pre_desc::String,
    node::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
)
    for data ∈ field
        data_type = nameof(typeof(data))
        name_field = "$name.$data_type"
        key_str_field = "$key_str.$data_type"
        add_description!(
            data, name_field, key_str_field, pre_desc, node, available_data, gui
        )
    end
end

"""
    add_description!(
        field::Any,
        name::String,
        key_str::String,
        pre_desc::String,
        node::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    )

Update the container with a description if available, and add description to available_data.
"""
function add_description!(
    field::Any,
    name::String,
    key_str::String,
    pre_desc::String,
    node::Plotable,
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
            sub_field, name_field, key_str, pre_desc_sub, node, available_data, gui
        )
    end
end

"""
    add_description!(
        field::T,
        name::String,
        key_str::String,
        pre_desc::String,
        node::Plotable,
        available_data::Vector{Dict},
        gui::GUI,
    ) where {T<:TS.TimeProfile}

Update the container with a description if available, and add description to available_data.
"""
function add_description!(
    field::T,
    name::String,
    key_str::String,
    pre_desc::String,
    node::Plotable,
    available_data::Vector{Dict},
    gui::GUI,
) where {T<:TS.TimeProfile}
    container = Dict(
        :name => name, :is_jump_data => false, :selection => [node], :field_data => field
    )
    add_description!(available_data, container, gui, key_str; pre_desc)
end

"""
    add_description!(
        available_data::Vector{Dict},
        container::Dict{Symbol,Any},
        gui::GUI,
        key_str::String;
        pre_desc::String="",
    )

Update the container with a description if available, and add container to available_data.
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
        description *= String(get_nested_value(gui.vars[:descriptive_names], key_str))
    catch
        description = key_str[(findfirst('.', key_str) + 1):end]
        @warn "Could't find a description for $description. \
            Using the string $description instead"
    end
    container[:description] = description
    push!(available_data, container)
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

Get the values from the JuMP `model` or the input data for at `selection` for all times `T`
restricted to strategic period `sp`, representative period `rp`, and scenario `sc`.
"""
function get_data(
    model::JuMP.Model, selection::Dict, T::TS.TimeStructure, sp::Int64, rp::Int64, sc::Int64
)
    if selection[:is_jump_data]
        dict = Symbol(selection[:name])
        i_T, type = get_time_axis(model[dict])
    else
        field_data = selection[:field_data]
        type = typeof(field_data)
    end
    t_values, time_axis = get_time_values(T, type, sp, rp, sc)
    if selection[:is_jump_data]
        y_values = get_jump_values(model, dict, selection[:selection], t_values, i_T)
    else
        y_values = field_data[t_values]
    end
    return t_values, y_values, time_axis
end

"""
    get_jump_values(
        model::JuMP.Model, var::Symbol, selection::Vector, t_values::Vector, i_T::Int64
    )

Get the values from the JuMP `model` for symbol `var` at `selection` for all times `T` \
restricted to `sp`
"""
function get_jump_values(
    model::JuMP.Model, var::Symbol, selection::Vector, t_values::Vector, i_T::Int64
)
    return [
        value(model[var][vcat(selection[1:(i_T - 1)], t, selection[i_T:end])...]) for
        t ∈ t_values
    ]
end

"""
    get_time_values(
        T::TS.TimeStructure, type::Type, sp::Int64, rp::Int64, sc::Int64
    )

Get the time values for a given time type (TS.StrategicPeriod, TS.RepresentativePeriod
or TS.OperationalPeriod)
"""
function get_time_values(T::TS.TimeStructure, type::Type, sp::Int64, rp::Int64, sc::Int64)
    if type <: TS.StrategicPeriod
        return [t for t ∈ TS.strat_periods(T)], :StrategicPeriod
    elseif type <: TS.TimeStructure{T} where {T}
        return [t for t ∈ TS.repr_periods(T)], :RepresentativePeriod
    else
        if eltype(T.operational) <: TS.RepresentativePeriods
            if eltype(T.operational[sp].rep_periods) <: TS.OperationalScenarios
                return [
                    t for
                    t ∈ T if t.sp == sp && t.period.rp == rp && t.period.period.sc == sc
                ],
                :OperationalPeriod
            else
                return [t for t ∈ T if t.sp == sp && t.period.rp == rp], :OperationalPeriod
            end
        elseif eltype(T.operational) <: TS.OperationalScenarios
            return [t for t ∈ T if t.sp == sp && t.period.sc == sc], :OperationalPeriod
        else
            return [t for t ∈ T if t.sp == sp], :OperationalPeriod
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

Get the index of the axis/column corresponding to TS.TimePeriod and return the specific type.
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

Return a label for a given `selection` to be used in the gui.menus[:available_data] menu.
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
    update_plot!(gui::GUI, node)

Based on `node` update the results in `gui.axes[:results]`.
"""
function update_plot!(gui::GUI, node::Plotable)
    T = gui.root_design.system[:T]
    selection = gui.menus[:available_data].selection[]
    if !isnothing(selection)
        xlabel = "Time"
        if haskey(selection, :description)
            ylabel = selection[:description]
        else
            ylabel = selection[:name]
        end
        sp = gui.menus[:period].selection[]
        rp = gui.menus[:representative_period].selection[]
        sc = gui.menus[:scenario].selection[]

        t_values, y_values, time_axis = get_data(gui.model, selection, T, sp, rp, sc)

        label::String = create_label(selection)
        if !isnothing(node)
            label *= " for $node"
        end
        if time_axis == :StrategicPeriod
            xlabel *= " (StrategicPeriod)"
        elseif time_axis == :RepresentativePeriod
            xlabel *= " (RepresentativePeriod)"
        elseif time_axis == :OperationalPeriod
            xlabel *= " (OperationalPeriod)"

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

        no_pts = length(t_values)
        # For FixedProfiles, make sure the y_values are extended correspondingly to the x_values
        if no_pts > length(y_values)
            y_values = vcat(y_values, fill(y_values[end], no_pts - length(y_values)))
        end
        if time_axis == :OperationalPeriod
            x_values = get_op.(t_values)
            x_values_step, y_values_step = stepify(vec(x_values), vec(y_values))
            # For FixedProfile, make values constant over the operational period
            points = [Point{2,Float64}(x, y) for (x, y) ∈ zip(x_values_step, y_values_step)]
            custom_ticks = (0:no_pts, string.(0:no_pts))
            gui.menus[:time].i_selected[] = 3
        else
            points = [Point{2,Float64}(x, y) for (x, y) ∈ zip(1:no_pts, y_values)]
            custom_ticks = (1:no_pts, [string(t) for t ∈ t_values])
            if time_axis == :StrategicPeriod
                gui.menus[:time].i_selected[] = 1
            else
                gui.menus[:time].i_selected[] = 2
            end
        end
        notify(gui.menus[:time].selection) # In case the new plot is on an other time type
        time_axis = gui.menus[:time].selection[]
        pinned_plots = [x[:plot] for x ∈ gui.vars[:pinned_plots][time_axis]]
        visible_plots = [x[:plot] for x ∈ gui.vars[:visible_plots][time_axis]]
        plots = filter(
            x ->
                (isa(x, Combined) || isa(x, Lines)) &&
                    !isa(x, Wireframe) &&
                    !(x ∈ pinned_plots),
            gui.axes[time_axis].scene.plots,
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
                    gui.vars[:visible_plots][time_axis],
                    Dict(
                        :plot => plot,
                        :name => selection[:name],
                        :selection => selection[:selection],
                        :t => t_values,
                        :y => y_values,
                        :color => plot.color[],
                    ),
                )
            end
        else # Overwrite the non-pinned visible plot
            @debug "Found a visible plot to overwrite"
            # remove the plot to be overwritten
            filter!(x -> x[:plot] != plot, gui.vars[:visible_plots][time_axis])

            push!(
                gui.vars[:visible_plots][time_axis],
                Dict(
                    :plot => plot,
                    :name => selection[:name],
                    :selection => selection[:selection],
                    :t => t_values,
                    :y => y_values,
                    :color => plot.color[],
                ),
            )
        end

        if !isnothing(plot)
            plot[1][] = points
            plot.visible = true # If it has been hidden after a "Remove Plot" action
            plot.label = label
        else
            @debug "Could not find anything to overwrite, creating new plot instead"
            if time_axis == :OperationalPeriod
                plot = lines!(gui.axes[time_axis], points; label=label)
            else
                n_visible = length(gui.vars[:visible_plots][time_axis]) + 1
                plot = barplot!(
                    gui.axes[time_axis],
                    points;
                    dodge=n_visible * ones(Int, length(points)),
                    n_dodge=n_visible,
                    strokecolor=:black,
                    strokewidth=1,
                    label=label,
                )
            end
            push!(
                gui.vars[:visible_plots][time_axis],
                Dict(
                    :plot => plot,
                    :name => selection[:name],
                    :selection => selection[:selection],
                    :t => t_values,
                    :y => y_values,
                    :color => plot.color[],
                ),
            )
        end
        update_barplot_dodge!(gui)
        if all(y_values .≈ 0)
            # Deactivate inspector for bars to avoid issue with wireframe when selecting
            # a bar with values being zero
            toggle_inspector!(plot, false)
        end

        if isempty(gui.vars[:results_legend]) # Initialize the legend box
            push!(
                gui.vars[:results_legend],
                axislegend(
                    gui.axes[time_axis], [plot], [label]; labelsize=gui.vars[:fontsize]
                ),
            ) # Add legends inside axes[:results] area
        else
            update_legend!(gui)
        end

        if time_axis == :OperationalPeriod
            gui.axes[time_axis].xticks = Makie.automatic
        else
            gui.axes[time_axis].xticks = custom_ticks
        end
        gui.axes[time_axis].xlabel = xlabel
        gui.axes[time_axis].ylabel = ylabel
    end
end

"""
    update_legend!(gui::GUI)

Update the legend based on the visible plots of type `time_axis`
"""
function update_legend!(gui::GUI)
    time_axis = gui.menus[:time].selection[]
    if !isempty(gui.vars[:results_legend])
        gui.vars[:results_legend][1].entrygroups[] = [(
            nothing,
            #! format: off
            [
                LegendEntry(x[:plot].label, x[:plot], gui.vars[:results_legend][1])
                for x ∈ gui.vars[:visible_plots][time_axis]
            ],
            #! format: on
        )]
    end
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `connection.connection` update the results in `gui.axes[:results]`
"""
function update_plot!(gui::GUI, connection::Connection)
    return update_plot!(gui, connection.connection)
end

"""
    update_plot!(gui::GUI, design::EnergySystemDesign)

Based on `design.system[:node]` update the results in `gui.axes[:results]`
"""
function update_plot!(gui::GUI, design::EnergySystemDesign)
    return update_plot!(gui, design.system[:node])
end

"""
    update_barplot_dodge!(gui::GUI)

Update the barplot of the state of the GUI (such that the bars are dodged away from each other)
"""
function update_barplot_dodge!(gui::GUI)
    if gui.menus[:time].selection[] != :results_op
        time_axis = gui.menus[:time].selection[]
        n_visible = length(gui.vars[:visible_plots][time_axis])
        for (i, x) ∈ enumerate(gui.vars[:visible_plots][time_axis])
            x[:plot].n_dodge = n_visible
            x[:plot].dodge = i * ones(Int, length(x[:plot].dodge[]))
        end
    end
end
