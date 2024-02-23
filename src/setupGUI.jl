# Create a type for all Clickable objects in the gui.axes[:topo]
const Plotable = Union{Nothing, EMB.Node, EMB.Link, EMG.Area, EMG.Transmission} # Types that can trigger an update in the gui.axes[:opAn] plot

"""
    GUI(case, path; idToColorMap, idToIconMap, model::JuMP.Model = JuMP.Model())

Initialize the EnergyModelsGUI window and visualize the topology of a EnergySystemDesign object (and optionally visualize its results in the JuMP object model).
"""
function GUI(case::Dict; design_path::String = "", idToColorMap::Dict{Any,Any} = Dict{Any,Any}(), idToIconMap::Dict{Any,Any} = Dict{Any,Any}(), model::JuMP.Model = JuMP.Model())
    # Generate the system topology:
    @info raw"Setting up the topology design structure"
    root_design::EnergySystemDesign = EnergySystemDesign(case; design_path, idToColorMap, idToIconMap)

    @info raw"Setting up the GUI"
    design::EnergySystemDesign = root_design # variable to store current system (inkluding sub systems)

    # Set variables
    vars::Dict{Symbol,Any} = Dict(
        :title => Observable(""),
        :Δh => Observable(0.05), # Sidelength of main box
        :coarseCoastLines => false,
        :Δh_px => 50,              # Pixel size of a box for nodes
        :markersize => 15,         # Marker size for arrows in connections
        :boundary_add => 0.2,     # Relative to the xlim/ylim-dimensions, expand the axis
        :line_sep_px => 2,         # Separation (in px) between lines for connections
        :connectionLinewidth => 2, # line width of connection lines
        :axAspectRatio => 1.0,     # Aspect ratio for the topology plotting area
        :fontsize => 12,           # General font size (in px)
        :linewidth => 1.2,         # Width of the line around boxes
        :parentScaling => 1.1,     # Scale for enlargement of boxes around main boxes for nodes for parent systems
        :icon_scale => 0.9,        # scale icons w.r.t. the surrounding box in fraction of Δh
        :twoWay_sep_px => Observable(10), # No pixels between set of lines for nodes having connections both ways
        :selection_color => :green2, # Colors for box boundaries when selection objects
        :investment_lineStyle => Linestyle([1.0, 1.5, 2.0, 2.5].*5), # linestyle for investment connections and box boundaries for nodes
    )

    # gobal variables for legends
    vars[:colorBoxPadding_px] = 25         # Padding around the legends
    vars[:colorBoxesWidth_px] = 20         # Width of the rectangles for the colors in legends
    vars[:colorBoxesHeight_px] = vars[:fontsize]  # Height of the rectangles for the colors in legends
    vars[:colorBoxesSep_px] = 5            # Separation between rectangles 
    vars[:boxTextSep_px] = 5               # Separation between rectangles for colors and text

    vars[:plot_widths] = Observable((1920, 1080))

    vars[:xlimits] = Observable(Vector{Float64}([0.0,1.0]))
    vars[:ylimits] = Observable(Vector{Float64}([0.0,1.0]))

    vars[:availableData_menu_history] = Ref(Vector{String}(undef, 0))
    vars[:selected_systems] = []
    vars[:selected_system] = []
    vars[:prev_selection] = []

    # Default text for the text area
    vars[:defaultText] = string("Tips:\n",
                        "Keyboard shortcuts:\n",
                        "\tctrl+left-click: Select multiple nodes (use arrows to move all selected nodes simultaneously).\n",
                        "\tright-click and drag: to pan\n",
                        "\tscroll wheel: zoom in or out\n",
                        "\tspace: Enter the selected system\n",
                        "\tctrl+s: Save\n",
                        "\tctrl+r: Reset view\n",
                        "\tEsc: Exit the current system and into the parent system\n\n",
                        "Left-clicking a component will put information about this component here")
    dragging::Ref{Bool} = Ref(false)
    is_ctrl_pressed::Ref{Bool} = Ref(false)

    # Create a figure (the main window)
    fig::Figure = Figure(resolution = vars[:plot_widths][], backgroundcolor = RGBf(0.99, 0.99, 0.99))

    # Create grid layout structure of the window
    gridlayout_buttons::GridLayout    = fig[1,1:2] = GridLayout()
    gridlayout_topologyAx::GridLayout = fig[2:3,1] = GridLayout()
    gridlayout_info::GridLayout       = fig[2,2] = GridLayout()
    gridlayout_resultsAx::GridLayout  = fig[3,2] = GridLayout()

    # Set row sizes of the layout
    rowsize!(fig.layout, 3, Relative(0.55)) # Control the relative height of the gridlayout_resultsAx (ax for plotting results)

    # Get the current limits of the axis
    colsize!(fig.layout, 2, Auto(0.97))

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
            alignmode = Outside(),
        )

        if vars[:coarseCoastLines] # Use low resolution coast lines
            lines!(ax, GeoMakie.coastlines())
        else # Use high resolution coast lines

            # Define the URL and the local file path
            url::String = "https://datahub.io/core/geo-countries/r/countries.geojson"
            temp_dir::String = tempdir()  # Get the system's temporary directory
            filename::String = "EnergyModelsGUI_countries.geojson"
            local_file_path::String = joinpath(temp_dir, filename)

            # Download the file if it doesn't exist in the temporary directory
            if !isfile(local_file_path)
                @debug "Trying to download file $url to $local_file_path"
                HTTP.download(url, local_file_path)
            end

            # Now read the data from the file
            countries::GeoJSON.FeatureCollection{2, Float32} = GeoJSON.read(read(local_file_path, String))
            poly!(ax, countries; 
                color = :honeydew, 
                colormap = :dense,
                strokecolor = :gray50, 
                strokewidth = 0.5,
            )
        end
    else # The root_design does not use the EnergyModelsGeography package: Create a simple Makie axis
        ax = Axis(
            gridlayout_topologyAx[1,1],
            aspect = DataAspect(), 
            alignmode = Outside(), 
        )
    end

    # Create axis for visualizating results 
    axResults::Axis = Axis(gridlayout_resultsAx[1,1], alignmode=Outside(), tellheight=false, tellwidth=false)

    # Collect all strategic periods
    periods::Vector{TimeStruct.StrategicPeriod} = [t for t in TS.strat_periods(root_design.system[:T])]

    # If no periods_labels are given, simply convert values to strings
    periods_labels::Vector{String} = string.(periods)

    # Create legend to explain the available resources in the root_design model
    markers::Vector{Makie.Scatter}   = Vector{Makie.Scatter}(undef,0)
    for color in collect(values(root_design.idToColorMap))
        push!(markers, scatter!(ax, Point2f((0, 0)), marker = :rect, color = color, visible = false)) # add invisible dummy markers to be put in the legend box
    end
    vars[:topoLegend] = axislegend(ax, markers, collect(keys(root_design.idToColorMap)), "Resources", position = :rt, labelsize = vars[:fontsize], titlesize = vars[:fontsize])

    # Initiate an axis for displaying information about the selected node
    axInfo::Makie.Axis = Axis(gridlayout_info[1,1])

    # Add text at the top left of the axis domain (to print information of the selected/hovered node/connection)
    text!(axInfo, vars[:defaultText], position = (0.01, 0.99), align = (:left, :top), fontsize = vars[:fontsize])
    limits!(axInfo, [0,1], [0,1])

    # Remove ticks and labels
    hidedecorations!(axInfo)

    # Add buttons related to the ax object (where the topology is visualized)
    align_horizontal_button = Makie.Button(gridlayout_buttons[1, 1]; label = "align horz.", fontsize = vars[:fontsize])
    align_vertical_button   = Makie.Button(gridlayout_buttons[1, 2]; label = "align vert.", fontsize = vars[:fontsize])
    open_button             = Makie.Button(gridlayout_buttons[1, 3]; label = "open", fontsize = vars[:fontsize])
    up_button               = Makie.Button(gridlayout_buttons[1, 4]; label = "navigate up", fontsize = vars[:fontsize])
    save_button             = Makie.Button(gridlayout_buttons[1, 5]; label = "save", fontsize = vars[:fontsize])
    resetView_button        = Makie.Button(gridlayout_buttons[1, 6]; label = "reset view", fontsize = vars[:fontsize])

    # Add the following to separate the buttons (related to axes[:topo]) to the left and the menus (related to axes[:opAn]) to the right
    Makie.Label(gridlayout_buttons[1, 7], ""; tellwidth = false) 

    # Add buttons related to the axResults object (where the optimization results are plotted) 
    #investmentPlan_label    = Makie.Label(gridlayout_buttons[1, 8], "Investment plan:"; halign = :left, fontsize = vars[:fontsize], justification = :left)
    #investmentPlan_menu     = Makie.Menu(gridlayout_buttons[1, 9], halign = :left, width=100, fontsize = vars[:fontsize])
    period_label            = Makie.Makie.Label(gridlayout_buttons[1, 10], "Period:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    period_menu             = Makie.Menu(gridlayout_buttons[1, 11], options = zip(periods_labels, periods), default = periods_labels[1], halign = :left, width=100, fontsize = vars[:fontsize])
    #segment_label           = Makie.Label(gridlayout_buttons[1, 12], "Segment:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    #segment_menu            = Makie.Menu(gridlayout_buttons[1, 13], halign = :left, width=100, fontsize = vars[:fontsize])
    #scenario_label          = Makie.Label(gridlayout_buttons[1, 14], "Scenario:"; halign = :left, fontsize = vars[:fontsize], justification = :left)
    #scenario_menu           = Makie.Menu(gridlayout_buttons[1, 15], halign = :left, width=200, fontsize = vars[:fontsize])
    availableData_label     = Makie.Label(gridlayout_buttons[1, 12], "Available data:"; halign = :right, fontsize = vars[:fontsize], justification = :right)
    availableData_menu      = Makie.Menu(gridlayout_buttons[1, 13], halign = :left, width=300, fontsize = vars[:fontsize])

    # Collect all menus into a dictionary
    buttons::Dict{Symbol, Makie.Button} = Dict(:align_horizontal => align_horizontal_button, 
                                               :align_vertical => align_vertical_button, 
                                               :open => open_button, 
                                               :up => up_button, 
                                               :save => save_button,
                                               :resetView => resetView_button,
                                               )

    # Collect all menus into a dictionary
    menus::Dict{Symbol, Makie.Menu} = Dict(:period => period_menu, 
                                           :availableData => availableData_menu
                                           )

    # Collect all axes into a dictionary
    axes::Dict{Symbol, Makie.Block} = Dict(:topo => ax, 
                                           :opAn => axResults,
                                           :info => axInfo
                                           )

    ## Create the main structure for the EnergyModelsGUI
    gui::GUI = GUI(fig, axes, buttons, menus, root_design, design, model, vars)

    # Update the title of the figure
    topoTitleLocX::Observable{Float64} = Observable(0.0)
    topoTitleLocY::Observable{Float64} = Observable(0.0)
    vars[:topoTitleObj] = text!(ax, topoTitleLocX, topoTitleLocY, text = gui.vars[:title], fontsize = vars[:fontsize])
    updateTitle!(gui)

    # Plot the topology of the root_design variable
    plotDesign!(gui)

    # Update limits based on the location of the nodes
    adjustLimits!(gui)
        
    update!(gui, nothing)

    # Create a function that notifies all components (and thus updates graphics when the observables are notified)
    notifyComponents = () -> begin
        for component ∈ gui.design.components
            notify(component.xy)
        end
    end

    # Update the size of the legend box when the title is updated
    on(gui.vars[:title], priority = 3) do val
        notify(gui.vars[:topoLegend].entrygroups)
    end

    # On zooming, make sure all graphics are adjusted acordingly
    on(gui.axes[:topo].finallimits, priority = 9) do finallimits
        widths::Vec{2, Float32} = finallimits.widths
        origin::Vec{2, Float32} = finallimits.origin
        gui.vars[:xlimits][] = [origin[1], origin[1] + widths[1]]
        gui.vars[:ylimits][] = [origin[2], origin[2] + widths[2]]
        update_distances!(gui)
        notifyComponents()
        topoTitleLocX[] = origin[1] + widths[1]/100
        topoTitleLocY[] = origin[2] + widths[2] - widths[2]/100 - pixel_to_data(gui, gui.vars[:fontsize])[2]
    end

    # If the window is resized, make sure all graphics are adjusted acordingly
    on(gui.fig.scene.events.window_area, priority = 3) do val
        notify(gui.axes[:topo].finallimits)
        adjustLimits!(gui)
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

                        updateSubSystemLocations!(sub_design, Tuple(change))
                    end

                    notifyComponents()
                end
            elseif Int(event.key) == 256 # Esc used to move up a level in the topology
                notify(up_button.clicks)
            elseif Int(event.key) == 32 # Space used to open up a sub-system
                notify(open_button.clicks)
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

    # Handle cases for mousebutton input
    on(events(gui.axes[:topo]).mousebutton, priority = 4) do event
        mouse_pos::Tuple{Float64, Float64} = events(gui.axes[:topo]).mouseposition[]

        plot_origin::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].origin
        plot_widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
        mouse_pos_loc::Vec2{Float64} = mouse_pos .- plot_origin

        # Check if mouseclick is outside the gui.axes[:topo] area (and return if so)
        if any(mouse_pos_loc .< 0.0) || any(mouse_pos_loc .- plot_widths .> 0.0)
            return
        end
        if event.button == Mouse.left
            if event.action == Mouse.press
                if !is_ctrl_pressed[] && !isempty(gui.vars[:selected_systems])
                    clear_selection(gui)
                end

                pickComponent!(gui)
                dragging[] = true
            elseif event.action == Mouse.release
                dragging[] = false
                update!(gui::GUI)
                empty!(gui.vars[:selected_system])

            end
            return Consume(true)
        elseif event.button == Mouse.right
            if event.action == Mouse.press
            #elseif event.action == Mouse.release
            end
        end

        return Consume(false)
    end

    # Handle mouse movement
    on(events(gui.axes[:topo]).mouseposition, priority = 2) do mouse_pos # priority ≥ 2 in order to suppress GLMakie left-click and drag zoom feature
        if dragging[]
            plot_origin::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].origin
            plot_widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
            mouse_pos_loc::Vec2{Float64} = mouse_pos .- plot_origin

            xy_widths::Vec2{Float32} = gui.axes[:topo].finallimits[].widths
            xy_origin::Vec2{Float32} = gui.axes[:topo].finallimits[].origin

            xy::Vec2{Float64} = xy_origin .+ mouse_pos_loc .* xy_widths ./ plot_widths
            if !isempty(gui.vars[:selected_systems]) && gui.vars[:selected_systems][1] isa EnergySystemDesign # Only nodes/area can be moved (connections will update correspondinlgy)
                sub_design::EnergySystemDesign = gui.vars[:selected_systems][1]

                updateSubSystemLocations!(sub_design, Tuple(xy .- sub_design.xy[]))
                sub_design.xy[] = Tuple(xy)
            end
            return Consume(true)
        end

        return Consume(false)
    end
    

    # Align horizontally button: Handle click on the align horizontal button
    on(align_horizontal_button.clicks, priority=10) do clicks
        align(gui, :horizontal)
    end

    # Align vertically button: Handle click on the align vertical button
    on(align_vertical_button.clicks, priority=10) do clicks
        align(gui, :vertical)
    end

    # Open button: Handle click on the open button (open a sub system)
    on(open_button.clicks, priority=10) do clicks
        for component in gui.vars[:selected_systems]
            if component.parent == :TopLevel
                component.parent = haskey(gui.design.system,:name) ? gui.design.system[:name] : :TopLevel
                plotDesign!(gui; visible = false)
                gui.design = component
                plotDesign!(gui; visible = true)
                updateTitle!(gui)
                update_distances!(gui)
                clear_selection(gui)

                notifyComponents()
                notify(resetView_button.clicks)
                break
            end
        end
    end

    # Navigate up button: Handle click on the navigate up button (go back to the root_design)
    on(up_button.clicks, priority=10) do clicks
        if !isnothing(gui.design.parent)
            plotDesign!(gui; visible = false)
            gui.design = root_design
            plotDesign!(gui; visible = true)
            updateTitle!(gui)
            adjustLimits!(gui)
            notifyComponents()
            update_distances!(gui)
        end
    end

    # Save button: Handle click on the save button (save the altered coordinates)
    on(save_button.clicks, priority=10) do clicks
        save_design(gui.design)
    end

    # Reset button: Reset view to the original view
    on(resetView_button.clicks, priority=10) do clicks
        adjustLimits!(gui)
        notify(gui.axes[:topo].finallimits)
    end
    
    # Period menu: Handle menu selection (selecting period)
    on(period_menu.selection, priority=10) do _
        if isempty(gui.vars[:selected_systems])
            updatePlot!(gui, nothing)
        else
            updatePlot!(gui, gui.vars[:selected_systems][end])
        end
    end

    # Available data menu: Handle menu selection (selecting available data)
    on(gui.menus[:availableData].selection, priority=10) do val
        @debug "Changes in available data selection. New val: $val"
        if !isnothing(val)
            labels, _ =  collect(zip(gui.menus[:availableData].options[]...))
            pushfirst!(gui.vars[:availableData_menu_history][], labels[gui.menus[:availableData].i_selected[]])
            if isempty(gui.vars[:selected_systems])
                updatePlot!(gui, nothing)
            else
                updatePlot!(gui, gui.vars[:selected_systems][end])
            end
        end
    end

    # make sure all graphics is adapted to the spawned figure sizes
    notify(pixelarea(gui.axes[:topo].scene))
    update_distances!(gui)

    # display the figure
    display(gui.fig)

    return gui
end

"""
    pixel_to_data(gui::GUI, pixel_size::Real)

Convert pixel size to data widths (in x- and y-direction)
"""
function pixel_to_data(gui::GUI, pixel_size::Real)
    # Calculate the range in data coordinates
    x_range::Float64 = gui.vars[:xlimits][][2] - gui.vars[:xlimits][][1]
    y_range::Float64 = gui.vars[:ylimits][][2] - gui.vars[:ylimits][][1]

    # Get the widths of the axis
    plot_widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths

    # Calculate the conversion factor
    x_factor::Float64 = x_range / plot_widths[1]
    y_factor::Float64 = y_range / plot_widths[2]

    # Convert pixel size to data coordinates
    return (pixel_size * x_factor, pixel_size * y_factor)
end

"""
    update_distances!(gui::GUI)

Find the minimum distance between the nodes in the design object in gui and update Δh such that neighbouring icons do not overlap
"""
function update_distances!(gui::GUI)
    min_d::Float64 = Inf
    for component ∈ gui.design.components
        d::Float64 = minimum([norm(collect(component.xy[] .- component2.xy[])) for component2 ∈ gui.design.components if component != component2])
        if d < min_d
            min_d = d
        end
    end
    gui.vars[:minimum_distance] = min_d
    new_global_delta_h(gui)
end

"""
    new_global_delta_h(gui::GUI)

Recalculate the sizes of the boxes in gui.axes[:topo] such that their size is independent of zooming an resizing the window
"""
function new_global_delta_h(gui::GUI)
    xyWidths::Vec{2, Float32} = gui.axes[:topo].finallimits[].widths
    plot_widths::Vec2{Int64} = pixelarea(gui.axes[:topo].scene)[].widths
    gui.vars[:Δh][] = minimum([minimum(Vector(gui.vars[:Δh_px]*xyWidths./plot_widths)), gui.vars[:minimum_distance]/2])
end

"""
    get_change(::GUI, ::Val)

Handle different keyboard inputs (events) and return changes in x, y coordinates.
"""
get_change(::GUI, ::Val) = (0.0, 0.0)
get_change(gui::GUI, ::Val{Keyboard.up}) = (0.0, +gui.vars[:Δh][] / 5)
get_change(gui::GUI, ::Val{Keyboard.down}) = (0.0, -gui.vars[:Δh][] / 5)
get_change(gui::GUI, ::Val{Keyboard.left}) = (-gui.vars[:Δh][] / 5, 0.0)
get_change(gui::GUI, ::Val{Keyboard.right}) = (+gui.vars[:Δh][] / 5, 0.0)

"""
    align(gui::GUI, type::Symbol)

Align components in `gui.vars[:selected_systems]` either horizontally or vertically.
"""
function align(gui::GUI, type::Symbol)
    xs::Vector{Real} = Real[]
    ys::Vector{Real} = Real[]
    for sub_design ∈ gui.vars[:selected_systems]
        x, y = sub_design.xy[]
        push!(xs, x)
        push!(ys, y)
    end

    # Use the average of the components as the basis of the translated coordinate
    z::Real = if type == :horizontal
        sum(ys) / length(ys)
    elseif type == :vertical
        sum(xs) / length(xs)
    end

    for sub_design ∈ gui.vars[:selected_systems]
        x, y = sub_design.xy[]

        if type == :horizontal
            sub_design.xy[] = (x, z)
        elseif type == :vertical
            sub_design.xy[] = (z, y)
        end
    end
end

"""
    plotDesign!(gui::GUI; visible::Bool = true)

Plot the topology of gui.design (only if not already available), and toggle visibility based on the optional argument `visible`
"""
function plotDesign!(gui::GUI; visible::Bool = true)
    update_distances!(gui)
    if isempty(gui.design.components[1].plotObj)
        for component in gui.design.components
            add_component!(gui,component)
        end
    else
        for component ∈ gui.design.components
            for plotObj ∈ component.plotObj
                plotObj.visible = visible
            end
        end
    end
    if isempty(gui.design.connections[1][3][:plotObj])
        connect!(gui)
    else
        for connection ∈ gui.design.connections
            for plotObjs ∈ connection[3][:plotObj]
                for plotObj ∈ plotObjs[]
                    plotObj.visible = visible
                end
            end
        end
    end
end

"""
    connect!(gui::GUI)

Draws lines between connected nodes/areas in gui.design.
"""
function connect!(gui::GUI)
    # Find optimal placement of label by finding the wall that has the least number of connections
    for component in gui.design.components
        linkedToComponent::Vector{Connection} = filter(x -> component.system[:node].id == x[3][:connection].to.id, gui.design.connections)
        linkedFromComponent::Vector{Connection} = filter(x -> component.system[:node].id == x[3][:connection].from.id, gui.design.connections)
        on(component.xy, priority=4) do _
            angles::Vector{Float64} = vcat(
                [angle(component, linkedComponent[1]) for linkedComponent ∈ linkedToComponent],
                [angle(component, linkedComponent[2]) for linkedComponent ∈ linkedFromComponent]
            ) 
            min_angleDiff::Vector{Float64} = fill(Inf, 4)
            for i ∈ eachindex(min_angleDiff)
                for angle ∈ angles
                    Δθ = angle_difference(angle, (i-1)*π/2)
                    if min_angleDiff[i] > Δθ
                        min_angleDiff[i] = Δθ
                    end
                end
            end
            walls::Vector{Symbol} = [:E, :N, :W, :S]
            component.wall[] = walls[argmax(min_angleDiff)]
        end
        notify(component.xy)
    end
        
    for connection in gui.design.connections
        # Check if link between two nodes goes in both directions (twoWay)
        connectionCon = connection[3][:connection]
        twoWay::Bool = false
        for connection2 in gui.design.connections
            connection2Con = connection2[3][:connection]
            if connection2Con.to.id == connectionCon.from.id &&
                connection2Con.from.id == connectionCon.to.id
                twoWay = true
            end
        end

        # Plot line for connection with decorations
        connect!(gui, connection, twoWay)
    end
end

"""
    connect!(gui::GUI, connection::Tuple{EnergySystemDesign,EnergySystemDesign,Dict}, twoWay::Bool)

Draws lines between connected nodes/areas in gui.design.
"""
function connect!(gui::GUI, connection::Tuple{EnergySystemDesign,EnergySystemDesign,Dict}, twoWay::Bool)

    colors::Vector{RGB} = connection[3][:colors]
    noColors::Int64 = length(colors)

    # Create an arrow to highlight the direction of the energy flow
    l::Float64 = 1.0 # length of the arrow
    t::Float64 = 0.5 # half of the thickness of the arrow
    arrowParts::Vector{Makie.BezierPath} = Vector{Makie.BezierPath}(undef, noColors)
    for i ∈ range(1,noColors)
        arrowParts[i] = Makie.BezierPath([
            Makie.MoveTo(Makie.Point(0, 0)),
            Makie.LineTo(Makie.Point(-l, t*(2*(i-1)/noColors - 1))),
            Makie.LineTo(Makie.Point(-l, t*(2*i/noColors - 1))),
            Makie.ClosePath(),
        ])
    end

    # Allocate and store objects
    lineConnections::Observable{Vector{Any}} = Observable(Vector{Any}(undef, 0))
    halfArrows::Observable{Vector{Any}} = Observable(Vector{Any}(undef, 0))
    push!(connection[3][:plotObj], lineConnections)
    push!(connection[3][:plotObj], halfArrows)

    # Create function to be run on changes in connection[i].xy (for i = 1,2)
    update = () -> begin
        markersizeLengths::Tuple{Float64,Float64} = pixel_to_data(gui, gui.vars[:markersize])
        xy_1::Vector{Real} = collect(connection[1].xy[])
        xy_2::Vector{Real} = collect(connection[2].xy[])

        for i ∈ 1:length(lineConnections[])
            lineConnections[][i].visible = false
        end
        for i ∈ 1:length(halfArrows[])
            halfArrows[][i].visible = false
        end

        lines_shift::Tuple{Float64,Float64} = pixel_to_data(gui, gui.vars[:connectionLinewidth]) .+ pixel_to_data(gui, gui.vars[:line_sep_px])
        twoWay_sep::Tuple{Float64,Float64} = pixel_to_data(gui, gui.vars[:twoWay_sep_px][])
        θ::Float64 = atan(xy_2[2]-xy_1[2], xy_2[1]-xy_1[1])
        cosθ::Float64 = cos(θ)
        sinθ::Float64 = sin(θ)
        cosϕ::Float64 = -sinθ # where ϕ = θ+π/2
        sinϕ::Float64 = cosθ

        Δ::Float64 = gui.vars[:Δh][]/2 # half width of a box
        if !isempty(connection[1].components)
            Δ *= gui.vars[:parentScaling]
        end

        for j ∈ 1:noColors
            xy_start::Vector{Float64} = copy(xy_1)
            xy_end::Vector{Float64} = copy(xy_2)
            xy_midpoint::Vector{Float64} = copy(xy_2)
            if twoWay
                xy_start[1]   += (twoWay_sep[1]/2 + lines_shift[1]*(j-1))*cosϕ
                xy_start[2]   += (twoWay_sep[2]/2 + lines_shift[2]*(j-1))*sinϕ
                xy_end[1]     += (twoWay_sep[1]/2 + lines_shift[1]*(j-1))*cosϕ
                xy_end[2]     += (twoWay_sep[2]/2 + lines_shift[2]*(j-1))*sinϕ
                xy_midpoint[1] += (twoWay_sep[1]/2 + lines_shift[1]*(noColors-1)/2)*cosϕ
                xy_midpoint[2] += (twoWay_sep[2]/2 + lines_shift[2]*(noColors-1)/2)*sinϕ
            end
            xy_start = squareIntersection(xy_1, xy_start, θ, Δ)
            xy_end = squareIntersection(xy_2, xy_end, θ+π, Δ)
            xy_midpoint = squareIntersection(xy_2, xy_midpoint, θ+π, Δ)
            parm::Float64 = -xy_start[1]*cosθ - xy_start[2]*sinθ + xy_midpoint[1]*cosθ + xy_midpoint[2]*sinθ - minimum(markersizeLengths)
            xs::Vector{Float64} = [xy_start[1], parm*cosθ + xy_start[1]]
            ys::Vector{Float64} = [xy_start[2], parm*sinθ + xy_start[2]]
                
            if length(halfArrows[]) < j
                sctr = scatter!(gui.axes[:topo], xy_midpoint[1], xy_midpoint[2], marker = arrowParts[j], markersize = gui.vars[:markersize], rotations = θ, color=colors[j])
                lns = lines!(gui.axes[:topo], xs, ys; color = colors[j], linewidth = gui.vars[:connectionLinewidth], linestyle = get_style(gui,connection))
                Makie.translate!(sctr, 0,0,1001)
                Makie.translate!(lns, 0,0,1000)
                push!(halfArrows[], sctr)
                push!(lineConnections[], lns)
            else
                halfArrows[][j][1][] = [Point{2, Float32}(xy_midpoint[1], xy_midpoint[2])]
                halfArrows[][j][:rotations] = θ
                halfArrows[][j].visible = true
                lineConnections[][j][1][] = [Point{2, Float32}(x, y) for (x, y) in zip(xs, ys)]
                lineConnections[][j].visible = true
            end
        end
    end

    # If components changes position, so must the connections
    for component in connection[1:2]
        on(component.xy, priority = 3) do _
            if component.plotObj[1].visible[]
                update()
            end
        end
    end
end

"""
    add_component!(gui::GUI, component::EnergySystemDesign)

Draw a box containing the icon and add a label with the id of the component with its type in parantheses
"""
function add_component!(gui::GUI, component::EnergySystemDesign)
    draw_box!(gui, component)
    draw_icon!(gui, component)
    draw_label!(gui, component)
end

"""
    get_style(gui::GUI, system::Dict)

Get the line style for an `EnergySystemDesign` object `system` based on its system properties.   
"""
function get_style(gui::GUI, system::Dict)
    if haskey(system,:node) && hasproperty(system[:node],:data)
        system_data = system[:node].data
        for data_element in eachindex(system_data)
            thistype = string(typeof(system_data[data_element]))
            if thistype == "InvData"
                return gui.vars[:investment_lineStyle]
            end
        end
    
    elseif haskey(system,:connection) && hasproperty(system[:connection],:modes)
        system_modes = system[:connection].modes
        for mode in eachindex(system_modes)
            this_mode = system_modes[mode]
            if hasproperty(this_mode,:data)
                system_data = this_mode.data
                for data_element in eachindex(system_data)
                    thistype = string(typeof(system_data[data_element]))
                    if thistype == "TransInvData"
                        return gui.vars[:investment_lineStyle]
                    end
                end
            end
        end
    end

    return :solid
end

"""
    get_style(gui::GUI, design::EnergySystemDesign)

Get the line style for an `EnergySystemDesign` object `design` based on its system properties.   
"""
get_style(gui::GUI, design::EnergySystemDesign) = get_style(gui, design.system)

"""
    get_style(gui::GUI, design::Connection)

Get the line style for an `Connection` object `connection` based on wheter it is part of an investment or not
"""
function get_style(gui::GUI, connection::Connection)
    style::Union{Symbol, Makie.Linestyle} = get_style(gui, connection[1])
    if style == gui.vars[:investment_lineStyle]
        return style
    end
    return get_style(gui, connection[2])
end

"""
    draw_box!(gui::GUI, design::EnergySystemDesign)

Draw a box for `design` and it's appearance, including style, color, size. 
"""
function draw_box!(gui::GUI, design::EnergySystemDesign)

    xo::Observable{Vector{Real}} = Observable(zeros(5))
    yo::Observable{Vector{Real}} = Observable(zeros(5))
    vertices::Vector{Tuple{Real,Real}} = [(x, y) for (x, y) in zip(xo[][1:end-1], yo[][1:end-1])]
    whiteRect = Observable(Makie.GeometryBasics.HyperRectangle{2, Int64})

    whiteRect = poly!(gui.axes[:topo], vertices, color=:white,strokewidth=0) # Create a white background rectangle to hide lines from connections
    Makie.translate!(whiteRect, 0,0,1004)
    push!(design.plotObj, whiteRect)

    # Observe changes in design coordinates and update box position
    on(design.xy, priority = 3) do val
        x::Real = val[1]
        y::Real = val[2]

        xo[], yo[] = box(x, y, gui.vars[:Δh][]/2)
        whiteRect[1] = [(x, y) for (x, y) in zip(xo[][1:end-1], yo[][1:end-1])]
    end

    style::Union{Symbol,Makie.Linestyle} = get_style(gui, design)

    # if the design has components, draw an enlarged box around it. 
    if !isempty(design.components)
        xo2::Observable{Vector{Real}} = Observable(zeros(5))
        yo2::Observable{Vector{Real}} = Observable(zeros(5))
        vertices2::Vector{Tuple{Real,Real}} = [(x, y) for (x, y) in zip(xo2[][1:end-1], yo2[][1:end-1])]
        
        whiteRect2 = poly!(gui.axes[:topo], vertices2, color=:white,strokewidth=0) # Create a white background rectangle to hide lines from connections
        Makie.translate!(whiteRect2, 0,0,1001)
        push!(design.plotObj, whiteRect2)

        # observe changes in design coordinates and update enlarged box position
        on(design.xy, priority = 3) do val
            x = val[1]
            y = val[2]

            xo2[], yo2[] = box(x, y, gui.vars[:Δh][]/2 * gui.vars[:parentScaling])
            whiteRect2[1] = [(x, y) for (x, y) in zip(xo2[][1:end-1], yo2[][1:end-1])]
        end


        boxBoundary2 = lines!(gui.axes[:topo], xo2, yo2; color = design.color, linewidth=gui.vars[:linewidth],linestyle = style)
        Makie.translate!(boxBoundary2, 0,0,1002)
        push!(design.plotObj, boxBoundary2)
    end

    boxBoundary = lines!(gui.axes[:topo], xo, yo; color = design.color, linewidth=gui.vars[:linewidth],linestyle = style)
    Makie.translate!(boxBoundary, 0,0,1005)
    push!(design.plotObj, boxBoundary)
end

"""
    draw_icon!(gui::GUI, design::EnergySystemDesign)

Draw an icon for `design`
"""
function draw_icon!(gui::GUI, design::EnergySystemDesign)
    xo::Observable{Vector{Real}} = Observable([0.0,0.0])
    yo::Observable{Vector{Real}} = Observable([0.0,0.0])
    on(design.xy, priority = 3) do val
        x::Real = val[1]
        y::Real = val[2]

        xo[] = [x - gui.vars[:Δh][] * gui.vars[:icon_scale]/2, x + gui.vars[:Δh][] * gui.vars[:icon_scale]/2]
        yo[] = [y - gui.vars[:Δh][] * gui.vars[:icon_scale]/2, y + gui.vars[:Δh][] * gui.vars[:icon_scale]/2]
    end

    if isempty(design.icon) # No path to an icon has been found
        node::Union{EMB.Node, EMG.Area} = if typeof(design.system[:node]) <: EMG.Area
            design.system[:node].node
        else
            design.system[:node] 
        end

        colorsInput::Vector{RGB} = getResourceColors(EMB.inputs(node), design.idToColorMap)
        colorsOutput::Vector{RGB} = getResourceColors(EMB.outputs(node), design.idToColorMap)
        type::Symbol = node isa EMB.Source ? :rect : :circle
        for (j, colors) ∈ enumerate([colorsInput, colorsOutput])
            noColors::Int64 = length(colors)
            for (i, color) ∈ enumerate(colors)
                θᵢ::Float64 = 0
                θᵢ₊₁::Float64 = 0
                if node isa EMB.NetworkNode # contains both input and output: Divide disc into two (left side for input and right side for output)
                    θᵢ = (-1)^(j+1)*π/2 + π*(i-1)/noColors
                    θᵢ₊₁ = (-1)^(j+1)*π/2 + π*i/noColors
                else
                    θᵢ = 2π*(i-1)/noColors
                    θᵢ₊₁ = 2π*i/noColors
                end
                sector = getSectorPoints()

                networkPoly = poly!(gui.axes[:topo], sector, color=color)
                Makie.translate!(networkPoly, 0,0,2000)
                push!(design.plotObj, networkPoly)
                on(design.xy, priority = 3) do c
                    Δ = gui.vars[:Δh][] * gui.vars[:icon_scale]/2
                    sector = getSectorPoints(;c, Δ, θ₁ = θᵢ, θ₂ = θᵢ₊₁, type = type)
                    networkPoly[1][] = sector
                end
            end
        end

        if node isa EMB.NetworkNode
            # Add a vertical white separation line to distinguis input resources from output resources
            separationLine = lines!(gui.axes[:topo],[0.0,1.0],[0.0,1.0],color=:white,linewidth=gui.vars[:Δh_px]/25)
            Makie.translate!(separationLine, 0,0,2001)
            push!(design.plotObj, separationLine)
            on(design.xy, priority = 3) do center
                radius = gui.vars[:Δh][] * gui.vars[:icon_scale]/2
                separationLine[1][] = Vector{Point{2, Float32}}([[center[1], center[2]-radius], [center[1], center[2]+radius]])
            end
        end
    else
        @debug "$(design.icon)"
        icon_image = image!(gui.axes[:topo], xo, yo, rotr90(load(design.icon)))
        Makie.translate!(icon_image, 0,0,2000)
        push!(design.plotObj, icon_image)
    end
end

"""
    draw_label!(gui::GUI, component::EnergySystemDesign)

Add a label to a component
"""
function draw_label!(gui::GUI, component::EnergySystemDesign)

    xo = Observable(0.0)
    yo = Observable(0.0)
    alignment = Observable((:left, :top))

    scale = 0.7

    on(component.xy, priority = 3) do val

        x = val[1]
        y = val[2]

        if component.wall[] == :E
            xo[] = x + gui.vars[:Δh][] * scale
            yo[] = y
        elseif component.wall[] == :S
            xo[] = x
            yo[] = y - gui.vars[:Δh][] * scale
        elseif component.wall[] == :W
            xo[] = x - gui.vars[:Δh][] * scale
            yo[] = y
        elseif component.wall[] == :N
            xo[] = x
            yo[] = y + gui.vars[:Δh][] * scale
        end
        alignment[] = get_text_alignment(component.wall[])

    end
    if haskey(component.system,:node)
        label_text = text!(gui.axes[:topo], xo, yo; text = "$(string(component.system[:node]))\n($(nameof(typeof(component.system[:node]))))", align = alignment, fontsize=gui.vars[:fontsize])
        Makie.translate!(label_text, 0,0,2001)
        push!(component.plotObj, label_text)
    end
end

"""
    clear_selection(gui::GUI)

Clear the color selection of components within 'gui.design' instance and to reset the `gui.vars[:selected_systems]` variable 
"""
function clear_selection(gui::GUI)
    for selection in gui.vars[:selected_systems]
        if selection isa EnergySystemDesign
            toggleSelectionColor!(gui, selection, false)
        else
            toggleSelectionColor!(gui, selection, false)
        end
    end
    empty!(gui.vars[:selected_systems])
end

"""
    adjustLimits!(gui::GUI)

Adjust the limits of gui.axes[:topo] based on its content
"""
function adjustLimits!(gui::GUI)
    min_x, max_x, min_y, max_y = find_min_max_coordinates(gui.design)
    Δ_lim_x = max_x-min_x
    Δ_lim_y = max_y-min_y
    min_x -= Δ_lim_x*gui.vars[:boundary_add]
    max_x += Δ_lim_x*gui.vars[:boundary_add]
    min_y -= Δ_lim_y*gui.vars[:boundary_add]
    max_y += Δ_lim_y*gui.vars[:boundary_add]
    Δ_lim_x = max_x-min_x
    Δ_lim_y = max_y-min_y
    x_center = (min_x+max_x)/2
    y_center = (min_y+max_y)/2
    if Δ_lim_y > Δ_lim_x
        Δ_lim_x =  Δ_lim_y*gui.vars[:axAspectRatio]
    else Δ_lim_y < Δ_lim_x
        Δ_lim_y =  Δ_lim_x/gui.vars[:axAspectRatio]
    end
    min_x = x_center - Δ_lim_x/2
    max_x = x_center + Δ_lim_x/2
    min_y = y_center - Δ_lim_y/2
    max_y = y_center + Δ_lim_y/2
    gui.vars[:xlimits][] = [min_x, max_x]
    gui.vars[:ylimits][] = [min_y, max_y]
    limits!(gui.axes[:topo], gui.vars[:xlimits][], gui.vars[:ylimits][])

    gui.axes[:topo].autolimitaspect = nothing # Fix the axis limits (needed to avoid resetting limits when adding objects along connection lines upon zoom)
end

"""
    updateTitle!(gui::GUI)

Update the title of `gui.axes[:topo]` based on `gui.design`
"""
function updateTitle!(gui::GUI)
    gui.vars[:title][] = if isnothing(gui.design.parent)
        "TopLevel"
    else
        "$(gui.design.parent).$(gui.design.system[:node])"
    end
end

"""
    toggleSelectionColor!(gui::GUI, selection::EnergySystemDesign, selected::Bool)

Set the color of selection to `gui.vars[:selection_color]` if selected, and its original color otherwise
"""
function toggleSelectionColor!(gui::GUI, selection::EnergySystemDesign, selected::Bool)
    if selected
        selection.color[] = gui.vars[:selection_color]
    else
        selection.color[] = :black
    end
end

"""
    toggleSelectionColor!(gui::GUI, plotObjs::Vector{Any}, selected::Bool)

Set the color of selection to `gui.vars[:selection_color]` if selected, and its original color otherwise
"""
function toggleSelectionColor!(gui::GUI, selection::Dict{Symbol,Any}, selected::Bool)
    if selected
        for plotObj ∈ selection[:plotObj]
            for plotObj_sub ∈ plotObj[]
                plotObj_sub.color = gui.vars[:selection_color]
            end
        end
    else
        colors::Vector{RGB} = selection[:colors]
        noColors::Int64 = length(colors)
        for plotObj ∈ selection[:plotObj]
            for (i, plotObj_sub) ∈ enumerate(plotObj[])
                plotObj_sub.color = colors[((i-1) % noColors) + 1]
            end
        end
    end
end

"""
    pickComponent!(gui::GUI)

Check if a system is found under the mouse pointer is an `EnergySystemDesign` and update state variables
"""
function pickComponent!(gui::GUI)
    plt, _ = pick(gui.axes[:topo])

    if isnothing(plt)
        empty!(gui.vars[:selected_systems])
        empty!(gui.vars[:selected_system])
    else
        # Loop through the design to find if the object under the pointer matches any of the object link to any of the components
        for component ∈ gui.design.components
            for plotObj ∈ component.plotObj
                if plotObj === plt || plotObj === plt.parent || plotObj === plt.parent.parent
                    toggleSelectionColor!(gui, component, true)
                    push!(gui.vars[:selected_systems], component)
                    push!(gui.vars[:selected_system], component)
                    @info "Node $(component.system[:node]) selected"
                    return
                end
            end
        end

        # Update the variables selections with the current selection
        for connection ∈ gui.design.connections
            for plotObj ∈ connection[3][:plotObj]
                for plotObj_sub ∈ plotObj[]
                    if plotObj_sub === plt || plotObj_sub === plt.parent || plotObj_sub === plt.parent.parent
                        selection::Dict{Symbol,Any} = connection[3]
                        toggleSelectionColor!(gui, selection, true)
                        push!(gui.vars[:selected_systems], selection)
                        push!(gui.vars[:selected_system], selection)
                        @info "Connection $(selection[:connection]) selected"
                        return
                    end
                end
            end
        end
    end
end

"""
    update!(gui::GUI)

Upon release of left mouse button update plots
"""
function update!(gui::GUI)
    selected_system = gui.vars[:selected_system]
    updateplot = !isempty(selected_system)

    if updateplot
        update!(gui, selected_system[1], updateplot = updateplot)
        gui.vars[:prev_selection] = selected_system
    else
        if isempty(gui.vars[:selected_systems])
            update!(gui, nothing; updateplot = updateplot)
        else
            update!(gui, gui.vars[:selected_systems][end]; updateplot = updateplot)
        end
    end
end

"""
    update!(gui::GUI, node::Plotable; updateplot::Bool = true)

Based on `node`, update the text in `gui.axes[:info]` and update plot in `gui.axes[:opAn]` if `updateplot = true`
"""
function update!(gui::GUI, node::Plotable; updateplot::Bool = true)
    updateInfoBox!(gui, node)
    updateAvailableDataMenu!(gui,node)
    if updateplot
        updatePlot!(gui, node)
    end
end

"""
    update!(gui::GUI, connection::Dict{Symbol, Any}; updateplot::Bool = true)

Based on `connection[:connection]`, update the text in `gui.axes[:info]` and update plot in `gui.axes[:opAn]` if `updateplot = true`
"""
function update!(gui::GUI, connection::Dict{Symbol, Any}; updateplot::Bool = true)
    update!(gui, connection[:connection]; updateplot)
end

"""
    update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool = true)

Based on `design.system[:node]`, update the text in `gui.axes[:info]` and update plot in `gui.axes[:opAn]` if `updateplot = true`
"""
function update!(gui::GUI, design::EnergySystemDesign; updateplot::Bool = true)
    update!(gui, design.system[:node]; updateplot)
end

"""
    updateAvailableDataMenu!(gui::GUI, node::Plotable)

Update the `gui.menus[:availableData]` with the available data of `node`.
"""
function updateAvailableDataMenu!(gui::GUI, node::Plotable)
    # Find appearances of node/area/link/transmission in the model
    availableData = Vector{Dict}(undef,0)
    if !isempty(gui.model) # Plot results if available
        for dict ∈ collect(keys(object_dictionary(gui.model))) 
            if typeof(gui.model[dict]) <: JuMP.Containers.DenseAxisArray
                if any([eltype(a) <: Union{EMB.Node, EMG.Area} for a in axes(gui.model[dict])]) # nodes/areas found in structure 
                    if node ∈ gui.model[dict].axes[1] # only add dict if used by node (assume node are located at first Dimension)
                        if length(axes(gui.model[dict])) > 2
                            for res ∈ gui.model[dict].axes[3]
                                push!(availableData, Dict(:name => dict, :isJuMPdata => true, :selection => [node, res]))
                            end
                        else
                            push!(availableData, Dict(:name => dict, :isJuMPdata => true, :selection => [node]))
                        end
                    end
                elseif any([eltype(a) <: EMG.TransmissionMode for a in axes(gui.model[dict])]) # nodes found in structure 
                    if node isa EMG.Transmission
                        for mode ∈ node.modes 
                            push!(availableData, Dict(:name => dict, :isJuMPdata => true, :selection => [mode])) # do not include node (<: EMG.Transmission) here as the mode is unique to this transmission
                        end
                        
                    end
                elseif isnothing(node)
                    if length(axes(gui.model[dict])) > 1
                        for res ∈ gui.model[dict].axes[2]
                            push!(availableData, Dict(:name => dict, :isJuMPdata => true, :selection => [res]))
                        end
                    else
                        push!(availableData, Dict(:name => dict, :isJuMPdata => true, :selection => EMB.Node[]))
                    end
                end
            elseif typeof(gui.model[dict]) <: JuMP.Containers.SparseAxisArray
                if any([typeof(x) <: Union{EMB.Node, EMB.Link, EMG.Area} for x in first(gui.model[dict].data)[1]]) # nodes/area/links found in structure
                    if !isnothing(node)
                        extractCombinations!(availableData, dict, node, gui.model)
                    end
                elseif isnothing(node)
                    extractCombinations!(availableData, dict, node, gui.model)
                end
            end
        end
    end

    # Add timedependent input data (if available)
    if !isnothing(node)
        for fieldName ∈ fieldnames(typeof(node))
            field = getfield(node, fieldName)

            if typeof(field) <: TS.TimeProfile
                push!(availableData, Dict(:name => fieldName, :isJuMPdata => false, :selection => [node]))
            elseif field isa Dict
                for (dictname, dictvalue) ∈ field
                    if typeof(dictvalue) <: TS.TimeProfile
                        push!(availableData, Dict(:name => "$fieldName.$dictname", :isJuMPdata => false, :selection => [node]))
                    end
                end
            elseif field isa Vector{<:EMG.TransmissionMode}
                for mode ∈ field
                    for mode_fieldName ∈ fieldnames(typeof(mode))
                        mode_field = getfield(mode, mode_fieldName)
                        if typeof(mode_field) <: TS.TimeProfile
                            push!(availableData, Dict(:name => "$mode_fieldName", :isJuMPdata => false, :selection => [mode]))
                        end
                    end
                end
            end
        end
    end
    availableData_strings::Vector{String} = createLabel.(availableData)

    gui.menus[:availableData].options = zip(availableData_strings, availableData)

    # Make sure an option is selected if the menu is altered
    if isnothing(gui.menus[:availableData].selection[]) && !isempty(gui.menus[:availableData].options[])
        labels, _ =  collect(zip(gui.menus[:availableData].options[]...))
        lastViableLabelIndex = nothing
        for label ∈ gui.vars[:availableData_menu_history][]
            lastViableLabelIndex = findfirst(isequal(label), labels)
            if !isnothing(lastViableLabelIndex)
                break
            end
        end
        if !isnothing(lastViableLabelIndex)
            gui.menus[:availableData].i_selected[] = lastViableLabelIndex
        elseif isnothing(node) || length(gui.menus[:availableData].options[]) == 1
            gui.menus[:availableData].i_selected[] = 1
        end 
    end
end

"""
    getData(model::JuMP.Model, selection::Dict{Symbol, Any}, T::TS.TimeStructure, period::TS.StrategicPeriod)

Get the values from the JuMP `model` or the input data for at `selection` for all times `T` restricted to `period`
"""
function getData(model::JuMP.Model, selection::Dict, T::TS.TimeStructure, period::TS.StrategicPeriod)
    if selection[:isJuMPdata] # Model results
        return getJuMPvalues(model, selection[:name], selection[:selection], T, period)
    else
        if '.' ∈ String(selection[:name])
            colon_index = findfirst(isequal('.'), selection[:name])
            field = selection[:name][1:colon_index-1]
            field_sub = selection[:name][colon_index+1:end]
            fieldData = getfield(selection[:selection][1], Symbol(field))[Symbol(field_sub)]
        else
            fieldData = getfield(selection[:selection][1], Symbol(selection[:name]))
        end
        x_values, xIsStrategicPeriod = getTimeValues(T, typeof(fieldData), period)
        if :vals ∈ fieldnames(typeof(fieldData))
            if fieldData isa TS.StrategicProfile
                y_values = fieldData.vals[period.sp].vals
            else
                y_values = fieldData.vals
            end
        elseif :val ∈ fieldnames(typeof(fieldData))
            y_values = [fieldData.val]
        else
            @error "Could not extract y-data from structure"
        end
        return x_values, y_values, xIsStrategicPeriod
    end
end

"""
    getJuMPvalues(model::JuMP.Model, dict::Symbol, selection::Vector{Any}, T::TS.TimeStructure, period::TS.StrategicPeriod)

Get the values from the JuMP `model` for dictionary `dict` at `selection` for all times `T` restricted to `period`
"""
function getJuMPvalues(model::JuMP.Model, dict::Symbol, selection::Vector, T::TS.TimeStructure, period::TS.StrategicPeriod)
    i_T, type = getTimeAxis(model[dict])
    x_values, xIsStrategicPeriod = getTimeValues(T, type, period)
    y_values::Vector{Float64} = if xIsStrategicPeriod
        [value(model[dict][vcat(selection[1:i_T-1], t, selection[i_T:end])...]) for t ∈ TS.strat_periods(T)]
    else
        [value(model[dict][vcat(selection[1:i_T-1], t, selection[i_T:end])...]) for t ∈ T if t.sp == period.sp]
    end
    return x_values, y_values, xIsStrategicPeriod
end

"""
    getTimeValues(T::TS.TimeStructure, type::DataType)

Get the time values for a given time type (TS.StrategicPeriod or TS.OperationalPeriod)
"""
function getTimeValues(T::TS.TimeStructure, type::DataType, period::TS.StrategicPeriod)
    xIsStrategicPeriod = type <: TS.StrategicPeriod
    if xIsStrategicPeriod
        return [t.sp for t ∈ TS.strat_periods(T)], xIsStrategicPeriod
    else
        return [t.period.op for t ∈ T if t.sp == period.sp], xIsStrategicPeriod
    end
end

"""
    getTimeAxis(data::Union{JuMP.Containers.DenseAxisArray, JuMP.Containers.SparseAxisArray})

Get the index of the axis/column corresponding to TS.TimePeriod and return the specific type
"""
function getTimeAxis(data::Union{JuMP.Containers.DenseAxisArray, JuMP.Containers.SparseAxisArray})
    types::Vector{DataType} = collect(getJumpAxisTypes(data))
    i_T::Union{Int64, Nothing} = findfirst(x -> x <: TS.TimePeriod, types)
    if isnothing(i_T)
        return i_T, nothing
    else
        return i_T, types[i_T]
    end
end

"""
    getJumpAxisTypes(data::JuMP.Containers.DenseAxisArray)

Get the types for each axis in the Jump container DenseAxisArray
"""
function getJumpAxisTypes(data::JuMP.Containers.DenseAxisArray)
    return eltype.(axes(data))
end

"""
    getJumpAxisTypes(data::JuMP.Containers.SparseAxisArray)

Get the types for each column in the Jump container SparseAxisArray
"""
function getJumpAxisTypes(data::JuMP.Containers.SparseAxisArray)
    return typeof.(first(data.data)[1])
end

"""
    createLabel(selection::Vector{Any})

Return a label for a given selection to be used in the gui.menus[:availableData] menu
"""
function createLabel(selection::Dict{Symbol, Any})
    label::String = selection[:isJuMPdata] ? "" : "Input data: "
    label *= string(selection[:name])
    otherRes::Bool = false
    if length(selection) > 1
        for select ∈ selection[:selection]
            if !(select isa Plotable)
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
    updatePlot!(gui::GUI, node)

Based on `node` update the results in `gui.axes[:opAn]`
"""
function updatePlot!(gui::GUI, node::Plotable)
    T = gui.root_design.system[:T]
    selection = gui.menus[:availableData].selection[]
    if !isnothing(selection)
        xlabel = "Time"
        ylabel = string(selection[:name])
        period = gui.menus[:period].selection[]

        x_values, y_values, xIsStrategicPeriod = getData(gui.model, selection, T, period)

        label::String = createLabel(selection)
        if !isnothing(node)
            label *= " for $node"
        end 
        if xIsStrategicPeriod
            xlabel *= " (StrategicPeriod)"
        else
            xlabel *= " (OperationalPeriod)"
            label *= " for strategic period $period"
        end

        if xIsStrategicPeriod
            points = [Point{2, Float64}(x, y) for (x, y) ∈ zip(x_values,y_values)]
        else
            x_valuesStep, y_valuesStep = stepify(vec(x_values),vec(y_values))
            points = [Point{2, Float64}(x, y) for (x, y) ∈ zip(x_valuesStep,y_valuesStep)]
        end
        plotObjs = gui.axes[:opAn].scene.plots
        i_plot::Int64 = xIsStrategicPeriod ? 1 : 2
        if length(plotObjs) < 1
            @debug "First plot generated"
            barplot!(gui.axes[:opAn], points, strokecolor = :black, strokewidth = 1)
            lines!(gui.axes[:opAn], points)
        else
            @debug "Updating results plot"
            plotObjs[1][1][] = points
            plotObjs[2][1][] = points
            delete!(gui.vars[:opAnLegend])
        end
        gui.vars[:opAnLegend] = axislegend(gui.axes[:opAn], [plotObjs[i_plot]], [label], labelsize = gui.vars[:fontsize]) # Add legends inside axes[:opAn] area
        plotObjs[1].visible = xIsStrategicPeriod
        plotObjs[2].visible = !xIsStrategicPeriod
        @debug "Creating legend"
        gui.axes[:opAn].xlabel = xlabel
        gui.axes[:opAn].ylabel = ylabel
        autolimits!(gui.axes[:opAn])
        reset_limits!(gui.axes[:opAn])
        yorigin::Float32 = gui.axes[:opAn].finallimits[].origin[2]
        ywidth::Float32 = gui.axes[:opAn].finallimits[].widths[2]
        ylims!(gui.axes[:opAn], yorigin, yorigin + ywidth*1.1) # ensure that the legend box does not overlap the data
    end
end

"""
    updatePlot!(gui::GUI, design::EnergySystemDesign)

Based on `connection[:connection]` update the results in `gui.axes[:opAn]`
"""
function updatePlot!(gui::GUI, connection::Dict{Symbol,Any})
    updatePlot!(gui, connection[:connection])
end

"""
    updatePlot!(gui::GUI, design::EnergySystemDesign)

Based on `design.system[:node]` update the results in `gui.axes[:opAn]`
"""
function updatePlot!(gui::GUI, design::EnergySystemDesign)
    updatePlot!(gui, design.system[:node])
end

"""
    updateInfoBox!(gui::GUI, node; indent::Int64 = 0)

Based on `node` update the text in `gui.axes[:info]`
"""
function updateInfoBox!(gui::GUI, node; indent::Int64 = 0)
    infoBox = gui.axes[:info].scene.plots[1][1]
    if isnothing(node)
        infoBox[] = gui.vars[:defaultText]
        return
    end
    if indent == 0
        infoBox[] =  "$node ($(typeof(node)))\n"
    end
    indent += 1
    indent_str = "  " ^ indent
    isIterable(x) = x isa Vector || x isa Dict || typeof(x) <: EMB.Node || typeof(x) <: EMB.Resource
    if node isa Vector
        for (i,field1) ∈ enumerate(node)
            if isIterable(field1)
                infoBox[] *= indent_str * "$i: $(typeof(field1)):\n"
                updateInfoBox!(gui, field1; indent)
            else
                infoBox[] *= indent_str * "$i: $(typeof(field1))\n"
            end
        end
    elseif node isa Dict
        for field1 ∈ keys(node)
            infoBox[] *= indent_str * "$field1 => $(node[field1])\n"
        end
    else
        for field1 ∈ fieldnames(typeof(node))
            value1 = getfield(node,field1)
            if isIterable(value1)
                infoBox[] *= indent_str * "$(field1) ($(typeof(value1))):\n"
                updateInfoBox!(gui, value1; indent)
            else
                infoBox[] *= indent_str * "$(field1): $value1\n"
            end
        end
    end
end