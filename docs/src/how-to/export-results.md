# [Export results](@id how_to-export_res)

The GUI enables simple printing of the results to the REPL, but one can also export to file.
In order to do this, you needs to provide the path to which the files can be exported.
This is done with the keyword input argument `path_to_results` as follows

```julia
gui = GUI(case; path_to_results=path_to_results);
```

In the opened GUI you will now be able to export results to different file formats.
It is here possible to export `All` to an .xlsx file where each JuMP variable will be stored in a separate excel sheet.
