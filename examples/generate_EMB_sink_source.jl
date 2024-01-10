using EnergyModelsBase
using JuMP
using HiGHS
using TimeStruct

function generate_data()
    @info "Generate case data"

    # Define the different resources
    Power = ResourceCarrier("Power", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)
    products = [Power, CO2]

    # Define colors for all products
    products_color = ["Electricity", "ResourceEmit"]
    EnergyModelsGUI.setColors!(idToColorsMap, products, products_color)

    # Creation of a dictionary with entries of 0 for all resources for the availability node
    # to be able to create the links for the availability node.
    𝒫₀ = Dict(k => 0 for k ∈ products)

    # Creation of a dictionary with entries of 0 for all emission resources
    # This dictionary is normally used as usage based non-energy emissions.
    𝒫ᵉᵐ₀ = Dict(k => 0.0 for k ∈ products if typeof(k) == ResourceEmit{Float64})
    𝒫ᵉᵐ₀[CO2] = 0.0

    # Create the individual test nodes, corresponding to a system with an electricity demand/sink,
    # coal and nautral gas sources, coal and natural gas (with CCS) power plants and CO2 storage.
    nodes = [
        RefSource(2, FixedProfile(1e12), FixedProfile(30),
            FixedProfile(0), Dict(Power => 1),
            []),
        RefSink(7, OperationalProfile([20 30 40 30]),
            Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(1e6)),
            Dict(Power => 1)),
    ]
    idToIconsMap[nodes[1].id] = "hydroPowerPlant"
    idToIconsMap[nodes[2].id] = "factoryEmissions"

    # Connect all nodes with the availability node for the overall energy/mass balance
    links = [
        Direct(12, nodes[1], nodes[2], Linear())
    ]

    # Creation of the time structure and global data
    T = TwoLevel(4, 1, SimpleTimes(4, 2))
    model = OperationalModel(Dict(CO2 => FixedProfile(10)), CO2)

    # WIP data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )
    return case, model
end


case, model = generate_data()