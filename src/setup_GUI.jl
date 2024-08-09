"""
    GUI(case::Dict)

Initialize the EnergyModelsGUI window and visualize the topology of a system `case` \
(and optionally visualize its results in a JuMP object model).

# Arguments:

- **`system::case`** is a dictionary containing system-related data stored as key-value pairs.
  This dictionary is corresponding to the the EnergyModelsX `case` dictionary.

# Keyword arguments:

- **`design_path::String=""`** is a file path or identifier related to the design.
- **`id_to_color_map::Dict=Dict()` is a dict that maps `Resource`s `id` to colors.
- **`id_to_icon_map::Dict=Dict()` is a dict that maps `Node/Area` `id` to .png files for icons.
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
- **`path_to_descriptive_names::String=""` is the Path to a .yml file where JuMP variables
  are described.
- **`coarse_coast_lines::Bool=true`** is a toggle for coarse or fine resolution coastlines.
- **`backgroundcolor=GLMakie.RGBf(0.99, 0.99, 0.99)`** is the background color of the
  main window.
- **`fontsize::Int64=12`** is the general fontsize.
- **`plot_widths::Tuple{Int64,Int64}=(1920, 1080)`** is the resolution of the window.
"""
function GUI(
    case::Dict;
    design_path::String="",
    id_to_color_map::Dict=Dict(),
    id_to_icon_map::Dict=Dict(),
    model::JuMP.Model=JuMP.Model(),
    hide_topo_ax_decorations::Bool=true,
    expand_all::Bool=false,
    periods_labels::Vector=[],
    representative_periods_labels::Vector=[],
    scenarios_labels::Vector=[],
    path_to_results::String="",
    path_to_descriptive_names::String="",
    descriptive_names_dict::Dict=Dict(),
    coarse_coast_lines::Bool=true,
    backgroundcolor=GLMakie.RGBf(0.99, 0.99, 0.99),
    fontsize::Int64=12,
    plot_widths::Tuple{Int64,Int64}=(1920, 1080),
)
    # Generate the system topology:
    @info raw"Setting up the topology design structure"
    root_design::EnergySystemDesign = EnergySystemDesign(
        case; design_path, id_to_color_map, id_to_icon_map
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
        :results_legend => [], # Legend for the results
        :pinned_data => Dict( # Arrays of pinned plots (stores Dicts with keys :label and :plot)
            :results_sp => [],
            :results_rp => [],
            :results_op => [],
        ),
        :visible_data => Dict( # Arrays of pinned plots (stores Dicts with keys :label and :plot)
            :results_sp => [],
            :results_rp => [],
            :results_op => [],
        ),
        :available_data => Dict{Any,Any}(),
        :periods_labels => periods_labels,
        :representative_periods_labels => representative_periods_labels,
        :scenarios_labels => scenarios_labels,
        :backgroundcolor => backgroundcolor,
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
    vars[:selected_plots] = []

    # Default text for the text area
    vars[:default_text] = string(
        "Tips:\n",
        "Keyboard shortcuts:\n",
        "\tctrl+left-click: Select multiple nodes (use arrows to move all selected nodes simultaneously).\n",
        "\tright-click and drag: to pan\n",
        "\tscroll wheel: zoom in or out\n",
        "\tspace: Enter the selected system\n",
        "\tctrl+s: Save\n",
        "\tctrl+r: Reset view\n",
        "\tctrl+w: Close window\n",
        "\tEsc (or MouseButton4): Exit the current system and into the parent system\n\n",
        "Left-clicking a component will put information about this component here\n\n",
        "Clicking a plot below enables you to pin this plot (hitting the `pin current plot` button) \
            for comparison with other plots. Use the `Delete` button to unpin a selected plot",
    )
    vars[:dragging] = Ref(false)
    vars[:ctrl_is_pressed] = Ref(false)

    # Construct the makie figure and its objects
    fig, buttons, menus, toggles, axes = create_makie_objects(vars, root_design)

    ## Create the main structure for the EnergyModelsGUI
    gui::GUI = GUI(fig, axes, buttons, menus, toggles, root_design, design, model, vars)

    # Create complete Dict of descriptive names
    update_descriptive_names!(gui)

    # Plot the topology
    initialize_plot!(gui, root_design)

    # Pre calculate the available fields for each node
    initialize_available_data!(gui)

    # Update limits based on the location of the nodes
    adjust_limits!(gui)

    update!(gui, nothing)

    # Define all event functions in the GUI
    define_event_functions(gui)

    # make sure all graphics is adapted to the spawned figure sizes
    notify(get_toggle(gui, :expand_all).active)

    # Enable inspector (such that hovering objects shows information)
    # Linewidth set to zero as this boundary is slightly laggy on movement
    DataInspector(fig; range=10, indicator_linewidth=0)

    # display the figure
    version = get_project_version(joinpath(@__DIR__, "..", "Project.toml"))
    display(GLMakie.Screen(title="EnergyModelsGUI v$version"), fig)

    return gui
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
    GLMakie.set_theme!(; fontsize=vars[:fontsize])

    fig::Figure = Figure(; size=vars[:plot_widths], backgroundcolor=vars[:backgroundcolor])

    # Create grid layout structure of the window
    gridlayout_taskbar::GridLayout = fig[1, 1:2] = GridLayout()
    gridlayout_topology_ax::GridLayout = fig[2:4, 1] = GridLayout(; valign=:top)
    gridlayout_info::GridLayout = fig[2, 2] = GridLayout()
    gridlayout_results_ax::GridLayout = fig[3, 2] = GridLayout()
    gridlayout_results_taskbar::GridLayout = fig[4, 2] = GridLayout()

    # Set row sizes of the layout
    # Control the relative height of the gridlayout_results_ax (ax for plotting results)
    rowsize!(fig.layout, 1, Fixed(vars[:taskbar_height]))
    # Control the relative height of the gridlayout_results_ax (ax for plotting results)
    rowsize!(fig.layout, 3, Relative(0.55))

    # Get the current limits of the axis
    colsize!(fig.layout, 2, Auto(1))
    vars[:ax_aspect_ratio] =
        vars[:plot_widths][1] / (vars[:plot_widths][2] - vars[:taskbar_height]) / 2

    # Check whether or not to use lat-lon coordinates to construct the axis used for visualizing the topology
    if haskey(get_system(design), :areas) # The design uses the EnergyModelsGeography package: Thus use GeoMakie
        # Set the source mapping for projection
        source::String = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        # Set the destination mapping for projection
        dest::String = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        # Construct the axis from the GeoMakie package
        ax = GeoMakie.GeoAxis(
            gridlayout_topology_ax[1, 1];
            source=source,
            dest=dest,
            aspect=DataAspect(),
            alignmode=Outside(),
        )

        if vars[:coarse_coast_lines] # Use low resolution coast lines
            countries = GeoMakie.land()
        else # Use high resolution coast lines
            # Define the URL and the local file path
            resolution = "10m" # "10m", "50m", "110m"
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
            color=:honeydew,
            colormap=:dense,
            strokecolor=:gray50,
            strokewidth=0.5,
            inspectable=false,
        )
    else # The design does not use the EnergyModelsGeography package: Create a simple Makie axis
        ax = Axis(gridlayout_topology_ax[1, 1]; aspect=DataAspect(), alignmode=Outside())
    end
    if vars[:hide_topo_ax_decorations]
        hidedecorations!(ax)
    end

    # Create axis for visualizating results
    ax_results_sp::Axis = Axis(
        gridlayout_results_ax[1, 1];
        alignmode=Outside(),
        tellheight=false,
        tellwidth=false,
        backgroundcolor=vars[:backgroundcolor],
    )
    ax_results_rp::Axis = Axis(
        gridlayout_results_ax[1, 1];
        alignmode=Outside(),
        tellheight=false,
        tellwidth=false,
        backgroundcolor=vars[:backgroundcolor],
    )
    ax_results_op::Axis = Axis(
        gridlayout_results_ax[1, 1];
        alignmode=Outside(),
        tellheight=false,
        tellwidth=false,
        backgroundcolor=vars[:backgroundcolor],
    )
    hidedecorations!(ax_results_rp)
    hidedecorations!(ax_results_op)
    hidespines!(ax_results_rp)
    hidespines!(ax_results_op)

    # Collect all strategic periods
    T = design.system[:T]
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
            markers, scatter!(ax, Point2f((0, 0)); marker=:rect, color=color, visible=false)
        ) # add invisible dummy markers to be put in the legend box
    end
    vars[:topo_legend] = axislegend(
        ax,
        markers,
        collect(keys(design.id_to_color_map)),
        "Resources";
        position=:rt,
        labelsize=vars[:fontsize],
        titlesize=vars[:fontsize],
    )

    # Initiate an axis for displaying information about the selected node
    ax_info::Makie.Axis = Axis(
        gridlayout_info[1, 1]; backgroundcolor=vars[:backgroundcolor]
    )

    # Add text at the top left of the axis domain (to print information of the selected/hovered node/connection)
    text!(
        ax_info,
        vars[:default_text];
        position=(0.01, 0.99),
        align=(:left, :top),
        fontsize=vars[:fontsize],
    )
    limits!(ax_info, [0, 1], [0, 1])

    # Remove ticks and labels
    hidedecorations!(ax_info)

    # Add buttons related to the ax object (where the topology is visualized)
    up_button = Makie.Button(
        gridlayout_taskbar[1, 1]; label="back", fontsize=vars[:fontsize]
    )
    open_button = Makie.Button(
        gridlayout_taskbar[1, 2]; label="open", fontsize=vars[:fontsize]
    )
    align_horizontal_button = Makie.Button(
        gridlayout_taskbar[1, 3]; label="align horz.", fontsize=vars[:fontsize]
    )
    align_vertical_button = Makie.Button(
        gridlayout_taskbar[1, 4]; label="align vert.", fontsize=vars[:fontsize]
    )
    save_button = Makie.Button(
        gridlayout_taskbar[1, 5]; label="save", fontsize=vars[:fontsize]
    )
    reset_view_button = Makie.Button(
        gridlayout_taskbar[1, 6]; label="reset view", fontsize=vars[:fontsize]
    )
    Makie.Label(
        gridlayout_taskbar[1, 7],
        "Expand all:";
        halign=:right,
        fontsize=vars[:fontsize],
        justification=:right,
    )
    expand_all_toggle = Makie.Toggle(gridlayout_taskbar[1, 8]; active=vars[:expand_all])

    # Add buttons related to the ax_results object (where the optimization results are plotted)
    Makie.Label(
        gridlayout_taskbar[1, 9],
        "Period:";
        halign=:right,
        fontsize=vars[:fontsize],
        justification=:right,
    )
    period_menu = Makie.Menu(
        gridlayout_taskbar[1, 10];
        options=zip(vars[:periods_labels], periods),
        default=vars[:periods_labels][1],
        halign=:left,
        width=100 * vars[:fontsize] / 12,
        fontsize=vars[:fontsize],
    )
    Makie.Label(
        gridlayout_taskbar[1, 11],
        "Representative period:";
        halign=:right,
        fontsize=vars[:fontsize],
        justification=:right,
    )
    representative_period_menu = Makie.Menu(
        gridlayout_taskbar[1, 12];
        options=zip(vars[:representative_periods_labels], representative_periods),
        default=vars[:representative_periods_labels][1],
        halign=:left,
        width=100 * vars[:fontsize] / 12,
        fontsize=vars[:fontsize],
    )
    Makie.Label(
        gridlayout_taskbar[1, 13],
        "Scenario:";
        halign=:left,
        fontsize=vars[:fontsize],
        justification=:left,
    )
    scenario_menu = Makie.Menu(
        gridlayout_taskbar[1, 14];
        options=zip(vars[:scenarios_labels], scenarios),
        default=vars[:scenarios_labels][1],
        halign=:left,
        width=100 * vars[:fontsize] / 12,
        fontsize=vars[:fontsize],
    )
    Makie.Label(
        gridlayout_taskbar[1, 15],
        "Data:";
        halign=:right,
        fontsize=vars[:fontsize],
        justification=:right,
    )
    available_data_menu = Makie.Menu(
        gridlayout_taskbar[1, 16]; halign=:left, fontsize=vars[:fontsize], tellwidth=true
    )

    # Add the following to add flexibility
    Makie.Label(gridlayout_results_taskbar[1, 1], ""; tellwidth=false)

    # Add task bar over axes[:results]
    Makie.Label(
        gridlayout_results_taskbar[1, 2],
        "Plot:";
        halign=:right,
        fontsize=vars[:fontsize],
        justification=:right,
    )
    time_menu = Makie.Menu(
        gridlayout_results_taskbar[1, 3];
        options=zip(
            ["Strategic", "Representative", "Operational"],
            [:results_sp, :results_rp, :results_op],
        ),
        halign=:left,
        width=120 * vars[:fontsize] / 12,
        fontsize=vars[:fontsize],
    )
    pin_plot_button = Makie.Button(
        gridlayout_results_taskbar[1, 4]; label="pin current data", fontsize=vars[:fontsize]
    )
    remove_plot_button = Makie.Button(
        gridlayout_results_taskbar[1, 5];
        label="remove selected data",
        fontsize=vars[:fontsize],
    )
    clear_all_button = Makie.Button(
        gridlayout_results_taskbar[1, 6]; label="clear all", fontsize=vars[:fontsize]
    )
    Makie.Label(
        gridlayout_results_taskbar[1, 7],
        "Export:";
        halign=:right,
        fontsize=vars[:fontsize],
        justification=:right,
    )
    axes_menu = Makie.Menu(
        gridlayout_results_taskbar[1, 8];
        options=["All", "Plots"],
        default="Plots",
        halign=:left,
        width=80 * vars[:fontsize] / 12,
        fontsize=vars[:fontsize],
    )
    export_type_menu = Makie.Menu(
        gridlayout_results_taskbar[1, 9];
        options=[
            "bmp", "tiff", "tif", "jpg", "jpeg", "lp", "mps", "svg", "xlsx", "png", "REPL"
        ],
        default="REPL",
        halign=:left,
        width=60 * vars[:fontsize] / 12,
        fontsize=vars[:fontsize],
    )
    export_button = Makie.Button(
        gridlayout_results_taskbar[1, 10]; label="export", fontsize=vars[:fontsize]
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

    # Collect all toggles into a dictionary
    toggles::Dict{Symbol,Makie.Toggle} = Dict(:expand_all => expand_all_toggle)

    # Collect all axes into a dictionary
    axes::Dict{Symbol,Makie.Block} = Dict(
        :topo => ax,
        :results_sp => ax_results_sp,
        :results_rp => ax_results_rp,
        :results_op => ax_results_op,
        :info => ax_info,
    )

    # Update the title of the figure
    vars[:topo_tile_obj] = text!(
        ax,
        vars[:topo_title_loc_x],
        vars[:topo_title_loc_y];
        text=vars[:title],
        fontsize=vars[:fontsize],
    )

    return fig, buttons, menus, toggles, axes
end
