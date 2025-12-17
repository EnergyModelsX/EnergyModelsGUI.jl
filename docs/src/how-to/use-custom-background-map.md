# [Use custom backgruond map](@id how_to-use_custom_backgruond_map)

The GUI enables user defined background maps in `.geojson` format through the `GUI` constructor parameter `String::map_boundary_file`. One could for example download NUTS boundaries as GeoJSON from [datahub.io](https://datahub.io/core/geo-nuts-administrative-boundaries), save this file at a desired location and use this file path as `map_boundary_file`.

Downloading [NUTS2](https://r2.datahub.io/clt98mkvt000ql70811z8xj6l/main/raw/data/NUTS_RG_60M_2024_4326_LEVL_2.geojson), one can with a EMX-case variable `case`

```julia
gui = GUI(case; map_boundary_file = joinpath(@__DIR__, "NUTS_RG_60M_2024_4326_LEVL_2.geojson"))
```

get something like

![NUTS2 illustration](../figures/NUTS2_illustration.png)
