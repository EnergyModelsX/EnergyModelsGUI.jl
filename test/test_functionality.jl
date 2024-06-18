# Test specific miscellaneous functionalities
@testset "Test functionality" verbose = true begin
    # Test GUI functionalities with the case7 example
    include("../examples/case7.jl")

    # Test print functionalities of GUI structures to the REPL
    @testset "Test Base.show() functions" begin
        println(gui)
        println(gui.design)
        println(gui.design.components[1])
        println(gui.design.connections[1])
        @test true
    end
end
