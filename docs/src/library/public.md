# [Public interface](@id sec_lib_public)

## Node types

### Electrolyzer nodes

```@docs
SimpleElectrolyzer
Electrolyzer
```

### Reformer nodes

```@docs
Reformer
```

## Additional types

### [Limiting the load](@id lib-pub-load_limit)

The load of a `Node` can be constrained to an upper and lower bound.
This is achieved through the type `LoadLimits` which incorporates the values for
both.

!!! note "Parametric type"
    `LoadLimits` is a [Parametric Composite Type](https://docs.julialang.org/en/v1/manual/types/#man-parametric-composite-types).
    This implies that the values for min and max have to be of the same type (_e.g._, both have to be Float or Integer)

Load limits are incorporated for both electrolyser nodes as well as the reformer node.

```@docs
LoadLimits
```

### [Unit commitment](@id lib-pub-unit_commit)

Unit commitment implies in the context of EMX to parameters that provide information on the stage cost and the minimum time in a stage.
They are currently only implemented for the `Reformer` node, but can be generalized for other node types, if desired.

```@docs
CommitParameters
```

### [Change of utilization](@id lib-pub-ramping)

Change of utilization constraints, also called ramping constraints, require different types to allow for both constraints on the positive change of utilization (ramp up) and negative change of utilization (ramp down).
They are currently only implemented for the `Reformer` node, but can be generalized for other node types, if desired.
In addition, we provide a type when no constraints should be incorporated.

```@docs
RampBi
RampUp
RampDown
RampNone
```
