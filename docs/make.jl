using Documenter

using EnergyModelsHydrogen


# Copy the NEWS.md file
news = "src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp("../NEWS.md", "src/manual/NEWS.md")


makedocs(
    sitename = "EnergyModelsHydrogen",
    format = Documenter.HTML(),
    modules = [EnergyModelsHydrogen],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "Examples" => Any[
            "WIP: Simple Electrolyzer" => "examples/simple-electrolyzer-1-area.md",
            "WIP: Electrolyzer: two areas" => "examples/simple-electrolyzer-2-areas.md",
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
