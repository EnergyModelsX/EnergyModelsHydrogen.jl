# EnergyModelsHydrogen

```@docs
EnergyModelsHydrogen
```

This Julia package implements three main nodes with corresponding JuMP constraints, extending the package [`EnergyModelsBase`](https://energymodelsx.github.io/EnergyModelsBase.jl/) with more detailed representation of *hydrogen technologies*.

The first node is an electrolyser node.
Two different types are provided, [`SimpleElectrolyzer`](@ref) and [`Electrolyzer`](@ref).
Both types include constraints on the lifetime of the electrolysis stack and the potential for stack replacement.
In addition, both types calculate the degradation rate.
The [`Electrolyzer`](@ref) node utilizes the degradation rate to calculate a reducing efficiency resulting in a bilinear problem.
The mathematical descriptions can be found on the page *[Electrolyzer nodes](@ref nodes-elec)*.

The second node is a reformer node described through the type [`Reformer`](@ref).
The reformer node is incorporating unit commit constraints.
The mathematical description can be found on the page *[Reformer node](@ref nodes-ref)*.

The third node is a hydrogen storage node described through the types [`SimpleHydrogenStorage`](@ref) and [`HydrogenStorage`](@ref).
Both types include constraints on the maximum discharge rate relative to the charge capacity and the maximum charge capacity relative to the storage capacity.
[`HydrogenStorage`](@ref) nodes include in addition a dependency of the compression electricity demand on the storage level and the charge rate.
The former requires furthermore a piecewise linear formulation for the electricity demand.
The mathematical description can be found on the page *[Hydrogen storage nodes](@ref nodes-h2_storage)*.

## Manual outline

```@contents
Pages = [
    "manual/quick-start.md",
    "manual/NEWS.md",
]
Depth = 1
```

## Description of the nodes

```@contents
Pages = [
    "nodes/electrolyzer.md",
    "nodes/reformer.md",
    "nodes/h2_storage.md",
]
Depth = 1
```

## How to guides

```@contents
Pages = [
    "how-to/contribute.md",
]
Depth = 1
```

## Auxiliary functions

```@contents
Pages = [
    "aux-fun/lin-reform.md",
    "aux-fun/pressurce_calc.md",
]
Depth = 1
```

## Library outline

```@contents
Pages = [
    "library/public.md",
    "library/internals/types.md",
    "library/internals/methods-fields.md",
    "library/internals/methods-EMH.md",
    "library/internals/methods-EMB.md",
]
Depth = 1
```
