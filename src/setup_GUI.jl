"""
    GUI(case::Case; kwargs...)

Initialize the EnergyModelsGUI window and visualize the topology of a system `case` \
(and optionally visualize its results in a JuMP object model). The input argument can either
be a `Case` object from the EnergyModelsBase package or a dictionary containing system-related
data stored as key-value pairs. This dictionary is corresponding to the the old EnergyModelsX
`case` dictionary.

# Keyword arguments:

- **`design_path::String=""`** is a file path or identifier related to the design.
- **`id_to_color_map::Dict=Dict()`** is a dict that maps `Resource`s `id` to colors.
- **`id_to_icon_map::Dict=Dict()`** is a dict that maps `Node/Area` `id` to .png files for icons.
- **`model::JuMP.Model=JuMP.Model()`** is the solved JuMP model with results for the `case`.
- **`hide_topo_ax_decorations::Bool=true`** is a visibility toggle of ticks, ticklabels and
  grids for the topology axis.
- **`expand_all::Bool=false`** is the default option for toggling visibility of all nodes
  in all areas.
- **`periods_labels::Vector=[]`** are descriptive labels for strategic periods.
- **`representative_periods_labels::Vector=[]`** are descriptive labels for the
  representative periods.
- **`scenarios_labels::Vector=[]`** are descriptive labels for scenarios.
- **`path_to_results::String=""`** is the path to where exported files are stored.
- **`path_to_descriptive_names::String=""`** is the Path to a .yml file where variables
  are described.
- **`descriptive_names_dict::Dict=Dict()`** is a dictionary where variables are described.
- **`coarse_coast_lines::Bool=true`** is a toggle for coarse or fine resolution coastlines.
- **`backgroundcolor=GLMakie.RGBf(0.99, 0.99, 0.99)`** is the background color of the
  main window.
- **`fontsize::Int64=12`** is the general fontsize.
- **`plot_widths::Tuple{Int64,Int64}=(1920, 1080)`** is the resolution of the window.
- **`scale_tot_opex::Bool=false`** multiplies total OPEX quantities with the duration of the strategic period.
- **`scale_tot_capex::Bool=false`** divides total CAPEX quantities with the duration of the strategic period.
- **`colormap::Vector=Makie.wong_colors()`** is the colormap used for plotting results.
- **`tol::Float64=1e-12`** the tolerance for numbers close to machine epsilon precision.
"""
function GUI(
    case::Case;
    design_path::String = "",
    id_to_color_map::Dict = Dict(),
    id_to_icon_map::Dict = Dict(),
    model::JuMP.Model = JuMP.Model(),
    hide_topo_ax_decorations::Bool = true,
    expand_all::Bool = false,
    periods_labels::Vector = [],
    representative_periods_labels::Vector = [],
    scenarios_labels::Vector = [],
    path_to_results::String = "",
    path_to_descriptive_names::String = "",
    descriptive_names_dict::Dict = Dict(),
    coarse_coast_lines::Bool = true,
    backgroundcolor = GLMakie.RGBf(0.99, 0.99, 0.99),
    fontsize::Int64 = 12,
    plot_widths::Tuple{Int64,Int64} = (1920, 1080),
    case_name::String = "",
    scale_tot_opex::Bool = false,
    scale_tot_capex::Bool = false,
    colormap::Vector = Makie.wong_colors(),
    tol::Float64 = 1e-8,
)
    # Generate the system topology:
    @info raw"Setting up the topology design structure"
    root_design::EnergySystemDesign = EnergySystemDesign(
        case; design_path, id_to_color_map, id_to_icon_map,
    )

    @info raw"Setting up the GUI"
    design::EnergySystemDesign = root_design # variable to store current system (inkluding sub systems)

    # Set variables
    vars::Dict{Symbol,Any} = Dict(
        :title => Observable("top_level"),
        :Δh => 0.05,                # Sidelength of main box
        :coarse_coast_lines => coarse_coast_lines,
        :Δh_px => 50,               # Pixel size of a box for nodes
        :markersize => 15,          # Marker size for arrows in connections
        :boundary_add => 0.2,       # Relative to the xlim/ylim-dimensions, expand the axis
        :line_sep_px => 2,          # Separation (in px) between lines for connections
        :connection_linewidth => 2, # line width of connection lines
        :ax_aspect_ratio => 1.0,    # Aspect ratio for the topology plotting area
        :fontsize => fontsize,      # General font size (in px)
        :linewidth => 1.2,          # Width of the line around boxes
        :parent_scaling => 1.1,     # Scale for enlargement of boxes around main boxes for nodes for parent systems
        :icon_scale => 0.9,         # scale icons w.r.t. the surrounding box in fraction of Δh
        :two_way_sep_px => 10,      # No pixels between set of lines for nodes having connections both ways
        :selection_color => :green2, # Colors for box boundaries when selection objects
        :investment_lineStyle => Linestyle([1.0, 1.5, 2.0, 2.5] .* 5), # linestyle for investment connections and box boundaries for nodes
        :path_to_results => path_to_results, # Path to the location where axes[:results] can be exported
        :plotted_data => [],
        :periods_labels => periods_labels,
        :representative_periods_labels => representative_periods_labels,
        :scenarios_labels => scenarios_labels,
        :backgroundcolor => backgroundcolor,
        :scale_tot_opex => scale_tot_opex,
        :scale_tot_capex => scale_tot_capex,
        :colormap => colormap,
        :tol => tol,
        :autolimits => Dict(
            :results_op => true,
            :results_sc => true,
            :results_rp => true,
            :results_sp => true,
        ),       # Automatically adjust limits of the axis
        :finallimits => Dict(
            :results_op => GLMakie.HyperRectangle(Vec2f(0, 0), Vec2f(1, 1)),
            :results_sc => GLMakie.HyperRectangle(Vec2f(0, 0), Vec2f(1, 1)),
            :results_rp => GLMakie.HyperRectangle(Vec2f(0, 0), Vec2f(1, 1)),
            :results_sp => GLMakie.HyperRectangle(Vec2f(0, 0), Vec2f(1, 1)),
        ),
    )

    # gobal variables for legends
    vars[:color_box_padding_px] = 25               # Padding around the legends
    vars[:color_boxes_width_px] = 20               # Width of the rectangles for the colors in legends
    vars[:color_boxes_height_px] = vars[:fontsize] # Height of the rectangles for the colors in legends
    vars[:color_boxes_sep_px] = 5                  # Separation between rectangles
    vars[:box_text_sep_px] = 5                     # Separation between rectangles for colors and text

    vars[:taskbar_height] = 30
    vars[:descriptive_names] = Dict()
    vars[:path_to_descriptive_names] = path_to_descriptive_names
    vars[:descriptive_names_dict] = descriptive_names_dict

    vars[:plot_widths] = plot_widths
    vars[:hide_topo_ax_decorations] = hide_topo_ax_decorations
    vars[:expand_all] = expand_all

    vars[:xlimits] = Vector{Float64}([0.0, 1.0])
    vars[:ylimits] = Vector{Float64}([0.0, 1.0])

    vars[:topo_title_loc_x] = Observable(0.0)
    vars[:topo_title_loc_y] = Observable(0.0)

    # Create iterables for plotting objects in layers (z-direction) such that nodes are
    # neatly placed on top of each other and lines are beneath nodes
    vars[:z_translate_lines] = 1000
    vars[:z_translate_components] = 5000

    vars[:selected_systems] = []

    # Default text for the text area
    vars[:default_text] = string(
        "Tips:\n",
        "Keyboard shortcuts:\n",
        "\tctrl+left-click: Select multiple nodes.\n",
        "\tright-click and drag: to pan\n",
        "\tscroll wheel: zoom in or out\n",
        "\tspace: Enter the selected system\n",
        "\tctrl+s: Save\n",
        "\tctrl+r: Reset view\n",
        "\tctrl+w: Close window\n",
        "\tEsc (or MouseButton4): Exit the current system and into the parent system\n",
        "\tholding x while scrolling over plots will zoom in/out in the x-direction.\n",
        "\tholding y while scrolling over plots will zoom in/out in the y-direction.\n\n",
        "Left-clicking a component will put information about this component here.\n\n",
        "Clicking a plot below enables you to pin this plot (hitting the `pin\n\
        current plot` button) for comparison with other plots.\n",
        "Use the `Delete` button to unpin a selected plot.",
    )
    vars[:dragging] = Ref(false)
    vars[:ctrl_is_pressed] = Ref(false)

    # Construct the makie figure and its objects
    fig, buttons, menus, toggles, axes, legends = create_makie_objects(vars, root_design)

    ## Create the main structure for the EnergyModelsGUI
    gui::GUI = GUI(
        fig, axes, legends, buttons, menus, toggles, root_design, design, model, vars,
    )

    # Create complete Dict of descriptive names
    update_descriptive_names!(gui)

    # Pre calculate the available fields for each node
    initialize_available_data!(gui)

    # Plot the topology
    initialize_plot!(gui, root_design)

    # Update limits based on the location of the nodes
    adjust_limits!(gui)

    update!(gui, nothing)

    # Define all event functions in the GUI
    define_event_functions(gui)

    # make sure all graphics is adapted to the spawned figure sizes
    notify(get_toggle(gui, :expand_all).active)

    # Enable inspector (such that hovering objects shows information)
    # Linewidth set to zero as this boundary is slightly laggy on movement
    DataInspector(fig; range = 3, indicator_linewidth = 0)

    # display the figure
    manifest = Pkg.Operations.Context().env.manifest
    version = manifest[findfirst(v -> v.name == "EnergyModelsGUI", manifest)].version
    fig_title = "EnergyModelsGUI v$version"
    if !isempty(case_name)
        fig_title *= ": $case_name"
    end
    display(GLMakie.Screen(title = fig_title), fig)

    return gui
end
function GUI(case::Dict; kwargs...)
    elements = [case[:nodes], case[:links]]
    if haskey(case, :areas)
        push!(elements, case[:areas])
    end
    if haskey(case, :transmission)
        push!(elements, case[:transmission])
    end
    case_new = Case(case[:T], case[:products], elements)
    GUI(case_new; kwargs...)
end

"""
    create_makie_objects(vars::Dict, design::EnergySystemDesign)

Create Makie figure and all its objects (buttons, menus, toggles and axes) for
EnergySystemDesign `design` and the options `vars`.
"""
function create_makie_objects(vars::Dict, design::EnergySystemDesign)
    # Create a figure (the main window)
    GLMakie.activate!() # use GLMakie as backend

    # Set the fontsize for the entire figure (if not otherwise specified, the fontsize will inherit this number)
    GLMakie.set_theme!(; fontsize = vars[:fontsize])

    fig::Figure =
        Figure(; size = vars[:plot_widths], backgroundcolor = vars[:backgroundcolor])

    # Create grid layout structure of the window
    gridlayout_taskbar::GridLayout = fig[1, 1] = GridLayout()
    gridlayout_topology_ax::GridLayout = fig[2:6, 1] = GridLayout()
    gridlayout_info::GridLayout = fig[1:2, 2] = GridLayout()
    gridlayout_summary::GridLayout = fig[1:2, 3] = GridLayout()
    gridlayout_results_taskbar1::GridLayout = fig[3, 2:3] = GridLayout()
    gridlayout_results_taskbar2::GridLayout = fig[4, 2:3] = GridLayout()
    gridlayout_results_ax::GridLayout = fig[5, 2:3] = GridLayout()
    gridlayout_results_taskbar3::GridLayout = fig[6, 2:3] = GridLayout()

    # Set row sizes of the layout
    # Control the relative height of the gridlayout_results_ax row heights
    rowsize!(fig.layout, 1, Fixed(vars[:taskbar_height]))
    rowsize!(fig.layout, 3, Fixed(vars[:taskbar_height]))
    rowsize!(fig.layout, 4, Fixed(vars[:taskbar_height]))
    rowsize!(fig.layout, 5, Relative(0.6))
    rowsize!(fig.layout, 6, Fixed(vars[:taskbar_height]))

    # Get the current limits of the axis
    colsize!(fig.layout, 1, Relative(0.45))
    colsize!(fig.layout, 2, Relative(0.35))
    vars[:ax_aspect_ratio] =
        vars[:plot_widths][1] / (vars[:plot_widths][2] - vars[:taskbar_height]) / 2

    # Check whether or not to use lat-lon coordinates to construct the axis used for visualizing the topology
    if isa(get_system(design), SystemGeo)
        # Set the source mapping for projection
        source::String = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        # Set the destination mapping for projection
        dest::String = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        # Construct the axis from the GeoMakie package
        ax = GeoMakie.GeoAxis(
            gridlayout_topology_ax[1, 1];
            source,
            dest,
            alignmode = Outside(),
        )

        if vars[:coarse_coast_lines] # Use low resolution coast lines
            countries = GeoMakie.land()
        else # Use high resolution coast lines
            # Define the URL and the local file path
            resolution::String = "10m" # "10m", "50m", "110m"
            url::String = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_$(resolution)_land.geojson"
            temp_dir::String = tempdir()  # Get the system's temporary directory
            filename_countries::String = "EnergyModelsGUI_countries.geojson"
            local_file_path::String = joinpath(temp_dir, filename_countries)

            # Download the file if it doesn't exist in the temporary directory
            if !isfile(local_file_path)
                @debug "Trying to download file $url to $local_file_path"
                HTTP.download(url, local_file_path)
            end

            # Now read the data from the file
            countries_geo_json = GeoJSON.read(read(local_file_path, String))

            # Create GeoMakie plotable object
            countries = GeoMakie.to_multipoly(countries_geo_json.geometry)
        end
        poly!(
            ax,
            countries;
            color = :honeydew,
            colormap = :dense,
            strokecolor = :gray50,
            strokewidth = 0.5,
            inspectable = false,
        )
        ocean_coords = [(180, -90), (-180, -90), (-180, 90), (180, 90)]
        ocean = poly!(
            ax,
            ocean_coords,
            color = :lightblue1,
            strokewidth = 0.5,
            strokecolor = :gray50,
            inspectable = false,
        )
        Makie.translate!(ocean, 0, 0, -1)
    else # The design does not use the EnergyModelsGeography package: Create a simple Makie axis
        ax = Axis(
            gridlayout_topology_ax[1, 1];
            autolimitaspect = true,
            alignmode = Outside(),
            tellheight = true,
            tellwidth = true,
        )
    end
    if vars[:hide_topo_ax_decorations]
        hidedecorations!(ax)
    end

    # Create axis for visualizating results
    ax_results::Axis = Axis(
        gridlayout_results_ax[1, 1];
        alignmode = Outside(),
        tellheight = false,
        tellwidth = false,
        backgroundcolor = vars[:backgroundcolor],
    )

    # Collect all strategic periods
    T = get_time_struct(design)
    periods::Vector{Int64} = 1:(T.len)

    # Initialize representative_periods to be the representative_period of the first strategic period
    representative_periods::Vector{Int64} = get_representative_period_indices(T, 1)

    # Initialize scenarios to be the scenario of the first strategic period
    scenarios::Vector{Int64} = get_scenario_indices(T, 1, 1)

    # Use the index number for time period labels if not provided
    if isempty(vars[:periods_labels])
        vars[:periods_labels] = string.(periods)
    else # make sure all labels are strings
        vars[:periods_labels] = string.(vars[:periods_labels])
    end
    if isempty(vars[:representative_periods_labels])
        vars[:representative_periods_labels] = string.(representative_periods)
    else # make sure all labels are strings
        vars[:representative_periods_labels] = string.(vars[:representative_periods_labels])
    end
    if isempty(vars[:scenarios_labels])
        vars[:scenarios_labels] = string.(scenarios)
    else # make sure all labels are strings
        vars[:scenarios_labels] = string.(vars[:scenarios_labels])
    end

    # Create legend to explain the available resources in the design model
    markers::Vector{Makie.Scatter} = Vector{Makie.Scatter}(undef, 0)
    for color ∈ collect(values(design.id_to_color_map))
        push!(
            markers,
            scatter!(ax, Point2f((0, 0)); marker = :rect, color = color, visible = false),
        ) # add invisible dummy markers to be put in the legend box
    end
    topo_legend = axislegend(
        ax,
        markers,
        collect(keys(design.id_to_color_map)),
        "Resources";
        position = :rt,
        labelsize = vars[:fontsize],
        titlesize = vars[:fontsize],
    )
    Makie.translate!(topo_legend.blockscene, 0, 0, vars[:z_translate_components] + 999)

    # Initiate an axis for displaying information about the selected node
    ax_info::Makie.Axis = Axis(
        gridlayout_info[1, 1]; backgroundcolor = vars[:backgroundcolor],
    )

    # Add text at the top left of the axis domain (to print information of the selected/hovered node/connection)
    text!(
        ax_info,
        vars[:default_text];
        position = (0.01, 0.99),
        align = (:left, :top),
        fontsize = vars[:fontsize],
    )
    limits!(ax_info, [0, 1], [0, 1])

    # Remove ticks and labels
    hidedecorations!(ax_info)

    # Initiate an axis for displaying summary of the model results
    ax_summary::Makie.Axis = Axis(
        gridlayout_summary[1, 1]; backgroundcolor = vars[:backgroundcolor],
    )

    # Add text at the top left of the axis domain (to print information of the selected/hovered node/connection)
    text!(
        ax_summary,
        "No model results";
        position = (0.01, 0.99),
        align = (:left, :top),
        fontsize = vars[:fontsize],
    )
    limits!(ax_summary, [0, 1], [0, 1])

    # Remove ticks and labels
    hidedecorations!(ax_summary)

    # Add buttons related to the ax object (where the topology is visualized)
    up_button = Makie.Button(
        gridlayout_taskbar[1, 1]; label = "back", fontsize = vars[:fontsize],
    )
    open_button = Makie.Button(
        gridlayout_taskbar[1, 2]; label = "open", fontsize = vars[:fontsize],
    )
    align_horizontal_button = Makie.Button(
        gridlayout_taskbar[1, 3]; label = "align horz.", fontsize = vars[:fontsize],
    )
    align_vertical_button = Makie.Button(
        gridlayout_taskbar[1, 4]; label = "align vert.", fontsize = vars[:fontsize],
    )
    save_button = Makie.Button(
        gridlayout_taskbar[1, 5]; label = "save", fontsize = vars[:fontsize],
    )
    reset_view_button = Makie.Button(
        gridlayout_taskbar[1, 6]; label = "reset view", fontsize = vars[:fontsize],
    )
    Makie.Label(
        gridlayout_taskbar[1, 7],
        "Expand all:";
        halign = :right,
        fontsize = vars[:fontsize],
        justification = :right,
    )
    expand_all_toggle = Makie.Toggle(gridlayout_taskbar[1, 8]; active = vars[:expand_all])

    # Add the following to add flexibility
    Makie.Label(gridlayout_taskbar[1, 9], ""; tellwidth = false)

    # Add buttons related to the ax_results object (where the optimization results are plotted)
    Makie.Label(
        gridlayout_results_taskbar1[1, 1],
        "Plot:";
        halign = :right,
        fontsize = vars[:fontsize],
        justification = :right,
    )
    time_menu = Makie.Menu(
        gridlayout_results_taskbar1[1, 2];
        options = zip(
            ["Strategic", "Representative", "Scenario", "Operational"],
            [:results_sp, :results_rp, :results_sc, :results_op],
        ),
        halign = :left,
        width = 110 * vars[:fontsize] / 12,
        fontsize = vars[:fontsize],
    )
    Makie.Label(
        gridlayout_results_taskbar1[1, 3],
        "Period:";
        halign = :right,
        fontsize = vars[:fontsize],
        justification = :right,
    )
    period_menu = Makie.Menu(
        gridlayout_results_taskbar1[1, 4];
        options = zip(vars[:periods_labels], periods),
        default = vars[:periods_labels][1],
        halign = :left,
        tellwidth = true,
        width = nothing,
        fontsize = vars[:fontsize],
    )
    Makie.Label(
        gridlayout_results_taskbar1[1, 5],
        "Repr. period:";
        halign = :right,
        fontsize = vars[:fontsize],
        justification = :right,
    )
    representative_period_menu = Makie.Menu(
        gridlayout_results_taskbar1[1, 6];
        options = zip(vars[:representative_periods_labels], representative_periods),
        default = vars[:representative_periods_labels][1],
        halign = :left,
        fontsize = vars[:fontsize],
    )
    Makie.Label(
        gridlayout_results_taskbar1[1, 7],
        "Scenario:";
        halign = :left,
        fontsize = vars[:fontsize],
        justification = :left,
    )
    scenario_menu = Makie.Menu(
        gridlayout_results_taskbar1[1, 8];
        options = zip(vars[:scenarios_labels], scenarios),
        default = vars[:scenarios_labels][1],
        halign = :left,
        fontsize = vars[:fontsize],
    )
    Makie.Label(
        gridlayout_results_taskbar2[1, 1],
        "Data:";
        halign = :right,
        fontsize = vars[:fontsize],
        justification = :right,
    )
    available_data_menu = Makie.Menu(
        gridlayout_results_taskbar2[1, 2]; halign = :left, fontsize = vars[:fontsize],
    )

    # Add the following to add flexibility
    Makie.Label(gridlayout_results_taskbar3[1, 1], ""; tellwidth = false)

    reset_view_results_button = Makie.Button(
        gridlayout_results_taskbar3[1, 2]; label = "reset view",
        fontsize = vars[:fontsize],
    )
    pin_plot_button = Makie.Button(
        gridlayout_results_taskbar3[1, 3];
        label = "pin current data",
        fontsize = vars[:fontsize],
    )
    remove_plot_button = Makie.Button(
        gridlayout_results_taskbar3[1, 4];
        label = "remove selected data",
        fontsize = vars[:fontsize],
    )
    clear_all_button = Makie.Button(
        gridlayout_results_taskbar3[1, 5]; label = "clear all",
        fontsize = vars[:fontsize],
    )
    Makie.Label(
        gridlayout_results_taskbar3[1, 6],
        "Export:";
        halign = :right,
        fontsize = vars[:fontsize],
        justification = :right,
    )
    axes_menu = Makie.Menu(
        gridlayout_results_taskbar3[1, 7];
        options = ["All", "Plots", "Topo"],
        default = "Plots",
        halign = :left,
        width = 80 * vars[:fontsize] / 12,
        fontsize = vars[:fontsize],
    )
    export_type_menu = Makie.Menu(
        gridlayout_results_taskbar3[1, 8];
        options = [
            "bmp", "tiff", "tif", "jpg", "jpeg", "lp", "mps", "svg", "xlsx", "png",
            "REPL",
        ],
        default = "REPL",
        halign = :left,
        width = 60 * vars[:fontsize] / 12,
        fontsize = vars[:fontsize],
    )
    export_button = Makie.Button(
        gridlayout_results_taskbar3[1, 9]; label = "export", fontsize = vars[:fontsize],
    )

    # Collect all menus into a dictionary
    buttons::Dict{Symbol,Makie.Button} = Dict(
        :align_horizontal => align_horizontal_button,
        :align_vertical => align_vertical_button,
        :open => open_button,
        :up => up_button,
        :save => save_button,
        :reset_view => reset_view_button,
        :export => export_button,
        :reset_view_results => reset_view_results_button,
        :pin_plot => pin_plot_button,
        :remove_plot => remove_plot_button,
        :clear_all => clear_all_button,
    )

    # Collect all menus into a dictionary
    menus::Dict{Symbol,Makie.Menu} = Dict(
        :period => period_menu,
        :representative_period => representative_period_menu,
        :scenario => scenario_menu,
        :available_data => available_data_menu,
        :time => time_menu,
        :export_type => export_type_menu,
        :axes => axes_menu,
    )

    # Collect all legends into a dictionary
    legends::Dict{Symbol,Union{Makie.Legend,Nothing}} = Dict(
        :results => nothing, :topo => topo_legend,
    )

    # Ensure that menus are on top
    for menu ∈ values(menus)
        translate!(menu.blockscene, 0, 0, vars[:z_translate_components] + 2000)
    end

    # Collect all toggles into a dictionary
    toggles::Dict{Symbol,Makie.Toggle} = Dict(:expand_all => expand_all_toggle)

    # Collect all axes into a dictionary
    axes::Dict{Symbol,Makie.Block} = Dict(
        :topo => ax, :results => ax_results, :info => ax_info, :summary => ax_summary,
    )

    # Update the title of the figure
    vars[:topo_title_obj] = text!(
        ax,
        vars[:topo_title_loc_x],
        vars[:topo_title_loc_y];
        text = vars[:title],
        fontsize = vars[:fontsize],
    )
    Makie.translate!(vars[:topo_title_obj], 0, 0, vars[:z_translate_components] + 999)

    return fig, buttons, menus, toggles, axes, legends
end
