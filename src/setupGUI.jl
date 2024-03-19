"""
    GUI(case::Dict)

Initialize the EnergyModelsGUI window and visualize the topology of a system `case` (and optionally visualize its results in a JuMP object model). 

The optional arguments are as follows:
- **`design_path::String = ""`**: Path to store the coordinates in .yml files format
- **`idToColorMap::Dict = Dict()`**: A dict that maps `Resource`s `id` to colors
- **`idToIconMap::Dict = Dict()`**: A dict that maps `Node/Area` `id` to .png files for icons
- **`model::JuMP.Model = JuMP.Model()`**: Input a JuMP model with results for the `case`
- **`hideTopoAxDecorations::Bool = true`**: Toggle visibility of ticks, ticklabels and grids for the topology axis
- **`expandAll::Bool = false`**: Set the default option for toggling visibility of all nodes in all areas
- **`periods_labels::Vector = []`**: Descriptive labels for strategic periods
- **`scenarios_labels::Vector = []`**: Descriptive labels for scenarios   
- **`representativePeriods_labels::Vector = []`**: Descriptive labels for the representative periods
- **`pathToResults::String = ""`**: Path to where exported files are stored
- **`coarseCoastLines::Bool = true`**: Toggle coarse or fine resolution coastlines 
- **`backgroundcolor = GLMakie.RGBf(0.99, 0.99, 0.99)`**: Background colors of the main window 
- **`fontsize::Int64 = 12`**: General fontsize
- **`plot_widths::Tuple{Int64,Int64} = (1920, 1080)`**: Resolution of window
"""
function GUI(
        case::Dict;
        design_path::String = "",
        idToColorMap::Dict = Dict(),
        idToIconMap::Dict = Dict(),
        model::JuMP.Model = JuMP.Model(),
        hideTopoAxDecorations::Bool = true,
        expandAll::Bool = false,
        periods_labels::Vector = [],
        scenarios_labels::Vector = [],
        representativePeriods_labels::Vector = [],
        pathToResults::String = "",
        coarseCoastLines::Bool = true,
        backgroundcolor = GLMakie.RGBf(0.99, 0.99, 0.99),
        fontsize::Int64 = 12,
        plot_widths::Tuple{Int64,Int64} = (1920, 1080),
    )
    # Generate the system topology:
    @info raw"Setting up the topology design structure"
    root_design::EnergySystemDesign = EnergySystemDesign(case; design_path, idToColorMap, idToIconMap)

    @info raw"Setting up the GUI"
    design::EnergySystemDesign = root_design # variable to store current system (inkluding sub systems)

    # Set variables
    vars::Dict{Symbol,Any} = Dict(
        :title => Observable(""),
        :Δh => Observable(0.05), # Sidelength of main box
        :coarseCoastLines => coarseCoastLines,
        :Δh_px => 50,              # Pixel size of a box for nodes
        :markersize => 15,         # Marker size for arrows in connections
        :boundary_add => 0.2,     # Relative to the xlim/ylim-dimensions, expand the axis
        :line_sep_px => 2,         # Separation (in px) between lines for connections
        :connectionLinewidth => 2, # line width of connection lines
        :axAspectRatio => 1.0,     # Aspect ratio for the topology plotting area
        :fontsize => fontsize,           # General font size (in px)
        :linewidth => 1.2,         # Width of the line around boxes
        :parentScaling => 1.1,     # Scale for enlargement of boxes around main boxes for nodes for parent systems
        :icon_scale => 0.9,        # scale icons w.r.t. the surrounding box in fraction of Δh
        :twoWay_sep_px => Observable(10), # No pixels between set of lines for nodes having connections both ways
        :selection_color => :green2, # Colors for box boundaries when selection objects
        :investment_lineStyle => Linestyle([1.0, 1.5, 2.0, 2.5].*5), # linestyle for investment connections and box boundaries for nodes
        :pathToResults => pathToResults, # Path to the location where axes[:results] can be exported
        :resultsLegend => [],         # Legend for the results
        :pinnedPlots => Dict(         # Arrays of pinned plots (stores Dicts with keys :label and :plotObj)
            :results_sp => [], 
            :results_rp => [], 
            :results_op => [],
        ),
        :visiblePlots => Dict(         # Arrays of pinned plots (stores Dicts with keys :label and :plotObj)
            :results_sp => [], 
            :results_rp => [], 
            :results_op => [],
        ),
        :availableData => Dict{Any, Any}(),
        :originalPlotColor => :black,
    )

    # gobal variables for legends
    vars[:colorBoxPadding_px] = 25               # Padding around the legends
    vars[:colorBoxesWidth_px] = 20               # Width of the rectangles for the colors in legends
    vars[:colorBoxesHeight_px] = vars[:fontsize] # Height of the rectangles for the colors in legends
    vars[:colorBoxesSep_px] = 5                  # Separation between rectangles 
    vars[:boxTextSep_px] = 5                     # Separation between rectangles for colors and text
    vars[:descriptiveNames] = YAML.load_file(joinpath(@__DIR__,"descriptiveNames.yml"); dicttype=Dict{Symbol,Any})

    vars[:plot_widths] = plot_widths
    vars[:hideTopoAxDecorations] = hideTopoAxDecorations
    vars[:expandAll] = expandAll

    vars[:xlimits] = Vector{Float64}([0.0,1.0])
    vars[:ylimits] = Vector{Float64}([0.0,1.0])

    vars[:selected_systems] = []
    vars[:selected_plots] = []

    # Default text for the text area
    vars[:defaultText] = string(
        "Tips:\n",
        "Keyboard shortcuts:\n",
        "\tctrl+left-click: Select multiple nodes (use arrows to move all selected nodes simultaneously).\n",
        "\tright-click and drag: to pan\n",
        "\tscroll wheel: zoom in or out\n",
        "\tspace: Enter the selected system\n",
        "\tctrl+s: Save\n",
        "\tctrl+r: Reset view\n",
        "\tEsc (or MouseButton4): Exit the current system and into the parent system\n\n",
        "Left-clicking a component will put information about this component here\n\n",
        "Clicking a plot below enables you to pin this plot (hitting the `pin current plot` button) for comparison with other plots. Use the `Delete` button to unpin a selected plot"
    )
    dragging::Ref{Bool} = Ref(false)
    is_ctrl_pressed::Ref{Bool} = Ref(false)

    # Create a figure (the main window)
    GLMakie.activate!() # use GLMakie as backend
    GLMakie.set_theme!(fontsize = Float32(vars[:fontsize])) # Set the fontsize for the entire figure (if not otherwise specified, the fontsize will inherit this number)

    fig::Figure = Figure(resolution = vars[:plot_widths], backgroundcolor = backgroundcolor)

    # Create grid layout structure of the window
    gridlayout_taskbar::GridLayout        = fig[1,1:2] = GridLayout()
    gridlayout_topologyAx::GridLayout     = fig[2:4,1] = GridLayout(; valign = :top)
    gridlayout_info::GridLayout           = fig[2,2] = GridLayout()
    gridlayout_resultsAx::GridLayout      = fig[3,2] = GridLayout()
    gridlayout_resultsTaskbar::GridLayout = fig[4,2] = GridLayout()

    # Set row sizes of the layout
    taskbarHeight::Int64 = 30
    rowsize!(fig.layout, 1, Fixed(taskbarHeight)) # Control the relative height of the gridlayout_resultsAx (ax for plotting results)
    rowsize!(fig.layout, 3, Relative(0.55)) # Control the relative height of the gridlayout_resultsAx (ax for plotting results)

    # Get the current limits of the axis
    colsize!(fig.layout, 2, Auto(1))
    vars[:axAspectRatio] = vars[:plot_widths][1]/(vars[:plot_widths][2]-taskbarHeight)/2

    # Check whether or not to use lat-lon coordinates to construct the axis used for visualizing the topology
    if haskey(root_design.system,:areas) # The root_design uses the EnergyModelsGeography package: Thus use GeoMakie 
        # Set the source mapping for projection
        source::String = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        # Set the destination mapping for projection
        dest::String   = "+proj=merc +lon_0=0 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +units=m +no_defs"
        # Construct the axis from the GeoMakie package
        ax = GeoMakie.GeoAxis(
            gridlayout_topologyAx[1,1],
            source = source, 
            dest = dest,
            backgroundcolor=:lightblue1,
            aspect = DataAspect(), 
            alignmode = Outside(),
        )

        if vars[:coarseCoastLines] # Use low resolution coast lines
            land = GeoMakie.land()
            coastlns = poly!(ax, land; 
                color = :honeydew, 
                colormap = :dense,
                strokecolor = :gray50, 
                strokewidth = 0.5,
                inspectable = false,
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
            countries::GeoJSON.FeatureCollection{2, Float32} = GeoJSON.read(read(local_file_path, String))
            coastlns = poly!(ax, countries; 
                color = :honeydew, 
                colormap = :dense,
                strokecolor = :gray50, 
                strokewidth = 0.5,
                inspectable = false,
            )
        end
    else # The root_design does not use the EnergyModelsGeography package: Create a simple Makie axis
        ax = Axis(
            gridlayout_topologyAx[1,1],
            aspect = DataAspect(), 
            alignmode = Outside(), 
        )
    end
    if vars[:hideTopoAxDecorations]
        hidedecorations!(ax)
    end

    # Create axis for visualizating results 
    axResults_sp::Axis = Axis(gridlayout_resultsAx[1,1], alignmode=Outside(), tellheight=false, tellwidth=false, backgroundcolor=backgroundcolor)
    axResults_rp::Axis = Axis(gridlayout_resultsAx[1,1], alignmode=Outside(), tellheight=false, tellwidth=false, backgroundcolor=backgroundcolor)
    axResults_op::Axis = Axis(gridlayout_resultsAx[1,1], alignmode=Outside(), tellheight=false, tellwidth=false, backgroundcolor=backgroundcolor)
    hidedecorations!(axResults_rp)
    hidedecorations!(axResults_op)
    hidespines!(axResults_rp)
    hidespines!(axResults_op)
    axisTimeTypes_labels = ["Strategic", "Representative", "Operational"]
    axisTimeTypes = [:results_sp, :results_rp, :results_op]

    # Collect all strategic periods
    T = root_design.system[:T]
    periods::Vector{Int64} = 1:T.len

    # Initialize representativePeriods to be the representativePeriod of the first strategic period
    representativePeriods::Vector{Int64} = get_representative_period_indices(T, 1, 1)

    # Initialize scenarios to be the scenario of the first strategic period
    scenarios::Vector{Int64} = get_scenario_indices(T, 1)

    # Use the index number for time period labels if not provided
    if isempty(periods_labels)
        periods_labels = string.(periods)
    else # make sure all labels are strings
        periods_labels = string.(periods_labels)
    end
    if isempty(scenarios_labels)
        scenarios_labels = string.(scenarios)
    else # make sure all labels are strings
        scenarios_labels = string.(scenarios_labels)
    end
    if isempty(representativePeriods_labels)
        representativePeriods_labels = string.(representativePeriods)
    else # make sure all labels are strings
        representativePeriods_labels = string.(representativePeriods_labels)
    end

    # Create legend to explain the available resources in the root_design model
    markers::Vector{Makie.Scatter}   = Vector{Makie.Scatter}(undef,0)
    for color in collect(values(root_design.idToColorMap))
        push!(markers, scatter!(ax, Point2f((0, 0)), marker = :rect, color = color, visible = false)) # add invisible dummy markers to be put in the legend box
    end
    vars[:topoLegend] = axislegend(ax, markers, collect(keys(root_design.idToColorMap)), "Resources", position = :rt, labelsize = vars[:fontsize], titlesize = vars[:fontsize])

    # Initiate an axis for displaying information about the selected node
    axInfo::Makie.Axis = Axis(gridlayout_info[1,1], backgroundcolor = backgroundcolor)

    # Add text at the top left of the axis domain (to print information of the selected/hovered node/connection)
    text!(axInfo, vars[:defaultText], position = (0.01, 0.99), align = (:left, :top), fontsize = vars[:fontsize])
    limits!(axInfo, [0,1], [0,1])

    # Remove ticks and labels
    hidedecorations!(axInfo)

    # Add buttons related to the ax object (where the topology is visualized)
    align_horizontal_button = Makie.Button(gridlayout_taskbar[1, 1]; label = "align horz.", fontsize = vars[:fontsize])
    align_vertical_button   = Makie.Button(gridlayout_taskbar[1, 2]; label = "align vert.", fontsize = vars[:fontsize])
    open_button             = Makie.Button(gridlayout_taskbar[1, 3]; label = "open", fontsize = vars[:fontsize])
    up_button               = Makie.Button(gridlayout_taskbar[1, 4]; label = "navigate up", fontsize = vars[:fontsize])
    save_button             = Makie.Button(gridlayout_taskbar[1, 5]; label = "save", fontsize = vars[:fontsize])
    resetView_button        = Makie.Button(gridlayout_taskbar[1, 6]; label = "reset view", fontsize = vars[:fontsize])
    expandAll_label         = Makie.Label( gridlayout_taskbar[1, 7], "Expand all:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    expandAll_toggle        = Makie.Toggle(gridlayout_taskbar[1, 8]; active = vars[:expandAll])

    # Add the following to separate the buttons (related to axes[:topo]) to the left and the menus (related to axes[:results]) to the right
    #Makie.Label(gridlayout_taskbar[1, 7], ""; tellwidth = false) 

    # Add buttons related to the axResults object (where the optimization results are plotted) 
    #investmentPlan_label    = Makie.Label(gridlayout_taskbar[1, 8], "Investment plan:"; halign = :left, fontsize = vars[:fontsize], justification = :left)
    #investmentPlan_menu     = Makie.Menu(gridlayout_taskbar[1, 9], halign = :left, width=100, fontsize = vars[:fontsize])
    period_label               = Makie.Label(gridlayout_taskbar[1, 9], "Period:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    period_menu                = Makie.Menu( gridlayout_taskbar[1, 10], options = zip(periods_labels, periods), default = periods_labels[1], halign = :left, width=100*vars[:fontsize]/12, fontsize = vars[:fontsize])
    scenario_label             = Makie.Label(gridlayout_taskbar[1, 11], "Scenario:"; halign = :left, fontsize = vars[:fontsize], justification = :left)
    scenario_menu              = Makie.Menu( gridlayout_taskbar[1, 12], options = zip(scenarios_labels, scenarios), default = scenarios_labels[1], halign = :left, width=100*vars[:fontsize]/12, fontsize = vars[:fontsize])
    representativePeriod_label = Makie.Label(gridlayout_taskbar[1, 13], "Representative period:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    representativePeriod_menu  = Makie.Menu( gridlayout_taskbar[1, 14], options = zip(representativePeriods_labels, representativePeriods), default = representativePeriods_labels[1], halign = :left, width=100*vars[:fontsize]/12, fontsize = vars[:fontsize])
    availableData_label        = Makie.Label(gridlayout_taskbar[1, 15], "Data:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    availableData_menu         = Makie.Menu( gridlayout_taskbar[1, 16], halign = :left, fontsize = vars[:fontsize],tellwidth = true)

    # Add the following to add flexibility
    Makie.Label(gridlayout_resultsTaskbar[1, 1], ""; tellwidth = false) 

    # Add task bar over axes[:results]
    time_label        = Makie.Label( gridlayout_resultsTaskbar[1, 2], "Plot:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    time_menu         = Makie.Menu(  gridlayout_resultsTaskbar[1, 3], options = zip(axisTimeTypes_labels, axisTimeTypes), halign = :left, width=120*vars[:fontsize]/12, fontsize = vars[:fontsize])
    pinPlot_button    = Makie.Button(gridlayout_resultsTaskbar[1, 4]; label = "pin current data", fontsize = vars[:fontsize])
    removePlot_button = Makie.Button(gridlayout_resultsTaskbar[1, 5]; label = "remove selected data", fontsize = vars[:fontsize])
    saveResults_label = Makie.Label( gridlayout_resultsTaskbar[1, 6], "Export:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    axes_menu         = Makie.Menu(  gridlayout_resultsTaskbar[1, 7], options = ["All", "Plots"], default = "Plots", halign = :left, width=80*vars[:fontsize]/12, fontsize = vars[:fontsize])
    saveResults_menu  = Makie.Menu(  gridlayout_resultsTaskbar[1, 8], options = ["bmp", "tiff", "tif", "jpg", "jpeg", "svg", "xlsx", "png", "REPL"], default = "REPL", halign = :left, width=60*vars[:fontsize]/12, fontsize = vars[:fontsize])
    export_button     = Makie.Button(gridlayout_resultsTaskbar[1, 9]; label = "export", fontsize = vars[:fontsize])

    # Collect all menus into a dictionary
    buttons::Dict{Symbol, Makie.Button} = Dict(
        :align_horizontal => align_horizontal_button, 
        :align_vertical => align_vertical_button, 
        :open => open_button, 
        :up => up_button, 
        :save => save_button,
        :resetView => resetView_button,
        :export => export_button,
        :pinPlot => pinPlot_button,
    )

    # Collect all menus into a dictionary
    menus::Dict{Symbol, Makie.Menu} = Dict(
        :period => period_menu, 
        :scenario => scenario_menu,
        :representativePeriod => representativePeriod_menu,
        :availableData => availableData_menu,
        :time => time_menu, 
        :saveResults => saveResults_menu,
        :axes => axes_menu,
    )

    # Collect all toggles into a dictionary
    toggles::Dict{Symbol, Makie.Toggle} = Dict(
        :expandAll => expandAll_toggle, 
    )

    # Collect all axes into a dictionary
    axes::Dict{Symbol, Makie.Block} = Dict(
        :topo => ax, 
        :results_sp => axResults_sp,
        :results_rp => axResults_rp,
        :results_op => axResults_op,
        :info => axInfo,
    )

    ## Create the main structure for the EnergyModelsGUI
    gui::GUI = GUI(fig, axes, buttons, menus, toggles, root_design, design, model, vars)

    # Update the title of the figure
    topoTitleLocX::Observable{Float64} = Observable(0.0)
    topoTitleLocY::Observable{Float64} = Observable(0.0)
    vars[:topoTitleObj] = text!(ax, topoTitleLocX, topoTitleLocY, text = gui.vars[:title], fontsize = vars[:fontsize])
    update_title!(gui)

    # Plot the topology
    initialize_plot!(gui, gui.root_design)
    
    # Pre calculate the available fields for each node
    initialize_availableData!(gui)

    # Update limits based on the location of the nodes
    adjust_limits!(gui)
        
    update!(gui, nothing)

    # Create a function that notifies all components (and thus updates graphics when the observables are notified)
    notifyComponents = () -> begin
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
    on(gui.axes[:topo].finallimits, priority = 10) do finallimits
        @debug "Changes in finallimits"
        widths::Vec{2, Float32} = finallimits.widths
        origin::Vec{2, Float32} = finallimits.origin
        gui.vars[:xlimits] = [origin[1], origin[1] + widths[1]]
        gui.vars[:ylimits] = [origin[2], origin[2] + widths[2]]
        update_distances!(gui)
        notifyComponents()
        topoTitleLocX[] = origin[1] + widths[1]/100
        topoTitleLocY[] = origin[2] + widths[2] - widths[2]/100 - pixel_to_data(gui, gui.vars[:fontsize])[2]
        return Consume(false)
    end

    # If the window is resized, make sure all graphics are adjusted acordingly
    on(gui.fig.scene.events.window_area, priority = 3) do val
        @debug "Changes in window_area"
        gui.vars[:plot_widths] = Tuple(gui.fig.scene.px_area.val.widths)
        gui.vars[:axAspectRatio] = gui.vars[:plot_widths][1]/(vars[:plot_widths][2]-taskbarHeight)/2
        notify(gui.axes[:topo].finallimits)
        return Consume(false)
    end

    # Handle case when user is pressing/releasing any ctrl key (in order to select multiple components)
    on(events(gui.axes[:topo].scene).keyboardbutton, priority=3) do event
        # For more integers: using GLMakie; typeof(events(gui.axes[:topo].scene).keyboardbutton[].key) 

        isCtrl(key::Makie.Keyboard.Button) = Int(key) == 341 || Int(key) == 345 # any of the ctrl buttons is clicked
        if event.action == Keyboard.press
            if isCtrl(event.key) 
                # Register if any ctrl-key has been pressed
                is_ctrl_pressed[] = true
            elseif Int(event.key) ∈ [262,263,264,265] # arrow right, arrow left, arrow down or arrow up
                # move a component(s) using the arrow keys

                # get changes
                change::Tuple{Float64,Float64} = get_change(gui, Val(event.key))

                # check if any changes where made
                if change != (0.0, 0.0)
                    for sub_design in gui.vars[:selected_systems]
                        xc::Real = sub_design.xy[][1]
                        yc::Real = sub_design.xy[][2]

                        sub_design.xy[] = (xc + change[1], yc + change[2])

                        update_sub_system_locations!(sub_design, Tuple(change))
                    end

                    notifyComponents()
                end
            elseif Int(event.key) == 256 # Esc used to move up a level in the topology
                notify(up_button.clicks)
            elseif Int(event.key) == 32 # Space used to open up a sub-system
                notify(open_button.clicks)
            elseif Int(event.key) == 261 # Delete used to delete selected plot
                notify(removePlot_button.clicks)
            elseif Int(event.key) == 82 # ctrl+r: Reset view
                if is_ctrl_pressed[]
                    notify(resetView_button.clicks)
                end
            elseif Int(event.key) == 83 # ctrl+s: Save
                if is_ctrl_pressed[]
                    notify(save_button.clicks)
                end
            #elseif Int(event.key) == 340 # Shift
            #elseif Int(event.key) == 342 # Alt
            end
        elseif event.action == Keyboard.release
            if isCtrl(event.key) 
                # Register if any ctrl-key has been released
                is_ctrl_pressed[] = false
            end
        end
        return Consume(true)
    end

    last_click_time = Ref(Dates.now())

    # Define the double-click threshold
    double_click_threshold = Dates.Millisecond(500) # Default value in Windows

    # Handle cases for mousebutton input
    on(events(gui.axes[:topo]).mousebutton, priority = 4) do event
        if event.button == Mouse.left
            current_click_time = Dates.now()
            time_difference = current_click_time - last_click_time[]
            if event.action == Mouse.press
                # Make sure selections are not removed when left-clicking outside axes[:topo]
                mouse_pos::Tuple{Float64, Float64} = events(gui.axes[:topo]).mouseposition[]

                origin::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].origin
                widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
                mouse_pos_loc::Vec2{Float64} = mouse_pos .- origin

                # Check if mouseclick is outside the gui.axes[:topo] area (and return if so)
                if all(mouse_pos_loc .> 0.0) && all(mouse_pos_loc .- widths .< 0.0)
                    if !is_ctrl_pressed[] && !isempty(gui.vars[:selected_systems])
                        clear_selection(gui; clearResults = false)
                    end

                    pick_component!(gui; pickTopoComponent = true)
                    if time_difference < double_click_threshold
                        notify(open_button.clicks)
                        return Consume(true)
                    end
                    last_click_time[] = current_click_time

                    dragging[] = true
                    return Consume(true)
                else
                    axisTimeType = gui.menus[:time].selection[]
                    origin = pixelarea(gui.axes[axisTimeType].scene)[].origin
                    widths = pixelarea(gui.axes[axisTimeType].scene)[].widths
                    mouse_pos_loc = mouse_pos .- origin

                    if all(mouse_pos_loc .> 0.0) && all(mouse_pos_loc .- widths .< 0.0)
                        if !is_ctrl_pressed[] && !isempty(gui.vars[:selected_plots])
                            clear_selection(gui; clearTopo = false)
                        end
                        pick_component!(gui; pickResultsComponent = true)
                        return Consume(true)
                    end
                    return Consume(false)
                end

            elseif event.action == Mouse.release
                if dragging[]
                    dragging[] = false
                    update!(gui::GUI)
                end
                return Consume(false)
            end
        elseif event.button == Mouse.button_4
            if event.action == Mouse.press
                notify(up_button.clicks)
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
    on(events(gui.axes[:topo]).mouseposition, priority = 2) do mouse_pos # priority ≥ 2 in order to suppress GLMakie left-click and drag zoom feature
        if dragging[]
            origin::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].origin
            widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
            mouse_pos_loc::Vec2{Float64} = mouse_pos .- origin

            xy_widths::Vec2{Float32} = gui.axes[:topo].finallimits[].widths
            xy_origin::Vec2{Float32} = gui.axes[:topo].finallimits[].origin

            xy::Vec2{Float64} = xy_origin .+ mouse_pos_loc .* xy_widths ./ widths
            if !isempty(gui.vars[:selected_systems]) && gui.vars[:selected_systems][1] isa EnergySystemDesign # Only nodes/area can be moved (connections will update correspondinlgy)
                sub_design::EnergySystemDesign = gui.vars[:selected_systems][1]

                update_sub_system_locations!(sub_design, Tuple(xy .- sub_design.xy[]))
                sub_design.xy[] = Tuple(xy)
            end
            return Consume(true)
        end

        return Consume(false)
    end
    

    # Align horizontally button: Handle click on the align horizontal button
    on(align_horizontal_button.clicks, priority=10) do clicks
        align(gui, :horizontal)
        return Consume(false)
    end

    # Align vertically button: Handle click on the align vertical button
    on(align_vertical_button.clicks, priority=10) do clicks
        align(gui, :vertical)
        return Consume(false)
    end

    # Open button: Handle click on the open button (open a sub system)
    on(open_button.clicks, priority=10) do clicks
        if !isempty(gui.vars[:selected_systems])
            gui.vars[:expandAll] = false
            component = gui.vars[:selected_systems][end] # Choose the last selected node
            if component isa EnergySystemDesign
                if component.parent == :TopLevel
                    component.parent = haskey(gui.design.system,:name) ? gui.design.system[:name] : :TopLevel
                    plot_design!(gui, gui.design; visible = false, expandAll = gui.vars[:expandAll])
                    gui.design = component
                    plot_design!(gui, gui.design; visible = true, expandAll = gui.vars[:expandAll])
                    update_title!(gui)
                    #update_distances!(gui)
                    clear_selection(gui)
                    notify(resetView_button.clicks)
                end
            end
        end
        return Consume(false)
    end

    # Navigate up button: Handle click on the navigate up button (go back to the root_design)
    on(up_button.clicks, priority=10) do clicks
        if !isnothing(gui.design.parent)
            gui.vars[:expandAll] = gui.toggles[:expandAll].active[]
            plot_design!(gui, gui.design; visible = false, expandAll = gui.vars[:expandAll])
            gui.design = root_design
            plot_design!(gui, gui.design; visible = true, expandAll = gui.vars[:expandAll])
            update_title!(gui)
            adjust_limits!(gui)
            #notifyComponents()
            #update_distances!(gui)
        end
        return Consume(false)
    end
    
    # Pin current plot (the last plot added)
    on(pinPlot_button.clicks, priority=10) do _
        @info "Current plot pinned"
        axisTimeType = axisTimeTypes[gui.menus[:time].i_selected[]]
        plotObjs = gui.axes[axisTimeType].scene.plots
        if !isempty(plotObjs) # Check if any plots exist
            pinnedPlots = [x[:plotObj] for x ∈ gui.vars[:pinnedPlots][axisTimeType]]
            plotObj = getfirst(x -> !(x[:plotObj] ∈ pinnedPlots) && (x[:plotObj] isa Lines || x[:plotObj] isa Combined), gui.vars[:visiblePlots][axisTimeType])
            if !isnothing(plotObj)
                push!(gui.vars[:pinnedPlots][axisTimeType], plotObj)
            end
        end
        return Consume(false)
    end

    # Remove selected plot
    on(removePlot_button.clicks, priority=10) do _
        if isempty(gui.vars[:selected_plots])
            return Consume(false)
        end
        axisTimeType = axisTimeTypes[gui.menus[:time].i_selected[]]
        for plotObj_selected ∈ gui.vars[:selected_plots]
            plotObj_selected.visible = false
            toggle_selection_color!(gui, plotObj_selected, false)
            filter!(x -> x[:plotObj] != plotObj_selected, gui.vars[:visiblePlots][axisTimeType])
            filter!(x -> x[:plotObj] != plotObj_selected, gui.vars[:pinnedPlots][axisTimeType])
            @info "Removing plot with label: $(plotObj_selected.label[])"

        end
        update_legend!(gui)
        update_barplot_dodge!(gui)
        update_limits!(gui)
        empty!(gui.vars[:selected_plots])
        return Consume(false)
    end

    # Toggle expansion of all systems
    on(gui.toggles[:expandAll].active, priority=10) do val
        # Plot the topology
        gui.vars[:expandAll] = val
        plot_design!(gui, gui.design; expandAll = val)
        update_distances!(gui)
        notifyComponents()
        return Consume(false)
    end

    # Save button: Handle click on the save button (save the altered coordinates)
    on(save_button.clicks, priority=10) do clicks
        save_design(gui.design)
        return Consume(false)
    end

    # Reset button: Reset view to the original view
    on(resetView_button.clicks, priority=10) do clicks
        adjust_limits!(gui)
        notify(gui.axes[:topo].finallimits)
        return Consume(false)
    end

    # Export button: Export gui.axes[:results] to file (format given by saveResults_menu.selection[])
    on(export_button.clicks, priority=10) do _
        if gui.menus[:saveResults].selection[] == "REPL"
            axesStr::String = gui.menus[:axes].selection[]
            if axesStr == "Plots"
                axisTimeType = axisTimeTypes[gui.menus[:time].i_selected[]]
                visPlots = gui.vars[:visiblePlots][axisTimeType]
                if !isempty(visPlots) # Check if any plots exist
                    t = visPlots[1][:t]
                    data = Matrix{Any}(undef,length(t),length(visPlots)+1)
                    data[:,1] = t
                    header = (Vector{Any}(undef, length(visPlots)+1),
                            Vector{Any}(undef, length(visPlots)+1))
                    header[1][1] = "t"
                    header[2][1] = "(" * string(nameof(eltype(t))) * ")"
                    for (j, visPlot) ∈ enumerate(visPlots)
                        data[:, j+1] = visPlot[:y]
                        header[1][j+1] = visPlots[j][:name]
                        header[2][j+1] = join([string(x) for x ∈ visPlots[j][:selection]], ", ")
                    end
                    println("\n")  # done in order to avoid the promt shifting the topspline of the table
                    pretty_table(data, header = header)
                end
            elseif axesStr == "All"
                for dict ∈ collect(keys(object_dictionary(gui.model))) 
                    @info "Results for $dict"
                    container = gui.model[dict]
                    if isempty(container)
                        continue
                    end
                    if typeof(container) <: JuMP.Containers.DenseAxisArray
                        axisTypes = nameof.([eltype(a) for a in JuMP.axes(gui.model[dict])])
                    elseif typeof(container) <: JuMP.Containers.SparseAxisArray
                        axisTypes = collect(nameof.(typeof.(first(container.data)[1])))
                    end
                    header = vcat(axisTypes, [:value])
                    pretty_table(
                        JuMP.Containers.rowtable(
                            value,
                            container;
                            header=header,
                        ),
                    )
                end
            end
        else
            export_to_file(gui)
        end
        return Consume(false)
    end
    
    # Time menu: Handle menu selection (selecting time)
    on(time_menu.selection, priority=10) do selection
        for (_, axisTimeType) in time_menu.options[]
            if axisTimeType == selection
                showdecorations!(gui.axes[axisTimeType])
                showspines!(gui.axes[axisTimeType])
                showplots!([x[:plotObj] for x ∈ gui.vars[:visiblePlots][axisTimeType]])
            else
                hidedecorations!(gui.axes[axisTimeType])
                hidespines!(gui.axes[axisTimeType])
                hideplots!(gui.axes[axisTimeType].scene.plots)
            end
        end
        update_legend!(gui)
        return Consume(false)
    end

    # Period menu: Handle menu selection (selecting period)
    on(period_menu.selection, priority=10) do _
        # Initialize representativePeriods to be the representativePeriods of the first operational period
        currentRepresentativePeriod = gui.menus[:representativePeriod].selection[]
        representativePeriodsInSP = get_representative_period_indices(T, gui.menus[:period].selection[], gui.menus[:scenario].selection[])
        gui.menus[:representativePeriod].options = zip(representativePeriods_labels[representativePeriodsInSP], representativePeriodsInSP)

        # If previously chosen representativePeriod is out of range, update it to be the largest number available
        if length(representativePeriodsInSP) < currentRepresentativePeriod
            gui.menus[:representativePeriod].i_selection = length(representativePeriodsInSP)
        end
        if isempty(gui.vars[:selected_systems])
            update_plot!(gui, nothing)
        else
            update_plot!(gui, gui.vars[:selected_systems][end])
        end
        return Consume(false)
    end
    
    # Scenario menu: Handle menu selection
    on(scenario_menu.selection, priority=10) do _
        # Initialize representativePeriods to be the representativePeriods of the first operational period
        currentScenario = gui.menus[:representativePeriod].selection[]
        scenariosInSP = get_scenario_indices(T, gui.menus[:period].selection[])
        gui.menus[:scenario].options = zip(scenarios_labels[scenariosInSP], scenariosInSP)

        # If previously chosen representativePeriod is out of range, update it to be the largest number available
        if length(scenariosInSP) < currentScenario
            gui.menus[:scenario].i_selection = length(scenariosInSP)
        end
        if isempty(gui.vars[:selected_systems])
            update_plot!(gui, nothing)
        else
            update_plot!(gui, gui.vars[:selected_systems][end])
        end
        return Consume(false)
    end
    
    # Representative period menu: Handle menu selection
    on(representativePeriod_menu.selection, priority=10) do _
        if isempty(gui.vars[:selected_systems])
            update_plot!(gui, nothing)
        else
            update_plot!(gui, gui.vars[:selected_systems][end])
        end
        return Consume(false)
    end

    # Available data menu: Handle menu selection (selecting available data)
    on(gui.menus[:availableData].selection, priority=10) do val
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

    # make sure all graphics is adapted to the spawned figure sizes
    notify(gui.toggles[:expandAll].active)
    #notify(pixelarea(gui.axes[:topo].scene))
    #update_distances!(gui)

    # Enable inspector (such that hovering objects shows information)
    DataInspector(fig, range = 10, indicator_linewidth = 0, enable_indicator = false) # Linewidth set to zero as this boundary is slightly laggy on movement

    # display the figure
    display(gui.fig)

    return gui
end