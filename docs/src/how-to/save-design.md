# [Save design to file](@id save_design)

EnergyModelsGUI enables an interactive framework for moving nodes in a topology which can be saved to file.
To save the coordinates to file the `design_path` argument must be provided as follows

```julia
gui = GUI(case; design_path);
```

where the variable `design_path` is where you want to store your updated design coordinates.
You can then simply use the save button in the GUI after running the application (for example using one of the examples in the repository).
Next time you run the GUI, it will use the updated coordinates.
