using CairoMakie
using YAML

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
    fig = Figure(resolution=(width, height))

    ax = Axis(
        fig[1, 1],
        yticks=(y_positions, colors_name),
        ygridvisible=false,
        xgridvisible=false,
        backgroundcolor=:white,
        width=markersize * 5 / 4,    # Adjust the width of the axis to match the box size
        height=height,  # Ensure enough height for all boxes,
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
        scatter!(ax, [0.5], [i], markersize=markersize, marker=:rect, color=color)
    end

    # Save the figure
    save(joinpath(@__DIR__, "src", "figures", "colors_visualization.png"), fig)
end

"""
    create_EMI_geography_images()

Create figures of the GUI based on the EMI_geography.jl example to be used for docs and README.md
"""
function create_EMI_geography_images()
    include(joinpath(@__DIR__, "..", "examples", "EMI_geography.jl"))

    # Create examples.png image
    gui.vars[:path_to_results] = joinpath(@__DIR__, "src", "figures")
    gui.menus[:axes].selection[] = "All"
    gui.menus[:export_type].selection[] = "png"
    notify(gui.buttons[:export].clicks)
    mv(
        joinpath(gui.vars[:path_to_results], "All.png"),
        joinpath(gui.vars[:path_to_results], "example.png"),
        force=true,
    )

    # Create EMI_geography.png image
    sub_component = gui.root_design.components[1] # fetch the Oslo area
    push!(gui.vars[:selected_systems], sub_component) # Manually add to :selected_systems
    EMGUI.update!(gui)
    EMGUI.toggle_selection_color!(gui, sub_component, true)
    available_data = [x[2][:name] for x ∈ collect(gui.menus[:available_data].options[])]
    i_selected = findfirst(x -> x == "area_exchange", available_data)
    gui.menus[:available_data].i_selected = i_selected # Select flow_out (CO2)
    notify(gui.buttons[:export].clicks)
    mv(
        joinpath(gui.vars[:path_to_results], "All.png"),
        joinpath(gui.vars[:path_to_results], "EMI_geography.png"),
        force=true,
    )

    # Create EMI_geography_Oslo.png image
    notify(gui.buttons[:open].clicks)
    sub_component = gui.root_design.components[1].components[2] # fetch the Oslo area
    empty!(gui.vars[:selected_systems])
    push!(gui.vars[:selected_systems], sub_component) # Manually add to :selected_systems
    EMGUI.update!(gui)
    EMGUI.toggle_selection_color!(gui, sub_component, true)
    available_data = [x[2][:name] for x ∈ collect(gui.menus[:available_data].options[])]
    i_selected = findfirst(x -> x == "cap_add", available_data)
    gui.menus[:available_data].i_selected = i_selected # Select flow_out (CO2)
    notify(gui.buttons[:export].clicks)
    mv(
        joinpath(gui.vars[:path_to_results], "All.png"),
        joinpath(gui.vars[:path_to_results], "EMI_geography_Oslo.png"),
        force=true,
    )
end

# generate images
create_colors_visualization_image()
create_EMI_geography_images()
