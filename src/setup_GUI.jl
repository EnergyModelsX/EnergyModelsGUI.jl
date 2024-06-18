"""
    GUI(case::Dict)

Initialize the EnergyModelsGUI window and visualize the topology of a system `case` \
(and optionally visualize its results in a JuMP object model).

# Arguments:

- **`system::case`** is a dictionary containing system-related data stored as key-value pairs.
  This dictionary is corresponding to the the EnergyModelsX `case` dictionary.

# Keyword arguments:

- **`design_path::String=""`** is a file path or identifier related to the design
- **`id_to_color_map::Dict=Dict()` is a dict that maps `Resource`s `id` to colors.
- **`id_to_icon_map::Dict=Dict()` is a dict that maps `Node/Area` `id` to .png files for icons.
- **`model::JuMP.Model=JuMP.Model()`** is the solved JuMP model with results for the `case`.
- **`hide_topo_ax_decorations::Bool=true`** is a visibility toggle of ticks, ticklabels and
  grids for the topology axis.
- **`expand_all::Bool=false`** is the default option for toggling visibility of all nodes
  in all areas
- **`periods_labels::Vector=[]`** are descriptive labels for strategic periods.
- **`representative_periods_labels::Vector=[]`** are descriptive labels for the
  representative periods.
- **`scenarios_labels::Vector=[]`** are descriptive labels for scenarios.
- **`path_to_results::String=""`** is the path to where exported files are stored.
- **`path_to_descriptive_names::String=""` is the Path to a .yml file where JuMP variables
  are described
- **`coarse_coast_lines::Bool=true`** is a toggle for coarse or fine resolution coastlines.
- **`backgroundcolor=GLMakie.RGBf(0.99, 0.99, 0.99)`** is the background color of the
  main window
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

    if isempty(path_to_descriptive_names)
        path_to_descriptive_names = joinpath(@__DIR__, "descriptive_names.yml")
    end

    # Set variables
    vars::Dict{Symbol,Any} = Dict(
        :title => Observable(""),
        :Δh => Observable(0.05), # Sidelength of main box
        :coarse_coast_lines => coarse_coast_lines,
        :Δh_px => 50,              # Pixel size of a box for nodes
        :markersize => 15,         # Marker size for arrows in connections
        :boundary_add => 0.2,     # Relative to the xlim/ylim-dimensions, expand the axis
        :line_sep_px => 2,         # Separation (in px) between lines for connections
        :connection_linewidth => 2, # line width of connection lines
        :ax_aspect_ratio => 1.0,     # Aspect ratio for the topology plotting area
        :fontsize => fontsize,           # General font size (in px)
        :linewidth => 1.2,         # Width of the line around boxes
        :parent_scaling => 1.1,     # Scale for enlargement of boxes around main boxes for nodes for parent systems
        :icon_scale => 0.9,        # scale icons w.r.t. the surrounding box in fraction of Δh
        :two_way_sep_px => Observable(10), # No pixels between set of lines for nodes having connections both ways
        :selection_color => :green2, # Colors for box boundaries when selection objects
        :investment_lineStyle => Linestyle([1.0, 1.5, 2.0, 2.5] .* 5), # linestyle for investment connections and box boundaries for nodes
        :path_to_results => path_to_results, # Path to the location where axes[:results] can be exported
        :results_legend => [],         # Legend for the results
        :pinned_plots => Dict(         # Arrays of pinned plots (stores Dicts with keys :label and :plot)
            :results_sp => [],
            :results_rp => [],
            :results_op => [],
        ),
        :visible_plots => Dict(         # Arrays of pinned plots (stores Dicts with keys :label and :plot)
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
    vars[:descriptive_names] = YAML.load_file(
        path_to_descriptive_names; dicttype=Dict{Symbol,Any}
    )

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
    vars[:is_ctrl_pressed] = Ref(false)
    vars[:axis_time_types_labels] = ["Strategic", "Representative", "Operational"]
    vars[:axis_time_types] = [:results_sp, :results_rp, :results_op]

    # Construct the makie figure and its objects
    fig, buttons, menus, toggles, axes = create_makie_objects(vars, root_design)

    ## Create the main structure for the EnergyModelsGUI
    gui::GUI = GUI(fig, axes, buttons, menus, toggles, root_design, design, model, vars)

    # Update the title of the figure
    gui.vars[:topo_tile_obj] = text!(
        gui.axes[:topo],
        gui.vars[:topo_title_loc_x],
        gui.vars[:topo_title_loc_y];
        text=gui.vars[:title],
        fontsize=gui.vars[:fontsize],
    )
    update_title!(gui)

    # Plot the topology
    initialize_plot!(gui, gui.root_design)

    # Pre calculate the available fields for each node
    initialize_available_data!(gui)

    # Update limits based on the location of the nodes
    adjust_limits!(gui)

    update!(gui, nothing)

    # Define all event functions in the GUI
    define_event_functions(gui)

    # make sure all graphics is adapted to the spawned figure sizes
    notify(gui.toggles[:expand_all].active)
    #notify(pixelarea(gui.axes[:topo].scene))
    #update_distances!(gui)

    # Enable inspector (such that hovering objects shows information)
    # Linewidth set to zero as this boundary is slightly laggy on movement
    DataInspector(gui.fig; range=10, indicator_linewidth=0, enable_indicator=false)

    # display the figure
    display(gui.fig)

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
    GLMakie.set_theme!(; fontsize=Float32(vars[:fontsize]))

    fig::Figure = Figure(;
        resolution=vars[:plot_widths], backgroundcolor=vars[:backgroundcolor]
    )

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
    if haskey(design.system, :areas) # The design uses the EnergyModelsGeography package: Thus use GeoMakie
        # Set the source mapping for projection
        source::String = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        # Set the destination mapping for projection
        dest::String = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        # Construct the axis from the GeoMakie package
        ax = GeoMakie.GeoAxis(
            gridlayout_topology_ax[1, 1];
            source=source,
            dest=dest,
            backgroundcolor=:lightblue1,
            aspect=DataAspect(),
            alignmode=Outside(),
        )

        if vars[:coarse_coast_lines] # Use low resolution coast lines
            land = GeoMakie.land()
            coastlns = poly!(
                ax,
                land;
                color=:honeydew,
                colormap=:dense,
                strokecolor=:gray50,
                strokewidth=0.5,
                inspectable=false,
            )
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
            countries::GeoJSON.FeatureCollection{2,Float32} = GeoJSON.read(
                read(local_file_path, String)
            )
            coastlns = poly!(
                ax,
                countries;
                color=:honeydew,
                colormap=:dense,
                strokecolor=:gray50,
                strokewidth=0.5,
                inspectable=false,
            )
        end
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
        options=zip(vars[:axis_time_types_labels], vars[:axis_time_types]),
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
    return fig, buttons, menus, toggles, axes
end

"""
    define_event_functions(gui::GUI)

Define event functions (handling button clicks, plot updates, etc.) for the GUI `gui`.
"""
function define_event_functions(gui::GUI)
    # Create a function that notifies all components (and thus updates graphics
    # when the observables are notified)
    notify_components = () -> begin
        for component ∈ gui.root_design.components
            notify(component.xy)
            if !isempty(component.components)
                for sub_component ∈ component.components
                    notify(sub_component.xy)
                end
            end
        end
    end

    # On zooming, make sure all graphics are adjusted acordingly
    on(gui.axes[:topo].finallimits; priority=10) do finallimits
        @debug "Changes in finallimits"
        widths::Vec{2,Float32} = finallimits.widths
        origin::Vec{2,Float32} = finallimits.origin
        gui.vars[:xlimits] = [origin[1], origin[1] + widths[1]]
        gui.vars[:ylimits] = [origin[2], origin[2] + widths[2]]
        update_distances!(gui)
        notify_components()
        gui.vars[:topo_title_loc_x][] = origin[1] + widths[1] / 100
        gui.vars[:topo_title_loc_y][] =
            origin[2] + widths[2] - widths[2] / 100 -
            pixel_to_data(gui, gui.vars[:fontsize])[2]
        return Consume(false)
    end

    # If the window is resized, make sure all graphics are adjusted acordingly
    on(gui.fig.scene.events.window_area; priority=3) do val
        @debug "Changes in window_area"
        gui.vars[:plot_widths] = Tuple(gui.fig.scene.px_area.val.widths)
        gui.vars[:ax_aspect_ratio] =
            gui.vars[:plot_widths][1] /
            (gui.vars[:plot_widths][2] - gui.vars[:taskbar_height]) / 2
        notify(gui.axes[:topo].finallimits)
        return Consume(false)
    end

    # Handle case when user is pressing/releasing any ctrl key (in order to select multiple components)
    on(events(gui.axes[:topo].scene).keyboardbutton; priority=3) do event
        # For more integers: using GLMakie; typeof(events(gui.axes[:topo].scene).keyboardbutton[].key)

        is_ctrl(key::Makie.Keyboard.Button) = Int(key) == 341 || Int(key) == 345 # any of the ctrl buttons is clicked
        if event.action == Keyboard.press
            if is_ctrl(event.key)
                # Register if any ctrl-key has been pressed
                gui.vars[:is_ctrl_pressed][] = true
            elseif Int(event.key) ∈ [262, 263, 264, 265] # arrow right, arrow left, arrow down or arrow up
                # move a component(s) using the arrow keys

                # get changes
                change::Tuple{Float64,Float64} = get_change(gui, Val(event.key))

                # check if any changes where made
                if change != (0.0, 0.0)
                    for sub_design ∈ gui.vars[:selected_systems]
                        xc::Real = sub_design.xy[][1]
                        yc::Real = sub_design.xy[][2]

                        sub_design.xy[] = (xc + change[1], yc + change[2])

                        update_sub_system_locations!(sub_design, Tuple(change))
                    end

                    notify_components()
                end
            elseif Int(event.key) == 256 # Esc used to move up a level in the topology
                notify(gui.buttons[:up].clicks)
            elseif Int(event.key) == 32 # Space used to open up a sub-system
                notify(gui.buttons[:open].clicks)
            elseif Int(event.key) == 261 # Delete used to delete selected plot
                notify(gui.buttons[:remove_plot].clicks)
            elseif Int(event.key) == 82 # ctrl+r: Reset view
                if gui.vars[:is_ctrl_pressed][]
                    notify(gui.buttons[:reset_view].clicks)
                end
            elseif Int(event.key) == 83 # ctrl+s: Save
                if gui.vars[:is_ctrl_pressed][]
                    notify(gui.buttons[:save].clicks)
                end
            elseif Int(event.key) == 87 # ctrl+w: Close
                if gui.vars[:is_ctrl_pressed][]
                    Threads.@spawn GLMakie.closeall()
                end
                #elseif Int(event.key) == 340 # Shift
                #elseif Int(event.key) == 342 # Alt
            end
        elseif event.action == Keyboard.release
            if is_ctrl(event.key)
                # Register if any ctrl-key has been released
                gui.vars[:is_ctrl_pressed][] = false
            end
        end
        return Consume(true)
    end

    last_click_time = Ref(Dates.now())

    # Define the double-click threshold
    double_click_threshold = Dates.Millisecond(500) # Default value in Windows

    # Handle cases for mousebutton input
    on(events(gui.axes[:topo]).mousebutton; priority=4) do event
        if event.button == Mouse.left
            current_click_time = Dates.now()
            time_difference = current_click_time - last_click_time[]
            if event.action == Mouse.press
                # Make sure selections are not removed when left-clicking outside axes[:topo]
                mouse_pos::Tuple{Float64,Float64} = events(gui.axes[:topo]).mouseposition[]

                origin::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].origin
                widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
                mouse_pos_loc::Vec2{Float64} = mouse_pos .- origin

                # Check if mouseclick is outside the gui.axes[:topo] area (and return if so)
                if all(mouse_pos_loc .> 0.0) && all(mouse_pos_loc .- widths .< 0.0)
                    if !gui.vars[:is_ctrl_pressed][] &&
                        !isempty(gui.vars[:selected_systems])
                        clear_selection(gui; clear_results=false)
                    end

                    pick_component!(gui; pick_topo_component=true)
                    if time_difference < double_click_threshold
                        notify(gui.buttons[:open].clicks)
                        return Consume(true)
                    end
                    last_click_time[] = current_click_time

                    gui.vars[:dragging][] = true
                    return Consume(true)
                else
                    axis_time_type = gui.menus[:time].selection[]
                    origin = pixelarea(gui.axes[axis_time_type].scene)[].origin
                    widths = pixelarea(gui.axes[axis_time_type].scene)[].widths
                    mouse_pos_loc = mouse_pos .- origin

                    if all(mouse_pos_loc .> 0.0) && all(mouse_pos_loc .- widths .< 0.0)
                        if !gui.vars[:is_ctrl_pressed][] &&
                            !isempty(gui.vars[:selected_plots])
                            clear_selection(gui; clear_topo=false)
                        end
                        pick_component!(gui; pick_results_component=true)
                        return Consume(true)
                    end
                    return Consume(false)
                end

            elseif event.action == Mouse.release
                if gui.vars[:dragging][]
                    gui.vars[:dragging][] = false
                    update!(gui::GUI)
                end
                return Consume(false)
            end
        elseif event.button == Mouse.button_4
            if event.action == Mouse.press
                notify(gui.buttons[:up].clicks)
                return Consume(true)
            end
            #elseif event.button == Mouse.right
            #    if event.action == Mouse.press
            #    elseif event.action == Mouse.release
            #    end
        end

        return Consume(false)
    end

    # Handle mouse movement
    on(events(gui.axes[:topo]).mouseposition; priority=2) do mouse_pos # priority ≥ 2 in order to suppress GLMakie left-click and drag zoom feature
        if gui.vars[:dragging][]
            origin::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].origin
            widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
            mouse_pos_loc::Vec2{Float64} = mouse_pos .- origin

            xy_widths::Vec2{Float32} = gui.axes[:topo].finallimits[].widths
            xy_origin::Vec2{Float32} = gui.axes[:topo].finallimits[].origin

            xy::Vec2{Float64} = xy_origin .+ mouse_pos_loc .* xy_widths ./ widths
            if !isempty(gui.vars[:selected_systems]) &&
                isa(gui.vars[:selected_systems][1], EnergySystemDesign) # Only nodes/area can be moved (connections will update correspondinlgy)
                sub_design::EnergySystemDesign = gui.vars[:selected_systems][1]

                update_sub_system_locations!(sub_design, Tuple(xy .- sub_design.xy[]))
                sub_design.xy[] = Tuple(xy)
            end
            return Consume(true)
        end

        return Consume(false)
    end

    # Align horizontally button: Handle click on the align horizontal button
    on(gui.buttons[:align_horizontal].clicks; priority=10) do clicks
        align(gui, :horizontal)
        return Consume(false)
    end

    # Align vertically button: Handle click on the align vertical button
    on(gui.buttons[:align_vertical].clicks; priority=10) do clicks
        align(gui, :vertical)
        return Consume(false)
    end

    # Open button: Handle click on the open button (open a sub system)
    on(gui.buttons[:open].clicks; priority=10) do clicks
        if !isempty(gui.vars[:selected_systems])
            gui.vars[:expand_all] = false
            component = gui.vars[:selected_systems][end] # Choose the last selected node
            if isa(component, EnergySystemDesign)
                if component.parent == :top_level
                    component.parent = if haskey(gui.design.system, :name)
                        gui.design.system[:name]
                    else
                        :top_level
                    end
                    plot_design!(
                        gui, gui.design; visible=false, expand_all=gui.vars[:expand_all]
                    )
                    gui.design = component
                    plot_design!(
                        gui, gui.design; visible=true, expand_all=gui.vars[:expand_all]
                    )
                    update_title!(gui)
                    #update_distances!(gui)
                    clear_selection(gui)
                    notify(gui.buttons[:reset_view].clicks)
                end
            end
        end
        return Consume(false)
    end

    # Navigate up button: Handle click on the navigate up button (go back to the root_design)
    on(gui.buttons[:up].clicks; priority=10) do clicks
        if !isnothing(gui.design.parent)
            gui.vars[:expand_all] = gui.toggles[:expand_all].active[]
            plot_design!(gui, gui.design; visible=false, expand_all=gui.vars[:expand_all])
            gui.design = gui.root_design
            plot_design!(gui, gui.design; visible=true, expand_all=gui.vars[:expand_all])
            update_title!(gui)
            adjust_limits!(gui)
            #notify_components()
            #update_distances!(gui)
            notify(gui.buttons[:reset_view].clicks)
        end
        return Consume(false)
    end

    # Pin current plot (the last plot added)
    on(gui.buttons[:pin_plot].clicks; priority=10) do _
        @info "Current plot pinned"
        axis_time_type = gui.vars[:axis_time_types][gui.menus[:time].i_selected[]]
        plots = gui.axes[axis_time_type].scene.plots
        if !isempty(plots) # Check if any plots exist
            pinned_plots = [x[:plot] for x ∈ gui.vars[:pinned_plots][axis_time_type]]
            plot = getfirst(
                x ->
                    !(x[:plot] ∈ pinned_plots) &&
                        (isa(x[:plot], Lines) || isa(x[:plot], Combined)),
                gui.vars[:visible_plots][axis_time_type],
            )
            if !isnothing(plot)
                push!(gui.vars[:pinned_plots][axis_time_type], plot)
            end
        end
        return Consume(false)
    end

    # Remove selected plot
    on(gui.buttons[:remove_plot].clicks; priority=10) do _
        if isempty(gui.vars[:selected_plots])
            return Consume(false)
        end
        axis_time_type = gui.vars[:axis_time_types][gui.menus[:time].i_selected[]]
        for plot_selected ∈ gui.vars[:selected_plots]
            plot_selected[:plot].visible = false
            toggle_selection_color!(gui, plot_selected, false)
            filter!(
                x -> x[:plot] != plot_selected[:plot],
                gui.vars[:visible_plots][axis_time_type],
            )
            filter!(
                x -> x[:plot] != plot_selected[:plot],
                gui.vars[:pinned_plots][axis_time_type],
            )
            @info "Removing plot with label: $(plot_selected[:plot].label[])"
        end
        update_legend!(gui)
        update_barplot_dodge!(gui)
        update_limits!(gui)
        empty!(gui.vars[:selected_plots])
        return Consume(false)
    end

    # Clear all plots
    on(gui.buttons[:clear_all].clicks; priority=10) do _
        axis_time_type = gui.vars[:axis_time_types][gui.menus[:time].i_selected[]]
        for plot_selected ∈ gui.vars[:visible_plots][axis_time_type]
            plot_selected[:plot].visible = false
            toggle_selection_color!(gui, plot_selected, false)
        end
        @info "Clearing plots"
        empty!(gui.vars[:selected_plots])
        empty!(gui.vars[:visible_plots][axis_time_type])
        empty!(gui.vars[:pinned_plots][axis_time_type])
        update_legend!(gui)
        return Consume(false)
    end

    # Toggle expansion of all systems
    on(gui.toggles[:expand_all].active; priority=10) do val
        # Plot the topology
        gui.vars[:expand_all] = val
        plot_design!(gui, gui.design; expand_all=val)
        update_distances!(gui)
        notify_components()
        return Consume(false)
    end

    # Save button: Handle click on the save button (save the altered coordinates)
    on(gui.buttons[:save].clicks; priority=10) do clicks
        save_design(gui.design)
        return Consume(false)
    end

    # Reset button: Reset view to the original view
    on(gui.buttons[:reset_view].clicks; priority=10) do clicks
        adjust_limits!(gui)
        notify(gui.axes[:topo].finallimits)
        return Consume(false)
    end

    # Export button: Export gui.axes[:results] to file (format given by export_type_menu.selection[])
    on(gui.buttons[:export].clicks; priority=10) do _
        if gui.menus[:export_type].selection[] == "REPL"
            axes_str::String = gui.menus[:axes].selection[]
            if axes_str == "Plots"
                axis_time_type = gui.vars[:axis_time_types][gui.menus[:time].i_selected[]]
                vis_plots = gui.vars[:visible_plots][axis_time_type]
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
                for dict ∈ collect(keys(object_dictionary(gui.model)))
                    @info "Results for $dict"
                    container = gui.model[dict]
                    if isempty(container)
                        continue
                    end
                    if typeof(container) <: JuMP.Containers.DenseAxisArray
                        axis_types = nameof.([eltype(a) for a ∈ JuMP.axes(gui.model[dict])])
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
    on(gui.menus[:time].selection; priority=10) do selection
        for (_, axis_time_type) ∈ gui.menus[:time].options[]
            if axis_time_type == selection
                showdecorations!(gui.axes[axis_time_type])
                showspines!(gui.axes[axis_time_type])
                showplots!([x[:plot] for x ∈ gui.vars[:visible_plots][axis_time_type]])
            else
                hidedecorations!(gui.axes[axis_time_type])
                hidespines!(gui.axes[axis_time_type])
                hideplots!(gui.axes[axis_time_type].scene.plots)
            end
        end
        update_legend!(gui)
        return Consume(false)
    end

    T = gui.design.system[:T]

    # Period menu: Handle menu selection (selecting period)
    on(gui.menus[:period].selection; priority=10) do _
        # Initialize representative_periods to be the representative_periods of the first operational period
        current_representative_period = gui.menus[:representative_period].selection[]
        representative_periods_in_sp = get_representative_period_indices(
            T, gui.menus[:period].selection[]
        )
        gui.menus[:representative_period].options = zip(
            gui.vars[:representative_periods_labels][representative_periods_in_sp],
            representative_periods_in_sp,
        )

        # If previously chosen representative_period is out of range, update it to be the largest number available
        if length(representative_periods_in_sp) < current_representative_period
            gui.menus[:representative_period].i_selection = length(
                representative_periods_in_sp
            )
        end
        if isempty(gui.vars[:selected_systems])
            update_plot!(gui, nothing)
        else
            update_plot!(gui, gui.vars[:selected_systems][end])
        end
        return Consume(false)
    end

    # Representative period menu: Handle menu selection
    on(gui.menus[:representative_period].selection; priority=10) do _
        # Initialize representative_periods to be the representative_periods of the first operational period
        current_scenario = gui.menus[:scenario].selection[]
        scenarios_in_rp = get_scenario_indices(
            T, gui.menus[:period].selection[], gui.menus[:representative_period].selection[]
        )
        gui.menus[:scenario].options = zip(
            gui.vars[:scenarios_labels][scenarios_in_rp], scenarios_in_rp
        )

        # If previously chosen scenario is out of range, update it to be the largest number available
        if length(scenarios_in_rp) < current_scenario
            gui.menus[:scenario].i_selection = length(scenarios_in_rp)
        end
        if isempty(gui.vars[:selected_systems])
            update_plot!(gui, nothing)
        else
            update_plot!(gui, gui.vars[:selected_systems][end])
        end
        return Consume(false)
    end

    # Scenario menu: Handle menu selection
    on(gui.menus[:scenario].selection; priority=10) do _
        if isempty(gui.vars[:selected_systems])
            update_plot!(gui, nothing)
        else
            update_plot!(gui, gui.vars[:selected_systems][end])
        end
        return Consume(false)
    end

    # Available data menu: Handle menu selection (selecting available data)
    on(gui.menus[:available_data].selection; priority=10) do val
        @debug "Changes in available data selection. New val: $val"
        if !isnothing(val)
            if isempty(gui.vars[:selected_systems])
                update_plot!(gui, nothing)
            else
                update_plot!(gui, gui.vars[:selected_systems][end])
            end
        end
        return Consume(false)
    end
end
