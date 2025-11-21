case, _ = generate_example_ss()
gui = GUI(case)

# Test specific miscellaneous functionalities
@testset "Test functionality" verbose = true begin
    # Test print functionalities of GUI structures to the REPL
    @testset "Test Base.show() functions" begin
        design = EMGUI.get_design(gui)
        component = EMGUI.get_components(design)[1]
        connection = EMGUI.get_connections(design)[1]
        @test Base.show(gui) == dump(gui; maxdepth = 1)
        @test Base.show(design) == dump(design; maxdepth = 1)
        @test Base.show(component) == dump(component; maxdepth = 1)
        @test Base.show(connection) == dump(connection; maxdepth = 1)

        inv_data = EMGUI.get_inv_data(design)
        @test Base.show(inv_data) == dump(inv_data; maxdepth = 1)

        system = EMGUI.parse_case(case)
        @test Base.show(system) == dump(system; maxdepth = 1)
    end
end
