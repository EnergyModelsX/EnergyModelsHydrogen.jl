using Documenter
using EnergyModelsHydrogen


# Copy the NEWS.md file
news = "src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp("../NEWS.md", "src/manual/NEWS.md")

DocMeta.setdocmeta!(EnergyModelsHydrogen, :DocTestSetup, :(using EnergyModelsHydrogen); recursive=true)
makedocs(
    sitename = "EnergyModelsHydrogen.jl",
    repo="https://gitlab.sintef.no/clean_export/energymodelshydrogen.jl/blob/{commit}{path}#{line}",
    format = Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://clean_export.pages.sintef.no/energymodelshydrogen.jl/",
        edit_link="main",
        assets=String[],
    ),

    modules = [EnergyModelsHydrogen],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "Examples" => Any[
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => "library/internals.md"
        ]
    ]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
# deploydocs(
#     repo = "https://clean_export.pages.sintef.no/energymodelshydrogen.jl/"
# )
