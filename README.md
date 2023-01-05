# EnergyModelsHydrogen

[![Pipeline: passing](https://gitlab.sintef.no/clean_export/energymodelsrenewableproducers.jl/badges/main/pipeline.svg)](https://gitlab.sintef.no/clean_export/energymodelsrenewableproducers.jl/-/jobs)
[![Docs: stable](https://img.shields.io/badge/docs-stable-4495d1.svg)](https://clean_export.pages.sintef.no/energymodelsrenewableproducers.jl)


`EnergyModelsHydrogen` is a package extending `EnergyModelsBase` to model Hydrogen production in greated detail, including e.g. degradation.

> **Note**
> This is an internal pre-release not intended for distribution outside the project consortium. 

> **Warning**
> This package needs a non-linear non-convex solver to run the tests. Examples of supported solvers are SCIP and Gurobi. The tests will be updated to use SCIP when a package of the open-source release is available, expected by the end of 2022 or early 2023.


## Usage

```julia
using EnergyModelsBase
using EnergyModelsHydrogen
using JuMP
using TimeStructures
using SCIP

const EMB = EnergyModelsBase
const EMH = EnergyModelsHydrogen

params_dict = Dict(
    :Deficit_cost => FixedProfile(0),
    :Num_hours => 2,
    :Degradation_rate => 1,
    :Equipment_lifetime => 85000,
)
optim = SCIP.Optimizer

function build_run_electrolyzer_model(Params)
    @debug "Degradation electrolyzer model."
    # Step 1: Defining the overall time structure.
    # Project lifetime: Params[:Num_hours] hours. 1 strategic investment period.
    # operations: period of Params[:Num_hours] hours, 1 hour resolution. 
    overall_time_structure =
        UniformTwoLevel(1, 3, 2, UniformTimes(1, Params[:Num_hours], 1))

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = ResourceCarrier("Power", 0.0)
    H2 = ResourceCarrier("H2", 0.0)

    # Step 3: Defining products:
    products = [Power, H2]
    𝒫 = Dict(k => 0 for k ∈ products)

    # Step 4: Defining nodes:
    Central_node = GenAvailability("CN", 𝒫, 𝒫)

    Wind_turbine = RefSource(
        "WT",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(0),    # Variable Opex    
        FixedProfile(0),    # Fixed Opex
        Dict(Power => 1),   # Ratio of output to characteristic throughput
        Dict(),             # Emissions
        Dict(),             # Data
    )

    PEM_electrolyzer = EMH.Electrolyzer(
        "PEM",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(10),   # Variable Opex
        FixedProfile(0),    # Fixed Opex
        FixedProfile(1000), # Stack replacement costs
        Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput 
        Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
        Dict(),             # Emissions dict
        0.0,                # CO2 capture
        Dict(),             # Data
        5 / 60,             # Startup time  
        0,                  # Min load
        160,                # Max load
        Params[:Equipment_lifetime],
        Params[:Degradation_rate],
    )

    End_hydrogen_consumer = RefSink(
        "Con",
        FixedProfile(50),   # Installed capacity [MW]
        Dict(:Surplus => FixedProfile(0), :Deficit => Params[:Deficit_cost]), # Penalty dict
        Dict(H2 => 1),      # Ratio of sink flows to sink characteristic throughput.
        Dict(),             # Emissions dict
    )


    nodes = [Central_node, Wind_turbine, PEM_electrolyzer, End_hydrogen_consumer]

    # Step 5: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links = [
        Direct("l1", Wind_turbine, Central_node, Linear())
        Direct("l2", Central_node, PEM_electrolyzer, Linear())
        Direct("l3", PEM_electrolyzer, Central_node, Linear())
        Direct("l4", Central_node, End_hydrogen_consumer, Linear())
    ]

    # Step 6: Setting up the global data. Data for the entire project and not node or arc dependent
    global_data = GlobalData(Dict())

    data = Dict(
        :T => overall_time_structure,
        :products => products,
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{EMB.Link}(links),
        :global_data => global_data,
    )

    # B Formulating and running the optimization problem
    modeltype = OperationalModel()
    m = create_model(data, modeltype)

    @debug "Optimization model: $(m)"

    set_optimizer(m, optim)

    optimize!(m)
end

build_run_electrolyzer_model(params_dict)
```

## Project Funding

`EnergyModelsHydrogen` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)



<!---
[![Build Status](https://travis-ci.com/avinashresearch1/Hydrogen.jl.svg?branch=main)](https://travis-ci.com/avinashresearch1/Hydrogen.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/avinashresearch1/Hydrogen.jl?svg=true)](https://ci.appveyor.com/project/avinashresearch1/Hydrogen-jl)
[![Coverage](https://codecov.io/gh/avinashresearch1/Hydrogen.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/avinashresearch1/Hydrogen.jl)
[![Coverage](https://coveralls.io/repos/github/avinashresearch1/Hydrogen.jl/badge.svg?branch=main)](https://coveralls.io/github/avinashresearch1/Hydrogen.jl?branch=main)
--->