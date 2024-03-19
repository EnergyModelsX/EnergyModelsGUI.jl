using Documenter
using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsGUI
const EMB = EnergyModelsBase
const EMGUI = EnergyModelsGUI

cd(dirname(@__FILE__)) # Make sure to be in the docs folder

# Copy the NEWS.md file
news = "src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp("../NEWS.md", news)


DocMeta.setdocmeta!(EnergyModelsGUI, :DocTestSetup, :(using EnergyModelsGUI); recursive=true)

makedocs(
    sitename = "EnergyModelsGUI.jl",
    repo="https://gitlab.sintef.no/clean_export/energymodelsgui.jl/blob/{commit}{path}#{line}",
    format = Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://clean_export.pages.sintef.no/energymodelsgui.jl/",
        repolink="https://clean_export.pages.sintef.no/energymodelsgui.jl/",
        edit_link="main",
        assets=String[],
    ),
    modules = [EnergyModelsGUI],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Philosophy" => "manual/philosophy.md",
            "Example" => "manual/simple-example.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "How-to" => Any[
            "Save design to file" => "how-to/save-design.md",
            "Export results" => "how-to/export-results.md",
            "Customize colors" => "how-to/customize-colors.md",
            "Customize icons" => "how-to/customize-icons.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => Any[
                "Reference" => "library/internals/reference.md",
            ]
        ]

    ],
    checkdocs=:all
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
#=deploydocs(
    repo = "<repository url>"
)=#
