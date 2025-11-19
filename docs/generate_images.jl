using CairoMakie
using YAML
import EnergyModelsGUI:
    get_vars,
    get_menu,
    get_button,
    get_root_design,
    get_components,
    get_component,
    get_selected_systems,
    get_name,
    update!,
    toggle_selection_color!,
    select_data!

include(joinpath(@__DIR__, "..", "examples", "generate_examples.jl"))

"""
    create_colors_visualization_image()

Create an image for the available colors based on the colors.yml file to be used in docs.
"""
function create_colors_visualization_image()
    colors = YAML.load_file(joinpath(@__DIR__, "..", "src", "colors.yml"))

    # Prepare data for plotting
    colors_name = collect(keys(colors))
    y_positions = 1:length(colors_name)

    markersize = 40
    width = 250
    height = markersize * length(colors_name)

    # Create the figure
    fig = Figure(size = (width, height))

    ax = Axis(
        fig[1, 1],
        yticks = (y_positions, colors_name),
        ygridvisible = false,
        xgridvisible = false,
        backgroundcolor = :white,
        width = markersize * 5 / 4,    # Adjust the width of the axis to match the box size
        height = height,  # Ensure enough height for all boxes,
    )
    ax.xlabelvisible = false
    ax.ylabelvisible = false
    ax.xticklabelsvisible = false
    ax.xticksvisible = false
    ax.yticksvisible = false
    ax.topspinevisible = false
    ax.bottomspinevisible = false
    ax.leftspinevisible = false
    ax.rightspinevisible = false

    # Plot each color
    for (i, (name, color)) ∈ enumerate(colors)
        scatter!(ax, [0.5], [i], markersize = markersize, marker = :rect, color = color)
    end

    # Save the figure
    save(joinpath(@__DIR__, "src", "figures", "colors_visualization.png"), fig)
end

"""
    create_EMI_geography_images()

Create figures of the GUI based on the EMI_geography.jl example to be used for docs and README.md.
"""
function create_EMI_geography_images()
    case, model = generate_example_data_geo()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    m = create_model(case, model)
    set_optimizer(m, optimizer)
    optimize!(m)

    solution_summary(m)

    # Set folder where visualization info is saved and retrieved
    design_path = joinpath(@__DIR__, "design", "EMI", "geography")

    # Run the GUI
    gui = GUI(
        case;
        design_path,
        model = m,
        coarse_coast_lines = false,
        scale_tot_opex = true,
        scale_tot_capex = false,
    )

    # Create examples.png image
    path_to_results = joinpath(@__DIR__, "src", "figures")
    get_vars(gui)[:path_to_results] = path_to_results
    get_menu(gui, :axes).selection[] = "All"
    get_menu(gui, :export_type).selection[] = "png"
    export_button = get_button(gui, :export)
    open_button = get_button(gui, :open)
    notify(export_button.clicks)
    mv(
        joinpath(path_to_results, "All.png"),
        joinpath(path_to_results, "example.png"),
        force = true,
    )

    # Create EMI_geography.png image
    oslo_area = get_component(get_root_design(gui), 1)
    push!(get_selected_systems(gui), oslo_area) # Manually add to :selected_systems
    update!(gui)
    toggle_selection_color!(gui, oslo_area, true)
    select_data!(gui, "area_exchange")
    notify(export_button.clicks)
    mv(
        joinpath(path_to_results, "All.png"),
        joinpath(path_to_results, "EMI_geography.png"),
        force = true,
    )

    # Create EMI_geography_Oslo.png image
    notify(open_button.clicks)
    sub_component = get_component(oslo_area, 5) # fetch node id 5 in Oslo area
    selected_systems = get_selected_systems(gui)
    empty!(selected_systems)
    push!(selected_systems, sub_component) # Manually add to :selected_systems
    update!(gui)
    toggle_selection_color!(gui, sub_component, true)
    select_data!(gui, "cap_add")
    notify(export_button.clicks)
    mv(
        joinpath(path_to_results, "All.png"),
        joinpath(path_to_results, "EMI_geography_Oslo.png"),
        force = true,
    )
end

# generate images
create_colors_visualization_image()
create_EMI_geography_images()
