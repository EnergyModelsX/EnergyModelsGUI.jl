# [Customize icons](@id customize_icons)

EnergyModelsGUI provides a set of colors for a set of frequently used `Resource`-`id`s. These can be found in `src/colors.toml`. If you have a `Resource` with another `id` or you want to alter the default colors, you need to specify the `idToIconMap` option in the `GUI` function. Say that you want to specify default icons for the types `Source`, `NetworkNode` and `Sink`, and you want to have a special icon for the node with `id` `7`, then simply do the following
```julia
const EMB = EnergyModelsBase
idToIconMap = Dict(
    EMB.Source => "Source", 
    EMB.NetworkNode => "Network", 
    EMB.Sink => "Sink", 
    7 => "factoryEmissions"
)

# Update idToIconMap with full paths for the icons
idToIconMap = set_icons(idToIconMap)

gui = GUI(case; idToIconMap);
```
If the string provided is a full path to a .png file the GUI will use this file. If the string is simply the name of the file (without the .png ending) as above, the GUI will first look for a file in a folder `../icons`. If it is not provided here, it will look in the `ext/EnergyModelsGUI/icons/` folder in the EMX repositories. If the icon is not found here either, it will fall back to the default icon generation (based on simple shapes like circle for `Sink`s and squares for `Source`s and colored by input/output colors).