# Internals

## Index
```@index
Pages = ["reference.md"]
```

## Types
```@autodocs
Modules = [EnergyModelsGUI]
Public = false
Order = [:type]
```

## Methods
```@autodocs
Modules = [EnergyModelsGUI]
Public = false
Order = [:function]
```

## Update Methods
```@docs
EnergyModelsGUI.update!(::GUI, ::Union{Nothing, EnergyModelsBase.Link, EnergyModelsBase.Node, EnergyModelsGeography.Area, EnergyModelsGeography.Transmission})
EnergyModelsGUI.update!(::GUI, ::Dict{Symbol, Any})
EnergyModelsGUI.update!(::GUI, ::EnergySystemDesign)
```