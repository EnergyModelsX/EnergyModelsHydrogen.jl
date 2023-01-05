using Documenter

using EnergyModelsHydrogen


makedocs(
    sitename = "EnergyModelsHydrogen",
    format = Documenter.HTML(),
    modules = [EnergyModelsHydrogen],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Philosophy" => "manual/philosophy.md",
            "Examples" => "manual/simple-example.md",
        ],
        "Examples" => Any[
            "Simple Electrolyzer" => "examples/simple-electrolyzer-1-area.md",
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
#=deploydocs(
    repo = "<repository url>"
)=#
