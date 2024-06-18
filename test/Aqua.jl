using Aqua

@testset "Aqua.jl" begin
    Aqua.test_ambiguities(EnergyModelsGUI)
    Aqua.test_unbound_args(EnergyModelsGUI)
    Aqua.test_undefined_exports(EnergyModelsGUI)
    Aqua.test_project_extras(EnergyModelsGUI)
    Aqua.test_stale_deps(EnergyModelsGUI)
    Aqua.test_deps_compat(EnergyModelsGUI)
    Aqua.test_piracies(EnergyModelsGUI)
    Aqua.test_persistent_tasks(EnergyModelsGUI)
end
