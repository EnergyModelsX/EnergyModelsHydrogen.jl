# EnergyModelsHydrogen

[![Pipeline: passing](https://gitlab.sintef.no/clean_export/energymodelshydrogen.jl/badges/main/pipeline.svg)](https://gitlab.sintef.no/clean_export/energymodelshydrogen.jl/-/jobs)
[![Docs: stable](https://img.shields.io/badge/docs-stable-4495d1.svg)](https://clean_export.pages.sintef.no/energymodelshydrogen.jl)


`EnergyModelsHydrogen` is a package extending `EnergyModelsBase` to model Hydrogen production in greated detail, including e.g. degradation.

> **Note**
> This is an internal pre-release not intended for distribution outside the project consortium.

> **Warning**
> This package needs a non-linear non-convex solver to run the tests. Examples of supported solvers are SCIP and Gurobi.

## Usage

```julia
using EnergyModelsBase
using EnergyModelsHydrogen
using JuMP
using TimeStruct
using SCIP

const EMB = EnergyModelsBase
const EMH = EnergyModelsHydrogen

params_dict = Dict(
    :deficit_cost => FixedProfile(100),
    :num_op => 2,
    :degradation_rate => .2,
    :stack_lifetime => 90000,
)
optim = SCIP.Optimizer

function build_run_electrolyzer_model(params)
    @debug "Degradation electrolyzer model."
    # Step 1: Defining the overall time structure
    T = TwoLevel(3, 5, SimpleTimes(params[:num_op], 1); op_per_strat=8760)

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = ResourceCarrier("Power", 0.0)
    H2 = ResourceCarrier("H2", 0.0)
    CO2 = ResourceEmit("CO2", 0.0)

    # Step 3: Define products
    products = [Power, H2, CO2]

    # Step 4: Define the nodes
    wind_turbine = RefSource(
        "wind_turbine",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(50),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(Power => 1),   # Ratio of output to characteristic throughput
        Data[],             # Data
    )

    electrolyzer = SimpleElectrolyzer(
        "electrolyzer",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(10),   # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
        Dict(H2 => 0.69),   # Ouput: Ratio of Output flow to characteristic throughput
        Data[],             # Data
        LoadLimits(0, 1),   # Minimum and maximum load
        params[:degradation_rate],
        FixedProfile(100000), # Stack replacement costs
        params[:stack_lifetime],
    )

    H2_demand = RefSink(
        "Con",
        FixedProfile(50),   # Installed capacity [MW]
        Dict(:surplus => FixedProfile(0), :deficit => params[:deficit_cost]), # Penalty dict
        Dict(H2 => 1),      # Ratio of sink flows to sink characteristic throughput.
    )


    nodes = [wind_turbine, electrolyzer, H2_demand]

    # Step 5: Define the links (graph connections).
    links = [
        Direct("l1", wind_turbine, electrolyzer, Linear())
        Direct("l3", electrolyzer, H2_demand, Linear())
    ]

    data = Dict(
        :T => T,
        :products => products,
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{EMB.Link}(links),
    )

    # B Formulating and running the optimization problem
    modeltype = OperationalModel(
        Dict(CO2 => FixedProfile(0)),
        Dict(CO2 => FixedProfile(0)),
        CO2
    )
    m = create_model(data, modeltype)

    set_optimizer(m, optim)

    optimize!(m)

    return m, data
end

m, data = build_run_electrolyzer_model(params_dict)
```

## Project Funding

`EnergyModelsHydrogen` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)



<!---
[![Build Status](https://travis-ci.com/avinashresearch1/Hydrogen.jl.svg?branch=main)](https://travis-ci.com/avinashresearch1/Hydrogen.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/avinashresearch1/Hydrogen.jl?svg=true)](https://ci.appveyor.com/project/avinashresearch1/Hydrogen-jl)
[![Coverage](https://codecov.io/gh/avinashresearch1/Hydrogen.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/avinashresearch1/Hydrogen.jl)
[![Coverage](https://coveralls.io/repos/github/avinashresearch1/Hydrogen.jl/badge.svg?branch=main)](https://coveralls.io/github/avinashresearch1/Hydrogen.jl?branch=main)
--->
