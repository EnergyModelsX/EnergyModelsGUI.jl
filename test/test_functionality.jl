# Test specific miscellaneous functionalities
@testset "Test functionality" verbose = true begin
    # Test GUI functionalities with the case7 example
    include("../examples/case7.jl")

    # Test print functionalities of GUI structures to the REPL
    @testset "Test Base.show() functions" begin
        println(gui)
        design = EMGUI.get_design(gui)
        println(design)
        components = EMGUI.get_components(design)
        connections = EMGUI.get_connections(design)
        println(components[1])
        println(connections[1])
        @test true
    end
end
