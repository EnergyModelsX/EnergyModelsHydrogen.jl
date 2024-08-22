# [Public interface](@id lib-pub)

## [Node types](@id lib-pub-nodes)

### [Electrolyzer nodes](@id lib-pub-nodes-elect)

```@docs
SimpleElectrolyzer
Electrolyzer
```

### [Reformer nodes](@id lib-pub-nodes-ref)

```@docs
Reformer
```

### [Hydrogen storage nodes](@id lib-pub-nodes-h2_stor)

```@docs
SimpleHydrogenStorage
```

## [Additional types](@id lib-pub-add)

### [Limiting the load](@id lib-pub-add-load_limit)

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

### [Unit commitment](@id lib-pub-add-unit_commit)

Unit commitment implies in the context of EMX to parameters that provide information on the stage cost and the minimum time in a stage.
They are currently only implemented for the `Reformer` node, but can be generalized for other node types, if desired.

```@docs
CommitParameters
```

### [Change of utilization](@id lib-pub-add-ramping)

Change of utilization constraints, also called ramping constraints, require different types to allow for both constraints on the positive change of utilization (ramp up) and negative change of utilization (ramp down).
They are currently only implemented for the `Reformer` node, but can be generalized for other node types, if desired.
In addition, we provide a type when no constraints should be incorporated.

```@docs
RampBi
RampUp
RampDown
RampNone
```
