using EnergyModelsGUI
using Test

design_path::String = joinpath(@__DIR__, "..", "design") # folder where visualization info is saved and retrieved
runOptimization::Bool = true # Set runOptimization boolean to run optimization or not

@testset "EnergyModelsGUI.jl" begin
    # The following tests simply checks if the main examples can be run without errors
    @test begin
        include("../examples/generate_EMB_sink_source.jl")
        gui = EnergyModelsGUI.GUI(case; design_path, idToColorMap, idToIconMap, model = m)
        true
    end
    @test begin
        include("../examples/generate_EMB.jl")
        gui = EnergyModelsGUI.GUI(case; design_path, idToColorMap, idToIconMap, model = m)
        true
    end
    @test begin
        include("../examples/generate_EMG.jl")
        gui = EnergyModelsGUI.GUI(case; design_path, idToColorMap, idToIconMap, model = m)
        true
    end
    @test begin
        include("../examples/generate_EMI.jl")
        gui = EnergyModelsGUI.GUI(case; design_path, idToColorMap, idToIconMap, model = m)
        component = gui.root_design.components[2] # fetch the Bergen area
        push!(gui.vars[:selected_systems], component) # Select Bergen
        notify(gui.buttons[:open].clicks) # Open Bergen area
        sub_component = gui.design.components[2] # fetch the RefNetworkNode used for investment
        push!(gui.vars[:selected_systems], sub_component) # Manually add to :selected_systems
        push!(gui.vars[:selected_system], sub_component) # Manually add to :selected_system
        EnergyModelsGUI.update!(gui)
        availableData = [x[1] for x in collect(gui.menus[:availableData].options[])]
        i_selected = findfirst(x -> x == "flow_out (CO2)", availableData)
        gui.menus[:availableData].i_selected = i_selected # Select flow_out (CO2)
        println("Value is $(gui.axes[:opAn].scene.plots[2][1][][10][2])")
        gui.axes[:opAn].scene.plots[2][1][][10][2] ≈ 6.378697 # Check a value (flow_out (CO2)) plotted at axes[:opAn]
    end
end
