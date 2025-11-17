case, model, m, gui = run_case()

# Test specific miscellaneous descriptive names
@testset "Test descriptive names" verbose = true begin

    @testset "Test customizing descriptive names" begin
        path_to_descriptive_names = joinpath(pkgdir(EMGUI), "src", "descriptive_names.yml")
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
        gui2 = GUI(
            case;
            path_to_descriptive_names = path_to_descriptive_names,
            descriptive_names_dict = descriptive_names_dict,
        )
        descriptive_names = EMGUI.get_var(gui2, :descriptive_names)
        @test descriptive_names[:structures][:RefStatic][:trans_cap] == str1
        @test descriptive_names[:structures][:RefStatic][:opex_fixed] == str2
        @test descriptive_names[:structures][:RefDynamic][:opex_var] == str3
        @test descriptive_names[:structures][:RefDynamic][:directions] == str4
        @test descriptive_names[:variables][:stor_discharge_use] == str5
        @test descriptive_names[:variables][:trans_cap_rem] == str6
        EMGUI.close(gui2)
    end

    @testset "Test inheritance of descriptive names" begin
        path_to_descriptive_names = joinpath(pkgdir(EMGUI), "src", "descriptive_names.yml")
        descriptive_names_raw =
            YAML.load_file(path_to_descriptive_names; dicttype = Dict{Symbol,Any})
        str1 = "Relative fixed operating expense per installed capacity"
        str2 = "Initial stored energy in the dam"
        gui3 = GUI(
            case;
            path_to_descriptive_names = path_to_descriptive_names,
        )

        @test descriptive_names_raw[:structures][:Node][:opex_fixed] == str1
        @test :StorCapOpexFixed ∉ keys(descriptive_names_raw[:structures])
        @test :RefNetworkNode ∉ keys(descriptive_names_raw[:structures])

        @test descriptive_names_raw[:structures][:HydroStorage][:level_init] == str2
        @test :HydroStor ∉ keys(descriptive_names_raw[:structures])
        @test :PumpedHydroStor ∉ keys(descriptive_names_raw[:structures])

        descriptive_names = EMGUI.get_var(gui3, :descriptive_names)
        @test descriptive_names[:structures][:StorCapOpexFixed][:opex_fixed] == str1
        @test descriptive_names[:structures][:RefNetworkNode][:opex_fixed] == str1

        @test descriptive_names[:structures][:HydroStor][:level_init] == str2
        @test descriptive_names[:structures][:PumpedHydroStor][:level_init] == str2
        EMGUI.close(gui3)
    end
end
