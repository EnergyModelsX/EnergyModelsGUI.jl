using Documenter
using DocumenterInterLinks
using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsGUI
const EMB = EnergyModelsBase
const EMGUI = EnergyModelsGUI

# Copy the NEWS.md file
news = "docs/src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp("NEWS.md", news)

ENV["EMX_TEST"] = true # Set flag for example scripts to check if they are run as part CI
include("generate_images.jl")

DocMeta.setdocmeta!(
    EnergyModelsGUI, :DocTestSetup, :(using EnergyModelsGUI); recursive = true,
)

links = InterLinks(
    "EnergyModelsBase" => "https://energymodelsx.github.io/EnergyModelsBase.jl/stable/",
)

makedocs(;
    sitename = "EnergyModelsGUI.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = "main",
        assets = String[],
        ansicolor = true,
        size_threshold = 307200, # Default is 204800 (KiB)
    ),
    modules = [EnergyModelsGUI],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start"=>"manual/quick-start.md",
            "Philosophy"=>"manual/philosophy.md",
            "Example"=>"manual/simple-example.md",
            "Release notes"=>"manual/NEWS.md",
        ],
        "How to" => Any[
            "Save design to file"=>"how-to/save-design.md",
            "Export results"=>"how-to/export-results.md",
            "Customize colors"=>"how-to/customize-colors.md",
            "Customize icons"=>"how-to/customize-icons.md",
            "Customize descriptive_names"=>"how-to/customize-descriptive_names.md",
        ],
        "Library" => Any[
            "Public"=>"library/public.md",
            "Internals"=>Any["Reference"=>"library/internals/reference.md",],
        ],
    ],
    plugins = [links],
)

deploydocs(; repo = "github.com/EnergyModelsX/EnergyModelsGUI.jl.git")
