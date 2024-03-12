using EnergyModelsGUI
using Test

"""
    run_through_all(gui::GUI)

Loop through all components of gui.root_design and display all available data
"""
function run_through_all(gui::GUI)
    @info "Running through all components"
    run_through_all(gui, gui.root_design)
end

"""
    run_through_all(gui::GUI, design::EnergySystemDesign)

Loop through all components of design and display all available data
"""
function run_through_all(gui::GUI, design::EnergySystemDesign)
    for component ∈ design.components
        empty!(gui.vars[:selected_systems])
        push!(gui.vars[:selected_systems], component)
        notify(gui.buttons[:open].clicks) # Open component
        
        if isempty(component.components) # no sub system found
            update!(gui)
            for i_selected ∈ 1:length(gui.menus[:availableData].options[])
                gui.menus[:availableData].i_selected = i_selected # Select flow_out (CO2)
                #sleep(0.1)
            end
        else
            run_through_all(gui, component)
        end
    end
    for connection ∈ design.connections
        empty!(gui.vars[:selected_systems])
        push!(gui.vars[:selected_systems], connection[3])
        notify(gui.buttons[:open].clicks) # Open component
        update!(gui)
        for i_selected ∈ 1:length(gui.menus[:availableData].options[])
            gui.menus[:availableData].i_selected = i_selected # Select flow_out (CO2)
            #sleep(0.1)
        end
    end
end

@testset "EnergyModelsGUI.jl" begin
    ## The following tests simply checks if the main examples can be run without errors

    # EnergyModelsBase examples
    @test begin
        include("../examples/EMB_network.jl")
        run_through_all(gui)
        true
    end
    @test begin
        include("../examples/EMB_sink_source.jl")
        run_through_all(gui)
        true
    end

    # EnergyModelsGeography example
    @test begin
        include("../examples/EMG_network.jl")
        run_through_all(gui)
        true
    end

    # EnergyModelsInvestment examples
    @test begin
        include("../examples/EMI_network.jl")
        run_through_all(gui)
        true
    end
    @test begin
        include("../examples/EMI_sink_source.jl")
        run_through_all(gui)
        true
    end
    @test begin
        include("../examples/EMI_geography.jl")
        component = gui.root_design.components[2] # fetch the Bergen area
        push!(gui.vars[:selected_systems], component) # Select Bergen
        notify(gui.buttons[:open].clicks) # Open Bergen area
        sub_component = gui.design.components[2] # fetch the RefNetworkNode used for investment
        push!(gui.vars[:selected_systems], sub_component) # Manually add to :selected_systems
        update!(gui)
        availableData = [x[1] for x in collect(gui.menus[:availableData].options[])]
        i_selected = findfirst(x -> x == "Output flowrate (flow_out) (CO2)", availableData)
        gui.menus[:availableData].i_selected = i_selected # Select flow_out (CO2)
        axisTimeType = gui.menus[:time].selection[]
        value = gui.axes[axisTimeType].scene.plots[1][1][][10][2]
        println("Value is $value")
        notify(gui.buttons[:up].clicks) # navigate back to top level
        run_through_all(gui)
        value ≈ 6.378697 # Check a value (flow_out (CO2)) plotted at axes[:opAn]
    end

    # EnergyModulesRenewableProducers examples
    @test begin
        include("../examples/EMR_simple_nondisres.jl")
        run_through_all(gui)
        true
    end
    @test begin
        include("../examples/EMR_hydro_power.jl")
        run_through_all(gui)
        true
    end
end
