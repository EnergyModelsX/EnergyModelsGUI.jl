@testset "CSV utilities" begin
    # Simplified function for testing
    function test_pers(opers, pers_dict)
        @test isempty(setdiff(repr.(opers), keys(pers_dict)))
        @test isempty(setdiff(opers, values(pers_dict)))
    end

    # Test for SimpleTimes
    ts_opers = SimpleTimes(4, 1)
    pers_dict = EMGUI.get_all_periods(ts_opers)
    test_pers(collect(ts_opers), pers_dict)
    @test length(pers_dict) == 4

    # Test for OperationalScenarios
    ts_oscs = OperationalScenarios(2, ts_opers)
    pers_dict = EMGUI.get_all_periods(ts_oscs)
    test_pers(collect(ts_oscs), pers_dict)
    test_pers(opscenarios(ts_oscs), pers_dict)
    @test length(pers_dict) == (4 + 1) * 2

    # Test for RepresentativePeriods{SimpleTimes}
    ts_rp = RepresentativePeriods(2, 8760, ts_opers)
    pers_dict = EMGUI.get_all_periods(ts_rp)
    test_pers(collect(ts_rp), pers_dict)
    test_pers(repr_periods(ts_rp), pers_dict)
    @test length(pers_dict) == (4 + 1) * 2

    # Test for RepresentativePeriods{OperationalScenarios}
    ts_rp_oscs = RepresentativePeriods(2, 8760, ts_oscs)
    pers_dict = EMGUI.get_all_periods(ts_rp_oscs)
    test_pers(collect(ts_rp_oscs), pers_dict)
    test_pers(opscenarios(ts_rp_oscs), pers_dict)
    test_pers(repr_periods(ts_rp_oscs), pers_dict)
    @test length(pers_dict) == ((4 + 1) * 2 + 1) * 2

    # Test for TwoLevel{SimpleTimes}
    ts_tl = TwoLevel(2, 1, ts_opers)
    pers_dict = EMGUI.get_all_periods(ts_tl)
    test_pers(collect(ts_tl), pers_dict)
    test_pers(strat_periods(ts_tl), pers_dict)
    @test length(pers_dict) == (4 + 1) * 2

    # Test for TwoLevel{OperationalScenarios}
    ts_tl_oscs = TwoLevel(2, 1, ts_oscs)
    pers_dict = EMGUI.get_all_periods(ts_tl_oscs)
    test_pers(collect(ts_tl_oscs), pers_dict)
    test_pers(opscenarios(ts_tl_oscs), pers_dict)
    test_pers(strat_periods(ts_tl_oscs), pers_dict)
    @test length(pers_dict) == ((4 + 1) * 2 + 1) * 2

    # Test for TwoLevel{RepresentativePeriods}
    ts_tl_rp = TwoLevel(2, 1, ts_rp)
    pers_dict = EMGUI.get_all_periods(ts_tl_rp)
    test_pers(collect(ts_tl_rp), pers_dict)
    test_pers(repr_periods(ts_tl_rp), pers_dict)
    test_pers(strat_periods(ts_tl_rp), pers_dict)
    @test length(pers_dict) == ((4 + 1) * 2 + 1) * 2

    # Test for TwoLevel{RepresentativePeriods{OperationalScenarios}}
    ts_tl_rp_oscs = TwoLevel(2, 1, ts_rp_oscs)
    pers_dict = EMGUI.get_all_periods(ts_tl_rp_oscs)
    test_pers(collect(ts_tl_rp_oscs), pers_dict)
    test_pers(opscenarios(ts_tl_rp_oscs), pers_dict)
    test_pers(repr_periods(ts_tl_rp_oscs), pers_dict)
    test_pers(strat_periods(ts_tl_rp_oscs), pers_dict)
    @test length(pers_dict) == (((4 + 1) * 2 + 1) * 2 + 1) * 2
end
