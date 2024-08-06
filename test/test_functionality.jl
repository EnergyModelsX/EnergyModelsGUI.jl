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

    @testset "Test customizing descriptive names" begin
        path_to_descriptive_names = joinpath(@__DIR__, "..", "src", "descriptive_names.yml")
        str1 = "<a test description 1>"
        str2 = "<a test description 2>"
        str3 = "<a test description 3>"
        str4 = "<a test description 4>"
        str5 = "<a test description 5>"
        str6 = "<a test description 6>"
        descriptive_names_dict = Dict(
            :structures => Dict( # Input parameter from the case Dict
                :RefStatic => Dict(:trans_cap => str1, :opex_fixed => str2),
                :RefDynamic => Dict(:opex_var => str3, :directions => str4),
            ),
            :variables => Dict( # variables from the JuMP model
                :stor_discharge_use => str5,
                :trans_cap_rem => str6,
            ),
        )
        gui = GUI(
            case;
            path_to_descriptive_names=path_to_descriptive_names,
            descriptive_names_dict=descriptive_names_dict,
        )
        descriptive_names = get_var(gui, :descriptive_names)
        @test descriptive_names[:structures][:RefStatic][:trans_cap] == str1
        @test descriptive_names[:structures][:RefStatic][:opex_fixed] == str2
        @test descriptive_names[:structures][:RefDynamic][:opex_var] == str3
        @test descriptive_names[:structures][:RefDynamic][:directions] == str4
        @test descriptive_names[:variables][:stor_discharge_use] == str5
        @test descriptive_names[:variables][:trans_cap_rem] == str6
    end
end
