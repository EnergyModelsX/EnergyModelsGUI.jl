const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const EMG = EnergyModelsGeography
const EMRP = EnergyModelsRenewableProducers
const EMH2 = EnergyModelsHydrogen
const EMH = EnergyModelsHeat
const EMC = EnergyModelsCO2

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
            :structures => Dict(
                :EnergyModelsGeography => Dict( # Input parameter from the case Dict
                    :RefStatic => Dict(:trans_cap => str1, :opex_fixed => str2),
                    :RefDynamic => Dict(:opex_var => str3, :directions => str4),
                ),
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
        descriptive_names_EMG = descriptive_names[:structures][:EnergyModelsGeography]
        @test descriptive_names_EMG[:RefStatic][:trans_cap] == str1
        @test descriptive_names_EMG[:RefStatic][:opex_fixed] == str2
        @test descriptive_names_EMG[:RefDynamic][:opex_var] == str3
        @test descriptive_names_EMG[:RefDynamic][:directions] == str4
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

        desc_raw_EMB = descriptive_names_raw[:structures][:EnergyModelsBase]
        @test desc_raw_EMB[:Node][:opex_fixed] == str1
        @test :StorCapOpexFixed ∉ keys(desc_raw_EMB)
        @test :RefNetworkNode ∉ keys(desc_raw_EMB)

        desc_raw_EMRP = descriptive_names_raw[:structures][:EnergyModelsRenewableProducers]
        @test desc_raw_EMRP[:HydroStorage][:level_init] == str2
        @test :HydroStor ∉ keys(desc_raw_EMRP)
        @test :PumpedHydroStor ∉ keys(desc_raw_EMRP)

        descriptive_names = EMGUI.get_var(gui3, :descriptive_names)
        desc_EMB = descriptive_names[:structures][:EnergyModelsBase]
        @test desc_EMB[:StorCapOpexFixed][:opex_fixed] == str1
        @test desc_EMB[:RefNetworkNode][:opex_fixed] == str1

        desc_EMRP = descriptive_names[:structures][:EnergyModelsRenewableProducers]
        @test desc_EMRP[:HydroStorage][:level_init] == str2
        @test desc_EMRP[:PumpedHydroStor][:level_init] == str2
        EMGUI.close(gui3)
    end

    @testset "Test existence of descriptive names for all available EMX-packages" begin
        # Check that no descriptive names are empty for types
        descriptive_names = create_descriptive_names()
        types_map =
            get_descriptive_names([EMB, EMI, EMG, EMRP, EMH2, EMH, EMC], descriptive_names)
        @test !any(any(isempty.(values(a))) for a ∈ values(types_map))

        # Check that no warnings are logged when running a full case
        @test_logs min_level=Logging.Error case, _, m, gui = run_all_in_one_case()

        # Check that no descriptive names are empty for variables
        variables_map = get_descriptive_names(m, descriptive_names)
        @test !any(any(isempty.(values(a))) for a ∈ values(variables_map))
    end
end
EMGUI.close(gui)
