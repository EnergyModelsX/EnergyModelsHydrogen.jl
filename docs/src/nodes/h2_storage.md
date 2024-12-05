# [Hydrogen storage nodes](@id nodes-h2_storage)

Hydrogen storage nodes are in some aspects differing from standard [`Storage`](@extref EnergyModelsBase.Storage) nodes.
A first difference is that the maximum installed charge capacity is dependent on the maximum installed storage level capacity.
The reason for this dependency is that the stability of the storage allows only for small storage level changes.
In the case of gas storage, fast pressure changes would have a significant impact on the stability of the storage vessel (or alternatively the cavern, when stored in salt caverns).
A second difference is that the maximum discharge rate is normally stated as a multiple of the charge rate.
This can be explained as well by the stability of the storage in which large pressure changes should be avoided.

As a consequence, new nodal descriptions are incorporated in `EnergyModelsHydrogen` specifically for modelling hydrogen storage.

## [Introduced types and their fields](@id nodes-h2_storage-fields)

`EnergyModelsHydrogen` introduces two hydrogen storage nodes, [`SimpleHydrogenStorage`](@ref) and [`HydrogenStorage`](@ref).

[`SimpleHydrogenStorage`](@ref) nodes incorporate the constraints on the maximum discharge from the storage as well as the constraint on the maximum charge rate to storage capacity.
The latter is used in the internal checks, if a standard operational model is utilized, while it restricts investments in capacity expansions models.

[`HydrogenStorage`](@ref) nodes include all constraints from [`SimpleHydrogenStorage`](@ref) nodes.
In addition, the nodes include a storage level dependent term for the electricity requirement.
This is implemented as a combination of a bilinear term and a piecewise linear interpolation using *[Special Ordered Sets of Type 2 constraints](https://jump.dev/JuMP.jl/stable/manual/constraints/#Special-Ordered-Sets-of-Type-2)*.

!!! warning "`HydrogenStorage` nodes and investment models"
    The current implementation of [`HydrogenStorage`](@ref) nodes does not allow their usage in capacity expansion models.
    The optimization problem would in this case include a bilinear term on the flow into the storage node, the current capacity, and the current storage level.
    This leads to a complex optimization model.
    As a consequence, we decided to only allow [`HydrogenStorage`](@ref) nodes in operational models.

    This is checked through the function `EMB.check_node_data` in the `EnergyModelsInvestments` extension.

### [Standard fields](@id nodes-h2_storage-fields-stand)

The fields of both storage nodes are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
- **`charge::UnionCapacity`**:\
  The charge storage parameters must include a capacity.
  More information can be found on *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
- **`level::UnionCapacity`**:\
  The level storage parameters must include a capacity.
  More information can be found on *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)*.
  !!! note "Permitted values for storage parameters in `charge` and `level`"
      If the node should contain investments through the application of [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
      Similarly, you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
      The variable operating expenses can be provided as `OperationalProfile` as well.
      In addition, all capacity and fixed OPEX values have to be non-negative.
- **`stor_res::ResourceEmit`**:\
  The `stor_res` is the stored [`Resource`](@extref EnergyModelsBase.Resource).
- **`input::Dict{<:Resource,<:Real}`** and **`output::Dict{<:Resource,<:Real}`**:\
  Both fields describe the `input` and `output` [`Resource`](@extref EnergyModelsBase.Resource)s with their corresponding conversion factors as dictionaries.
  All values have to be non-negative.
  !!! indo "Meaning in both nodes"
      In the case of a [`SimpleHydrogenStorage`](@ref), the input should correspond to the hydogen and electricity resources.
      The chosen value in the dictionary for the hydrogen resource is not relevant.
      However, the chosen value for the electricity resource impacts the required compression energy.

      [`HydrogenStorage`](@ref) do not have the fields input and output.
      The individual resources used as input and output are instead obtained through dispatching on the functions [`inputs`](@extref EnergyModelsBase.inputs-Tuple{EnergyModelsBase.Node}) and [`outputs`](@extref EnergyModelsBase.outputs-Tuple{EnergyModelsBase.Node}).
      The inputs correspond in this case to the field `stor_res` and `el_res`.
      The latter is explained the following section.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current version, it is used for providing additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/) is used.
  !!! note
      The field `data` is not required as we include a constructor when the value is excluded.
      The current implementation of [`HydrogenStorage`](@ref) does not allow for investment data.

### [Additional fields](@id nodes-h2_storage-fields-new)

[`AbstractH2Storage`](@ref EnergyModelsHydrogen.AbstractH2Storage) nodes add additional fields compared to [`RefStorage`](@extref EnergyModelsBase.RefStorage) nodes.
The location of the fields is changing.
Hence, it is beneficial to use the docstrings ([`SimpleHydrogenStorage`](@ref) and [`HydrogenStorage`](@ref)) in which the order is included.

The individual fields are related to specifics of storing gases.
Boths nodes have the following fields:

- **`discharge_charge::Float64`**:\
  The discharge to charge ratio specifies the maximum allowed discharge as a ratio of the installed charging capacity.
  It is important due to the stability of the storage vessel or cavern.
  As a consequence of its introduction, it is not possible to specify a `discharge` capacity to the storage node.
- **`level_charge::Float64`**:\
  The level to charge ratio specifies the maximum allowed storage level capacity as a ratio of the charging capacity.
  The implementation is rquired to avoid large pressure changes in the vessel in a short period.

!!! note "Allowed values"
    Both ratios have to be positive.
    The field `level_charge` is in operational models only used for checking the provided input capacities while it is used in investment models to restrict the investments in the charge capacity.

[`HydrogenStorage`](@ref) have in addition several fields:

- **`el_res::ResourceEmit`**:\
  The `el_res` is the [`Resource`](@extref EnergyModelsBase.Resource) that corresponds in the chosen system to electricity.
  It is required to specify it to avoid
- **`p_min::Float64`**:\
  The minimum pressure in the vessel is required for stability purposes.
  The implementation of the minimum pressure requires a *cushion gas* which always remains in the storage vessel.
  The cushion gas is **not** included in the analysis.
  It must be instead included in the storage level capital expenditures as it is linear proportional to the storage level capacity.\
  The value is
- **`p_charge::Float64`**:\
  The charge pressure is the pressure used to calculate the required electricity for compressing the gas to the storage pressure.
  It corresponds to the pressure at the boundaries of the storage node.
- **`p_max::Float64`**:\
  The maximum pressure in the vessel is also required for stability purposes.
  Depending on the storage type, this pressure is either defined through the wall properties (when considering small on-site storage) or through the depth (when considering storage in salt caverns).

!!! note "Allowed values and units"
    All pressures have to be positive.
    The maximum pressure `p_max` has to be larger than the minimum pressure `p_min`.
    The charging pressure `p_charge` can be any positive value.
    If it is larger than `p_max`, it is however beneficial to use a [`SimpleHydrogenStorage`](@ref) instead without an electricity input as no compression is required.

## [Mathematical description](@id nodes-h2_storage-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-h2_storage-math-var)

The variables of both [`SimpleHydrogenStorage`](@ref) and [`HydrogenStorage`](@ref) nodes include:

- [``\texttt{opex\_var}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{stor\_level}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_level\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_charge\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_charge\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_discharge\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{flow\_in}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{stor\_level\_Δ\_op}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{stor\_level\_Δ\_rp}``](@extref EnergyModelsBase man-opt_var-cap) if the `TimeStruct` includes `RepresentativePeriods`

### [Constraints](@id nodes-h2_storage-math-con)

The following sections omit the direct inclusion of the vector of hydrogen storage nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n ∈ N`` for all [`SimpleHydrogenStorage`](@ref) or [`HydrogenStorage`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all investment periods).

#### [Standard constraints](@id nodes-h2_storage-math-con-stand)

Hydrogen storages nodes utilize in general the standard constraints described on *[Constraint functions](@extref EnergyModelsBase man-con)* for [`RefStorage`](@extref EnergyModelsBase.RefStorage) nodes.

These standard constraints are:

- `constraints_capacity_installed`:

  ```math
  \begin{aligned}
  \texttt{stor\_level\_inst}[n, t] & = capacity(level(n), t) \\
  \texttt{stor\_charge\_inst}[n, t] & = capacity(charge(n), t)
  \end{aligned}
  ```

- `constraints_flow_in`:\
  The flow into a hydrogen storage node is given by:

  ```math
  \texttt{flow\_in}[n, t, stor\_res(n)] = \texttt{stor\_charge\_use}[n, t]
  ```

  The flow of the electricity resource is dependent on the chosen type, and hence, explained below in detail.

- `constraints_flow_out`:

  ```math
  \texttt{flow\_out}[n, t, stor\_res(n)] = \texttt{stor\_discharge\_use}[n, t]
  ```

- `constraints_level`:\
  The level constraints are more complex compared to the standard constraints.
  They are explained in detail below in *[Level constraints](@ref nodes-h2_storage-math-con-level)*.

- `constraints_opex_fixed`:

  ```math
  \begin{aligned}
  \texttt{opex\_fixed}&[n, t_{inv}] = \\ &
    opex\_fixed(level(n), t_{inv}) \times \texttt{stor\_level\_inst}[n, first(t_{inv})] + \\ &
    opex\_fixed(charge(n), t_{inv}) \times \texttt{stor\_charge\_inst}[n, first(t_{inv})]
  \end{aligned}
  ```

  !!! tip "Why do we use `first()`"
      The variables ``\texttt{stor\_level\_inst}`` are declared over all operational periods (see the section on *[Capacity variables](@extref EnergyModelsBase man-opt_var-cap)* for further explanations).
      Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacities in the first operational period of a given investment period ``t_{inv}`` in the function `constraints_opex_fixed`.

- `constraints_opex_var`:

  ```math
  \begin{aligned}
  \texttt{opex\_var}&[n, t_{inv}] = \\ \sum_{t \in t_{inv}}&
    opex\_var(level(n), t) \times \texttt{stor\_level}[n, t] \times scale\_op\_sp(t_{inv}, t) + \\ &
    opex\_var(charge(n), t) \times \texttt{stor\_charge\_use}[n, t] \times scale\_op\_sp(t_{inv}, t)
  \end{aligned}
  ```

  !!! tip "The function `scale_op_sp`"
      The function [``scale\_op\_sp(t_{inv}, t)``](@extref EnergyModelsBase.scale_op_sp) calculates the scaling factor between operational and investment periods.
      It also takes into account potential operational scenarios and their probability as well as representative periods.

- `constraints_data`:\
  This function is only called for specified data of the storage node, see above.

!!! info "Implementation of capacity and OPEX"
    Even if an `AbstractHStorage` node includes the corresponding capacity field (*i.e.*, `charge`, `level`), we only include the fixed and variable OPEX constribution for the different capacities if the corresponding *[storage parameters](@extref EnergyModelsBase lib-pub-nodes-stor_par)* have a field `opex_fixed` and `opex_var`, respectively.
    Otherwise, they are omitted.

Both hydrogen storage nodes provide a new method for the function `EMB.constraints_capacity`.
While the standard constraints remain unchanged,

```math
\begin{aligned}
\texttt{stor\_level\_use}[n, t] & = \texttt{stor\_level\_inst}[n, t] \\
\texttt{stor\_charge\_use}[n, t] & = \texttt{stor\_charge\_inst}[n, t]
\end{aligned}
```

additional constraints are introduced to account for the introduced limits through the fields `discharge_charge` and `level_charge`:

```math
\begin{aligned}
\texttt{stor\__discharge\_use}[n, t] & \leq discharge\_charge(n) \texttt{stor\_charge\_use}[n, t] \\
\texttt{stor\_charge\_inst}[n, t] level\_charge(n) & \leq \texttt{stor\_level\_inst}[n, t]
\end{aligned}
```

The second constraint also limitsthe potential for investments in the charge capacity through the different constraints introduced in `EnergyModelsBase`.

The function `constraints_flow_in` is different for [`SimpleHydrogenStorage`](@ref) and [`HydrogenStorage`](@ref).
[`SimpleHydrogenStorage`](@ref) nodes utilize the standard method.
The auxiliary resource constraints are in this case given by:

```math
\texttt{flow\_in}[n, t, p] = inputs(n, p) \times \texttt{flow\_in}[n, stor\_res(n)]
\qquad \forall p \in inputs(n) \setminus \{stor\_res(n)\}
```

[`HydrogenStorage`](@ref) nodes include a pressure dependent term for the required compression energy.
As a consequence, the required electricity for compression is depending on both the hydrogen flow into the storage node and the storage level.
The constraint is given by

```math
\texttt{flow\_in}[n, t, electricity\_resource(n)]  = \texttt{flow\_in}[n, stor\_res(n)] \times W\_p[t]
```

in which ``W_p[t]`` is dependent on the storage level.
The calculation of ``W_p[t]`` is explained in the section *[Compression constraints](@ref nodes-h2_storage-math-con-comp)*

#### [Level constraints](@id nodes-h2_storage-math-con-level)

The level constraints are in general slightly more complex to understand.
The overall structure is outlined on *[Constraint functions](@extref EnergyModelsBase man-con-stor_level)*.
The level constraints are called through the function `constraints_level` which then calls additional functions depending on the chosen time structure (whether it includes representative periods and/or operational scenarios) and the chosen *[storage behaviour](@extref EnergyModelsBase lib-pub-nodes-stor_behav)*.

The hydrogen storage nodes utilize all concepts from `EnergyModelsBase`.
They remain unchanged, but are repeated below for a concise understanding.
If the time structure includes representative periods, we also calculate the change of the storage level in each representative period within the function `constraints_level_iterate` (from `EnergyModelsBase`):

```math
  \texttt{stor\_level\_Δ\_rp}[n, t_{rp}] = \sum_{t \in t_{rp}}
  \texttt{stor\_level\_Δ\_op}[n, t] \times scale\_op\_sp(t_{inv}, t)
```

The general level constraint is calculated in the function `constraints_level_iterate` (from `EnergyModelsBase`):

```math
\texttt{stor\_level}[n, t] = prev\_level +
\texttt{stor\_level\_Δ\_op}[n, t] \times duration(t)
```

in which the value ``prev\_level`` is depending on the type of the previous operational (``t_{prev}``) and strategic level (``t_{inv,prev}``) (as well as the previous representative period (``t_{rp,prev}``)).
It is calculated through the function `previous_level`.

In the case of hydropower node, we can distinguish the following cases:

1. The first operational period in the first representative period in any investment period (given by ``typeof(t_{prev}) = typeof(t_{rp, prev})`` and ``typeof(t_{inv,prev}) = NothingPeriod``).
   In this situation, we can distinguish three cases, the time structure does not include representative periods:

   ```math
   prev\_level = \texttt{stor\_level}[n, last(t_{inv})]
   ```

   the time structure includes representative periods and the storage behavior is given as [`CyclicRepresentative`](@extref EnergyModelsBase.CyclicRepresentative):

   ```math
   prev\_level = \texttt{stor\_level}[n, last(t_{rp})]
   ```

   the time structure includes representative periods and the storage behavior is given as [`CyclicStrategic`](@extref EnergyModelsBase.CyclicStrategic):

   ```math
   \begin{aligned}
    prev\_level = & \texttt{stor\_level}[n, first(t_{rp,last})] - \\ &
      \texttt{stor\_level\_Δ\_op}[n, first(t_{rp,last})] \times duration(first(t_{rp,last})) + \\ &
      \texttt{stor\_level\_Δ\_rp}[n, t_{rp,last}] \times duration\_strat(t_{rp,last})
   \end{aligned}
   ```

2. The first operational period in subsequent representative periods in any investment period (given by ``typeof(t_{prev}) = nothing``) f the the storage behavior is given as [`CyclicStrategic`](@extref EnergyModelsBase.CyclicStrategic):\

   ```math
   \begin{aligned}
    prev\_level = & \texttt{stor\_level}[n, first(t_{rp,prev})] - \\ &
      \texttt{stor\_level\_Δ\_op}[n, first(t_{rp,prev})] \times duration(first(t_{rp,prev})) + \\ &
      \texttt{stor\_level\_Δ\_rp}[n, t_{rp,prev}]
   \end{aligned}
   ```

   This situation only occurs in cases in which the time structure includes representative periods.

3. All other operational periods:\

   ```math
    prev\_level = \texttt{stor\_level}[n, t_{prev}]
   ```

All cases are implemented in `EnergyModelsBase` simplifying the design of the system.

#### [Compression constraints](@id nodes-h2_storage-math-con-comp)

The storage pressure ``p`` can be translated into the storage level assuming ideal gas behavior as

```math
\texttt{stor\_level}[n, t] = \frac{p-p_{min}}{p_{max}-p_{min}} capacity(level(n), t)
```

in which ``p_{min}`` and ``p_{max}`` corresponds to the minimum and maximum pressure, respectively.
The number of compressors ``n_{comp}`` are calculated as

```math
n_{comp} = ceil\left(\frac{\log PR_{tot}}{\log PR_{max}}\right)
```

in which ``PR_{tot} = p_{max}/p_{min}`` and ``PR_{max}`` is a user specified maximum pressure ratio.
The utilized pressure ratio is then given as

```math
PR = PR_{tot}^{1/n_{comp}}
```

The required electricity demand for compression is subsequently calculated using the concepts explained on *[Calculation of compression energy](@ref aux-p_calc)*.

The non-linear compression curve is implemented using a piecewise linear approach in which the break points are identified as the inlet to each compressor as well as 1/3 of the pressure ratio in each compressor:

```math
\begin{aligned}
  \hat{p}_1 & = p_{min} \\
  \hat{p}_{2i+2} & = p_{in}PR^i & \qquad \text{for} ~ i \in 0, \ldots, n_{comp}-1 \\
  \hat{p}_{2i+3} & = \left(1/3PR+2/3\right)p_{in}PR^i & \qquad \text{for} ~ i \in 0, \ldots, n_{comp}-1 \\
  \hat{p}_{end} & = p_{max} \\
\end{aligned}
```

Given the formulation, it is possible that some pressures are included twice and that the pressures are not sorted.
Hence, the ``\hat{\textbef{p}}`` is sorted and all duplicates are removed resulting in ``n_p`` break points.

The required relative compression energy at each breakpoint ``\hat{W}_p`` is then calculated using the function [`energy_curve`](@ref EnergyModelsHydrogen.energy_curve) as described on *[Compression train](@ref aux-p_calc-train)*.

The implementation through *[Special Ordered Sets of Type 2 constraints](https://jump.dev/JuMP.jl/stable/manual/constraints/#Special-Ordered-Sets-of-Type-2)* requires the introduction of an auxiliary variable ``\lambda \in [0,1]``
which is indexed over all operational periods ``t \\in T`` and all break points given by ``1, \ldots, n_p``.
The required constraints are subsequently given by

```math
\begin{aligned}
\texttt{stor\_level}[n, t] & =
  \sum_{i \in 1, \ldots, n_p} \lambda[t, i]\frac{\hat{p}_i-p_{min}}{p_{max}-p_{min}} capacity(level(n), t) \\
W_p[t] & = \sum_{i \in 1, \ldots, n_p} \lambda[t, i] \hat{W}_p[i]
\end{aligned}
```

The first constraints link the storage level at each operational period to the pressure ``p`` through a piecewise linear interpolation utilizing the variables ``\lambda[t, :]`` and ``\hat{\textbf{p}}`` while the second constraints calculate the required compression electricity demand ``W_p[t]`` through a piecewise linear interpolation utilizing the variables ``\lambda[t, :]`` and ``\hat{\textbf{W}}``.

In addition, we have to declare

```math
\begin{aligned}
\sum_{i \in 1, \ldots, n_p} \lambda[t, i] & = 1 \\
\lambda[t, :] & \in SOS2()
\end{aligned}
```

The first constraint assures a proper linear interpolation between break points while the second constraint states that only 2 of the variables ``\lambda[t, :]`` can be non-zero.
In addition, if two variables are non-zero, they have to be sequential.
