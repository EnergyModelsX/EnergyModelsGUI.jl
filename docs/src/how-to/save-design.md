# [Save design to file](@id save_design)

EnergyModelsGUI enables an interactive framework for moving nodes in a topology which can be saved to file. Simply use the save button in the GUI after running the application (for example using one of the examples in the repository)
```julia
gui = GUI(case; path);
```
where the variable path is where you want to store your updated design coordinates. Next time you run the GUI, it will use the updated coordinates. 
