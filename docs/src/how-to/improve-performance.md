# [Improve performance](@id how_to-improve_performance)

Due to the just-in-time (JIT) compilation of Julia, the instantiation of the `EnergyModelsGUI` window takes some time (but reopening the windo will take less time) and this also includes interactive features in the GUI (plotting a plot over `OperationalPeriod`s is a lot faster compared to the first plot).

That being said, it is possible to boost startup time by turning of redundant features. 
One can for example plot sub-areas only on demand (which for large system significantly reduces setup of the `GUI`) through 

```julia
gui = GUI(case; pre_plot_sub_components = false)
```

If there is no need to use the background map when using `EnergyModelsGeography` one can skip the usage of `GeoMakie` (this will also increase performance)

```julia
gui = GUI(case; use_geomakie = false)
```

If the user do not see any usage of the `DataInspector` tool provided by `Makie` (which enables information of plot objects upon hovering with the mouse) one could use the `enable_data_inspector` toogle to further improve performance

```julia
gui = GUI(case; enable_data_inspector = false)
```

It is also possible to use a simplified plotting of the `Link`s/`Transmission`s using the `simplified_connection_plotting` which improves performance slightly. 
This option is however more motivated by simplified visuals. 
One can also use `simplify_all_levels` to have this simplified plotting on all levels (not just the top level).

```julia
gui = GUI(case; simplified_connection_plotting = true, simplify_all_levels = true)
```