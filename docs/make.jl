using Documenter
using DocumenterInterLinks
using EnergyModelsBase
using EnergyModelsInvestments
using EnergyModelsHydrogen
using TimeStruct

const EMH = EnergyModelsHydrogen
const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments


# Copy the NEWS.md file
news = "src/manual/NEWS.md"
if isfile(news)
    rm(news)
end
cp("../NEWS.md", "src/manual/NEWS.md")


links = InterLinks(
    "TimeStruct" => "https://sintefore.github.io/TimeStruct.jl/stable/",
    "EnergyModelsBase" => "https://energymodelsx.github.io/EnergyModelsBase.jl/stable/",
    "EnergyModelsInvestments" => "https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/",
)

# DocMeta.setdocmeta!(EnergyModelsHydrogen, :DocTestSetup, :(using EnergyModelsHydrogen, EnergyModelsInvestments); recursive=true)

makedocs(
    sitename = "EnergyModelsHydrogen",
    repo="https://gitlab.sintef.no/clean_export/energymodelshydrogen.jl/blob/{commit}{path}#{line}",
    format = Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://clean_export.pages.sintef.no/energymodelshydrogen.jl/",
        edit_link="main",
        assets=String[],
    ),

    modules = [
        EnergyModelsHydrogen,
        isdefined(Base, :get_extension) ?
        Base.get_extension(EMH, :EMIExt) :
        EMH.EMIExt,
    ],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "Nodes" => Any[
            "Electrolyzer" => "nodes/electrolyzer.md",
            "Reformer" => "nodes/reformer.md",
            "H₂ storage" => "nodes/h2_storage.md",
        ],
        "Auxiliary functions" => Any[
            "Linear reformulation" => "aux-fun/lin-reform.md",
            "Compression energy" => "aux-fun/pressure_calc.md",
        ],
        "Library" => Any[
            "Public" => "library/public.md",
            "Internals" => String[
                "library/internals/types-EMH.md",
                "library/internals/methods-fields.md",
                "library/internals/methods-EMH.md",
                "library/internals/methods-EMB.md",
            ],
        ]
    ],
    plugins=[links],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
# deploydocs(
#     repo = "https://clean_export.pages.sintef.no/energymodelshydrogen.jl/"
# )
