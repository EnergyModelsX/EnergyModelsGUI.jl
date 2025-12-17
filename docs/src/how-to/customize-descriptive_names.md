# [Customize descriptive_names](@id how_to-cust_desc_names)

`EnergyModelsGUI` provides a set of descriptive names for case input structures and assosiated JuMP variables.
These can be found in `src/descriptive_names.yml`. These descriptions are extended/overwritten with EMX
packages having a `descriptive_names.yml` file in a `ext/EMGUIExt` folder of its repository (having a module 
name starting with `EnergyModel`). That is, if you want to provide descriptive names for your EMX package, 
add a `.yml` file in this location, with the same structure as `src/descriptive_names.yml`.

It can be convenient to provide a user defined file in addition.
If you have this file located at `path_to_descriptive_names`, simply add it using

```julia
gui = GUI(case; path_to_descriptive_names=path_to_descriptive_names)
```

If you instead (or in addition) want to provide descriptive names through a `Dict`, this can be done as follows

```julia
descriptive_names_dict = Dict(
    :structures => Dict( # Input parameter from the case Dict
        :EnergyModelsGeography => Dict( # Input parameter from the case Dict
            :RefStatic => Dict(
                :trans_cap => "New description for `trans_cap`",
                :opex_fixed => "New description for `opex_fixed`",
            ),
            :RefDynamic => Dict(
                :opex_var => "New description for `opex_var`",
                :directions => "New description for `directions`",
            ),
        ),
    ),
    :variables => Dict( # variables from the JuMP model
        :stor_discharge_use => "New description for `stor_discharge_use`",
        :trans_cap_rem => "New description for `trans_cap_rem`",
    ),
)
gui = GUI(
    case;
    descriptive_names_dict=descriptive_names_dict,
)
```

The variables for `total` quantities (and their descriptions) can be customized in the same manner (see structure in the `src/descriptive_names.yml` file).

It is also possible to ignore certain `JuMP` variables.
As an example, `cap_use` and `flow_in` (in addition to the variable `con_em_tot` which is ignored by default) can be ignored through:

```julia
gui = GUI(
    case;
    model=m,
    path_to_descriptive_names=path_to_descriptive_names,
    descriptive_names_dict=Dict(:ignore => ["con_em_tot", "cap_use", "flow_in"]),
)
```

You can similarly customize variables that indicate an investment has occured through the values of the key `:investment_indicators` in the keyword argument `descriptive_names_dict`.
The default variables are which indicate investments are

- ``\texttt{cap\_add}`` for all nodes except for [`Storage`](@extref EnergyModelsBase.Storage),
- ``\texttt{stor\_level\_add}`` for all  [`Storage`](@extref EnergyModelsBase.Storage) nodes,
- ``\texttt{stor\_charge_\_add}`` for all  [`Storage`](@extref EnergyModelsBase.Storage) nodes with charge capacity,
- ``\texttt{stor\_discharge\_add}`` for all  [`Storage`](@extref EnergyModelsBase.Storage) nodes with discharge capacity, and
- ``\texttt{trans\_cap\_add}`` for all transmission modes.
