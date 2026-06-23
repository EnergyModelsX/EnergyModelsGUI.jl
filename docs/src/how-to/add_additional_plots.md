# [Add Additional Plots](@id how_to-add_additional_plots)

Use the `additional_plots` keyword in the [`GUI(::Case; kwargs...)`](@ref) constructor to add external time series (or other indexed series) in the results axis, alongside model data.

The `additional_plots` keyword argument accepts a vector of dictionaries. Each dictionary defines one additional plot source:

- `"data"` (**required**):  
  - a `DataFrame`, or  
  - a path to a CSV file.
- `"normalize"` (*optional*, default `false`):  
  If `true`, the series is scaled before plotting, which is useful for shape comparisons with model results.

The time index of the additional data must match the time index of the model results. The time index column must be named one of the following `t`, `sp`, `rp`, `osc`, `op`. If this column is missing, an `OperationalProfile` will be created for the additional data (where the time index is inferred based on the row order to match the time structure of the model case), and a warning will be issued.

## Example

Assuming you have a CSV file with additional time series data located at `path/to/your/data.csv`, for example with content

```csv
sp,val1,val2
sp1,0.5,0.6
sp2,0.6,0.7
sp3,0.7,0.8
sp4,0.8,0.9
```

you can load it into the GUI as follows:

```julia
using EnergyModelsGUI

gui = GUI(case; additional_plots=[Dict("data"=>"path/to/your/data.csv", "normalize"=>true)])
```

Adding a data frame directly is also possible, for example (assuming the time index is `sp1-t1`, `sp1-t2`, ..., `sp1-t10`):

```julia
using EnergyModelsGUI, DataFrames

t = "sp1-t" .* string.(1:10)
additional_data = DataFrame(t=t, series1=rand(10), series2=rand(10))
gui = GUI(case; additional_plots=[
        Dict("data"=>"path/to/your/data.csv", "normalize"=>true), 
        Dict("data"=>additional_data),
    ]
)
```

After loading the GUI the additional series are available in the **Available data** menu (make sure not to have any element selected), and can be selected for plotting alongside model results.
