# [Customize icons](@id how_to-cust_icons)

EnergyModelsGUI provides default icon generation for `Node`s and `Area`s, but these "icons" can be customized by the users.
You can define an icon based on a `Node` `id` or by types.
To do this you need to specify the `id_to_icon_map` option in the `GUI` function.

Say that you want to specify default icons for the types `Source`, `NetworkNode` and `Sink`, and you want to have a special icon for the `Node` with `id` `7`, then simply do the following

```julia
const EMB = EnergyModelsBase
id_to_icon_map = Dict(
    EMB.Source => "Source",
    EMB.NetworkNode => "Network",
    EMB.Sink => "Sink",
    7 => "factory_emissions"
)

# Update id_to_icon_map with full paths for the icons
id_to_icon_map = set_icons(id_to_icon_map)

gui = GUI(case; id_to_icon_map=id_to_icon_map);
```

If the string provided is a full path to a .png file, the GUI will use this file.
If the string is simply the name of the file (without the .png ending) as above, the GUI will first look for a file in a folder `../icons`.
If it is not provided here, it will look in the `ext/EMGUIExt/icons/` folder in the EMX repositories.
If the icon is not found here either, it will fall back to the default icon generation mentioned earlier (based on simple shapes like circle for `Sink`s and squares for `Source`s and colored by input/output colors).
