case, _ = generate_example_ss()
gui = GUI(case)

# Test specific miscellaneous functionalities
@testset "Test functionality" verbose = true begin
    # Test print functionalities of GUI structures to the REPL
    @testset "Test Base.show() functions" begin
        design = EMGUI.get_design(gui)
        component = EMGUI.get_components(design)[1]
        component_element = EMGUI.get_element(component)
        connection = EMGUI.get_connections(design)[1]
        connection_element = EMGUI.get_element(connection)
        @test Base.show(gui) == dump(gui; maxdepth = 1)
        @test Base.show(design) == Base.show(gui)
        @test Base.show(component) == Base.show(component_element)
        @test Base.show(connection) == Base.show(connection_element)

        inv_data = EMGUI.get_inv_data(design)
        @test Base.show(inv_data) == dump(inv_data; maxdepth = 1)

        system = EMGUI.parse_case(case)
        @test Base.show(system) == Base.show(design)
    end
end
