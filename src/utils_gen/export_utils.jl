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
        return svg_string[start_idx:end_idx], svg_string[1:(start_idx - 1)]
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
    export_svg(ax::Makie.Block, filename::String)

Export the `ax` to a .svg file with path given by `filename`.
"""
function export_svg(
    ax::Makie.Block, filename::String; legend::Union{Makie.Legend,Nothing}=nothing
)
    bb = ax.layoutobservables.suggestedbbox[]
    protrusions = ax.layoutobservables.reporteddimensions[].outer

    offset = 0 #ax.spinewidth[] / 2
    axis_bb = Rect2f(
        bb.origin .- (protrusions.left, protrusions.bottom) .- offset,
        bb.widths .+
        (protrusions.left + protrusions.right, protrusions.bottom + protrusions.top) .+
        2 * offset,
    )

    pad = 5

    ws = axis_bb.widths
    o = axis_bb.origin
    width = "$(ws[1] + 2 * pad)pt"
    height = "$(ws[2] + 2 * pad)pt"

    # Temporary hack to fix viewBox for SVG export:
    # Based on the default (1920,1080) resolution, set hack such that
    # [:results]: when ws[2] is 575.80005 then hack should be 202.442, and
    # [:topo]:    when ws[2] is 1001.0    then hack should be 953.000
    # Awaiting solution from issue https://github.com/MakieOrg/Makie.jl/issues/4500
    # pad should arguably also be set to 0 when solution is found
    hack = 202.442 + (ws[2] - 575.80005) * (953.000 - 202.442) / (1001.0 - 575.80005)
    viewBox = "$(o[1] - pad) $(o[2] - hack + ws[2] - pad) $(ws[1] + 2 * pad) $(ws[2] + 2 * pad)"

    svgstring_ax = repr(MIME"image/svg+xml"(), ax.blockscene)
    svgstring_legend =
        isnothing(legend) ? "" : repr(MIME"image/svg+xml"(), legend.blockscene)
    svgstring = merge_svg_strings(svgstring_ax, svgstring_legend)
    svgstring = replace(svgstring, r"""(?<=width=")[^"]*(?=")""" => width; count=1)
    svgstring = replace(svgstring, r"""(?<=height=")[^"]*(?=")""" => height; count=1)
    svgstring = replace(svgstring, r"""(?<=viewBox=")[^"]*(?=")""" => viewBox; count=1)
    open(filename, "w") do io
        print(io, svgstring)
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
    XLSX.openxlsx(filename; mode="w") do xf
        sheet = xf[1] # Access the first sheet

        no_columns = length(plots) + 1
        data = Vector{Any}(undef, no_columns)
        data[1] = string.(plots[1][:t])
        for (i, plot) ∈ enumerate(plots)
            data[i + 1] = plot[:y]
        end
        labels::Vector{String} = [plot[:name] for plot ∈ plots]

        headers::Vector{Any} = vcat(xlabel, labels)

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
    XLSX.openxlsx(filename; mode="w") do xf
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
            data_jump = JuMP.Containers.rowtable(value, container; header=header)
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

Export results based on the state of `gui`.
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
    if file_ending ∈ ["svg"]
        CairoMakie.activate!() # Set CairoMakie as backend for proper export quality
        cairo_makie_activated = true
    else
        cairo_makie_activated = false
    end
    if axes_str == "All"
        filename = joinpath(path, axes_str * "." * file_ending)
        if file_ending ∈ ["bmp", "tiff", "tif", "jpg", "jpeg"]
            @warn "Exporting the entire figure to an $file_ending file is not implemented"
            flag = 1
        elseif file_ending == "xlsx"
            flag = export_xlsx(gui, filename)
        elseif file_ending == "lp" || file_ending == "mps"
            try
                write_to_file(get_model(gui), filename)
                flag = 0
            catch
                flag = 2
            end
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
        filename = joinpath(path, "$ax_sym.$file_ending")
        if file_ending == "svg"
            if axes_str == "Plots"
                flag = export_svg(
                    get_ax(gui, ax_sym), filename; legend=get_results_legend(gui)
                )
            elseif axes_str == "Topo"
                flag = export_svg(
                    get_ax(gui, ax_sym), filename; legend=get_topo_legend(gui)
                )
            else
                flag = export_svg(get_ax(gui, ax_sym), filename)
            end
        elseif file_ending == "xlsx"
            if ax_sym == :topo
                @warn "Exporting the topology to an xlsx file is not implemented"
                flag = 1
            else
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
                save(filename, colorbuffer(get_ax(gui, ax_sym)))
                flag = 0
            catch
                flag = 2
            end
        end
    end
    if cairo_makie_activated
        GLMakie.activate!() # Return to GLMakie as a backend
    end
    if flag == 0
        @info "Exported results to $filename"
    elseif flag == 2
        @info "An error occured, no file exported"
    end
    return flag
end
