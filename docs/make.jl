using Documenter
using DocumenterInterLinks
using EnergyModelsBase
using EnergyModelsInvestments
using EnergyModelsHydrogen
using TimeStruct

const EMH = EnergyModelsHydrogen
const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments


DocMeta.setdocmeta!(
    EnergyModelsHydrogen,
    :DocTestSetup,
    :(using EnergyModelsHydrogen);
    recursive = true,
)

# Copy the NEWS.md file
news = "docs/src/manual/NEWS.md"
cp("NEWS.md", news; force=true)

links = InterLinks(
    "TimeStruct" => "https://sintefore.github.io/TimeStruct.jl/stable/",
    "EnergyModelsBase" => "https://energymodelsx.github.io/EnergyModelsBase.jl/stable/",
    "EnergyModelsInvestments" => "https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/",
)

makedocs(
    sitename = "EnergyModelsHydrogen",
    modules = [
        EnergyModelsHydrogen,
        isdefined(Base, :get_extension) ?
        Base.get_extension(EMH, :EMIExt) :
        EMH.EMIExt,
    ],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = "main",
        assets = String[],
        ansicolor = true,
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start" => "manual/quick-start.md",
            "Examples" => "manual/simple-example.md",
            "Release notes" => "manual/NEWS.md",
        ],
        "Nodes" => Any[
            "Electrolyzer" => "nodes/electrolyzer.md",
            "Reformer" => "nodes/reformer.md",
            "H₂ storage" => "nodes/h2_storage.md",
        ],
        "How to" => Any[
            "Contribute to EnergyModelsHydrogen" => "how-to/contribute.md",
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

deploydocs(;
    repo = "github.com/EnergyModelsX/EnergyModelsHydrogen.jl.git",
)
