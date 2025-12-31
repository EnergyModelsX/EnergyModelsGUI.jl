"""
    extract_svg(svg_string)

Extracts the raw SVG content from the representation.
"""
function extract_svg(svg_string)
    # Extracts the raw SVG content from the representation
    if isempty(svg_string)
        return "", ""
    else
        svg_start = findfirst("<svg", svg_string)[1]
        start_idx = findfirst(">", svg_string[svg_start:end])[end] + svg_start
        end_idx = findfirst("</svg>", svg_string)[1] - 1
        return svg_string[start_idx:end_idx], svg_string[1:(start_idx-1)]
    end
end

"""
    merge_svg_strings(svg1, svg2)

Merge two SVG strings `svg1` and `svg2` into one with header from `svg1`.
"""
function merge_svg_strings(svg1, svg2)
    svg_str1, header = extract_svg(svg1)
    svg_str2, _ = extract_svg(svg2)
    return header * svg_str1 * svg_str2 * "</svg>\n"
end

"""
    outer_bbox(ax::Makie.AbstractAxis; padding::Number = 0)

Compute the outer bounding box of the axis `ax` with additional `padding`.
"""
function outer_bbox(ax::Makie.AbstractAxis; padding::Number = 0)
    sbb = ax.layoutobservables.suggestedbbox[]
    # prot = ax.layoutobservables.protrusions[]
    prot = ax.layoutobservables.reporteddimensions[].outer
    o = sbb.origin .- (prot.left, prot.bottom) .- padding
    w = sbb.widths .+ (prot.left + prot.right, prot.bottom + prot.top) .+ 2 * padding
    return Rect2f(o, w)
end

"""
    get_svg(blockscene::Makie.Scene)

Get the SVG representation of the `blockscene`.
"""
function get_svg(blockscene::Makie.Scene)
    svg = mktempdir() do dir
        save(joinpath(dir, "output.svg"), blockscene; backend = CairoMakie)
        read(joinpath(dir, "output.svg"), String)
    end
    return svg
end

"""
    export_svg(ax::Makie.Block, filename::String)

Export the `ax` to a .svg file with path given by `filename`.

!!! note "Temporary approach"
    This approach awaits solution from issue https://github.com/MakieOrg/Makie.jl/issues/4500
"""
function export_svg(
    ax::Makie.Block, filename::String; legend::Union{Makie.Legend,Nothing} = nothing,
)
    bbox = outer_bbox(ax)
    _, sh = ax.blockscene.viewport[].widths
    ox, oy = bbox.origin
    w, h = bbox.widths
    svg_ax = get_svg(ax.blockscene)
    svg_legend = isnothing(legend) ? "" : get_svg(legend.blockscene)
    svg = merge_svg_strings(svg_ax, svg_legend)
    svg = replace(
        svg,
        r"viewBox=\".*?\"" => "viewBox=\"$ox $(sh - oy - h) $w $h\"",
        r"width=\".*?\"" => "width=\"$w\"",
        r"height=\".*?\"" => "height=\"$h\"",
        count = 3,
    )

    # Add white background
    svg_str1, header = extract_svg(svg)
    svg =
        header *
        """<rect x="$ox" y="$(sh - oy - h)" width="$w" height="$h" fill="white"/> """ *
        svg_str1 * "</svg>\n"

    open(filename, "w") do io
        print(io, svg)
    end
    return 0
end

"""
    export_xlsx(plots::Vector, filename::String, xlabel::Symbol)

Export the `plots` to a .xlsx file with path given by `filename` and top header `xlabel`.
"""
function export_xlsx(plots::Vector, filename::String, xlabel::Symbol)
    if isempty(plots)
        @warn "No data to be exported"
        return 1
    end
    # Create a new Excel file and write data
    XLSX.openxlsx(filename; mode = "w") do xf
        sheet = xf[1] # Access the first sheet

        no_columns = length(plots) + 1
        data = Vector{Any}(undef, no_columns)
        data[1] = string.(plots[1][:t])
        for (i, plot) ∈ enumerate(plots)
            data[i+1] = plot[:y]
        end
        labels::Vector{String} = [plot[:name] for plot ∈ plots]

        headers::Vector{String} = vcat(string(xlabel), labels)

        #XLSX.rename!(sheet, "My Data Sheet")
        XLSX.writetable!(sheet, data, headers)
    end
    return 0
end

"""
    export_xlsx(gui::GUI, filename::String)

Export the JuMP fields to an xlsx file with path given by `filename`.
"""
function export_xlsx(gui::GUI, filename::String)
    model = get_model(gui)
    if isempty(model)
        @warn "No data to be exported"
        return 1
    end
    # Create a new Excel file and write data
    XLSX.openxlsx(filename; mode = "w") do xf
        first_sheet::Bool = true
        for (i, dict) ∈ enumerate(get_JuMP_names(gui))
            container = model[dict]
            if isempty(container)
                continue
            end
            if first_sheet
                sheet = xf[1]
                XLSX.rename!(sheet, string(dict))
                first_sheet = false
            else
                sheet = XLSX.addsheet!(xf, string(dict))
            end
            if typeof(container) <: JuMP.Containers.DenseAxisArray
                axisTypes = nameof.([eltype(a) for a ∈ axes(model[dict])])
            elseif typeof(container) <: SparseVars
                axisTypes = collect(nameof.(typeof.(first(keys(container.data)))))
            else
                @info "dict = $dict, container = $container, typeof(container) = $(typeof(container))"
            end
            header = vcat(axisTypes, [:value])
            data_jump = JuMP.Containers.rowtable(value, container; header = header)
            no_columns = length(fieldnames(eltype(data_jump)))
            num_tuples = length(data_jump)
            data = [Vector{Any}(undef, num_tuples) for i ∈ range(1, no_columns)]
            for (i, nt) ∈ enumerate(data_jump)
                for (j, field) ∈ enumerate(fieldnames(typeof(nt)))
                    data[j][i] = string(getfield(nt, field))
                end
            end

            XLSX.writetable!(sheet, data, header)
        end
    end
    return 0
end

"""
    export_to_file(gui::GUI)

Export results based on the state of `gui` to a file located within the folder specified
through the `path_to_results` keyword of [`GUI`](@ref).
"""
function export_to_file(gui::GUI)
    path = get_var(gui, :path_to_results)
    if isempty(path)
        @error "Path not specified for exporting results; use GUI(case; path_to_results = \
                \"<path to exporting folder>\")"
        return nothing
    end
    if !isdir(path)
        mkpath(path)
    end
    axes_str::String = get_menu(gui, :axes).selection[]
    file_ending = get_menu(gui, :export_type).selection[]
    filename = joinpath(path, axes_str * "." * file_ending)
    if file_ending ∈ ["svg"]
        CairoMakie.activate!() # Set CairoMakie as backend for proper export quality
        cairo_makie_activated = true
    else
        cairo_makie_activated = false
    end
    if file_ending == "lp" || file_ending == "mps"
        if isa(get_model(gui), DataFrame)
            @info "Writing model to a $file_ending file is not supported when reading results from .csv-files"
            return 1
        elseif isempty(get_model(gui))
            @info "No model to be exported"
            return 2
        end
        try
            write_to_file(get_model(gui), filename)
            flag = 0
        catch
            flag = 2
        end
    else
        valid_combinations = Dict(
            "All" => ["jpg", "jpeg", "svg", "xlsx", "png"],
            "Plots" => ["bmp", "tif", "tiff", "jpg", "jpeg", "svg", "xlsx", "png"],
            "Topo" => ["bmp", "tif", "tiff", "jpg", "jpeg", "svg", "png"],
        )
        if !(file_ending ∈ valid_combinations[axes_str])
            @info "Exporting $axes_str to a $file_ending file is not supported"
            return 1
        end
        if axes_str == "All"
            if file_ending == "xlsx"
                flag = export_xlsx(gui, filename)
            else
                try
                    save(filename, get_fig(gui))
                    flag = 0
                catch
                    flag = 2
                end
            end
        else
            if axes_str == "Plots"
                ax_sym = :results
            elseif axes_str == "Topo"
                ax_sym = :topo
            end
            ax = get_ax(gui, ax_sym)
            if file_ending == "svg"
                if axes_str == "Plots"
                    flag = export_svg(ax, filename; legend = get_results_legend(gui))
                elseif axes_str == "Topo"
                    flag = export_svg(ax, filename; legend = get_topo_legend(gui))
                else
                    flag = export_svg(ax, filename)
                end
            elseif file_ending == "xlsx"
                if axes_str == "Plots"
                    time_axis = get_menu(gui, :time).selection[]
                    plots = get_visible_data(gui, time_axis)
                    flag = export_xlsx(plots, filename, ax_sym)
                end
            elseif file_ending == "lp" || file_ending == "mps"
                try
                    write_to_file(get_model(gui), filename)
                    flag = 0
                catch
                    flag = 2
                end
            else
                try
                    save(filename, colorbuffer(ax.scene))
                    flag = 0
                catch
                    flag = 2
                end
            end
        end
    end
    if cairo_makie_activated
        GLMakie.activate!() # Return to GLMakie as a backend
    end
    if flag == 0
        @info "Exported results to $filename"
    elseif flag == 2
        @info "An error occurred, no file exported"
    end
    return flag
end

"""
    export_to_repl(gui::GUI)

Export results based on the state of `gui` to the REPL.
"""
function export_to_repl(gui::GUI)
    axes_str::String = get_menu(gui, :axes).selection[]
    if axes_str == "Plots"
        time_axis = get_menu(gui, :time).selection[]
        vis_plots = get_visible_data(gui, time_axis)
        if !isempty(vis_plots) # Check if any plots exist
            t = vis_plots[1][:t]
            data = Matrix{Any}(undef, length(t), length(vis_plots) + 1)
            data[:, 1] = t
            header = [
                Vector{String}(undef, length(vis_plots) + 1),
                Vector{String}(undef, length(vis_plots) + 1),
            ]
            header[1][1] = "t"
            header[2][1] = "(" * string(nameof(eltype(t))) * ")"
            for (j, vis_plot) ∈ enumerate(vis_plots)
                data[:, j+1]   = vis_plot[:y]
                header[1][j+1] = vis_plots[j][:name]
                header[2][j+1] = join([string(x) for x ∈ vis_plots[j][:selection]], ", ")
            end
            println("\n")  # done in order to avoid the prompt shifting the topspline of the table
            pretty_table(data; column_labels = header)
        end
    else
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
            pretty_table(
                JuMP.Containers.rowtable(value, container; header = header),
            )
        end
    end
    return 0
end
