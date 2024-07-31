# [Linear reformulation](@id aux-lin_reform)

## [Product of continuous and binary variable](@id aux-lin_reform-bin_con)

### General approach

Consider the product ``z`` between a continuous variable ``x`` and a binary variable ``y`` with ``x`` being constrained as ``x \in [lb, ub]``.
In this case, it is possible to reformulate the product through linear inequality constraints:

```math
\begin{aligned}
lb \times y \leq & z \leq ub \times y \\
ub (y-1) + x \leq & z \leq lb (1-y) + x
\end{aligned}
```

The first line enforces that if ``y = 1``, then ``z \in [lb, ub]``, otherwise, ``z = 0``.
The second line enforces that ``z = x`` if ``y = 1``.
The constraint is inactive if ``y = 0``.

### Indexing in `EnergyModelsHydrogen`

`EnergyModelsHydrogen` provides two functions for the linear reformulation which differ with respect to the indexing of the individual variables.
It would be also possible to include the indexing within the function call, but it is preferable to create the anonymous auxiliary variables within a single call.

These two functions differ in the time structure indexing.
Mathematically, this is given as

1. ``z[t] = x[t] \times b[t]`` and
2. ``z[t_a, t_b] = x[t_b] \times b[t_a, t_b]``.

The linear reformulations are available through the function [`EnergyModelsHydrogen.linear_reformulation()`](@ref)

## [Product of two binary variablees](@id aux-lin_reform-bin_bin)

The element-wise product ``z`` of ``n`` binary variables ``x_i``, that is

```math
z = \prod_{i=1}^n x_i,
```

can be reformulated as

```math
\begin{aligned}
z & \leq x_i \qquad\qquad\qquad \text{for } i = 1,\ldots,n \\
z & \geq \sum_{i=1}^n x_i - (n-1)
\end{aligned}
```

This reformulation is exact.
The reformulation is not implemented as an auxiliary function.
Instead it is directly included in the `EMB.create_node()` function for `AbtractElectrolyzer` nodes.
