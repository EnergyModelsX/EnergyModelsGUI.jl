using ModelingToolkit
using ModelingToolkit: value
using Plots
using JuMP
using Makie
GLMakie.activate!()

# Define the nodes and location
@parameters t

#@variable n1(t), n2(t), n3(t), S1(t) # not working on my system
#
case, model = generate_data()

#case[:links][1]

model = Model()


# Later we can get the data from "case" dictionary
nodes = ["n1","n2","n3","n4","n5","n6","n7"]#case[:nodes]#[n1,n2,n3,n4,n5,n6,n7]
activityNode = "A1"
links = Dict(
    "l1" => ["n1"],
    "l2" => ["n2"],
    "l3" => ["n3"],
    "l4" => ["n4"],
    "l5" => ["n5"],
    "l6" => ["n6"],
    "l7" => ["n7"]
)


# Connect the nodes to the  Activity Node
connections = Dict(node => activityNode for node in nodes)
for (link, connected_nodes) in links
    for node in connected_nodes
        connections[node] = activityNode
    end
end

# Print the connections
for (node, connected_location) in connections
    println("Node $node is connected to $connected_location.")
end

# Create a Figure
fig = Figure()

# Create the nodes
node_positions = Dict(node => (i, 0) for (i, node) in enumerate(nodes))
node_positions[activityNode] = (length(nodes) + 1, 0)

scene = Scene()

# Create  the scatter plot for nodes
node_plot = scatter!(scene, [pos[1] for pos in values(node_positions)],
                     [pos[2] for pos in values(node_positions)],
                     markersize = 10,
                     color = :lightblue,
                     label = ["$node" for node in keys(node_positions)],
                     legend = true)

# Connect the nodes with links
for (link, connected_nodes) in links
    for node in connected_nodes
        link_start = node_positions[node]
        link_end = node_positions[activityNode]
        linesegments!(scene, [link_start[1], link_end[1]],
                      [link_start[2], link_end[2]],
                      color = :black,
                      linewidth = 2,
                      linestyle = :solid)
    end
end

# Define the interaction
on(node_plot.pick, MouseButton.left) do picked
    selected_node = node_plot[picked].seriesnames[1]
    println("Selected Node: $selected_node")
end

# Set the aspect ratio and labels
scene.aspect = DataAspect()
scene.xlabel = "X"
scene.ylabel = "Y"

# Show the plot
display(scene)