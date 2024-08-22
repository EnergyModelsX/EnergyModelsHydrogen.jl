# [Electrolyzer nodes](@id nodes-elec)

Electrolysis plants can be separated between the electrolysis stack and the balance of plant.
While the former is the core of the plant for the production of hydrogen, it experiences degradation resulting in a reduced efficiency when utilizing the stack.
The lifetime of the stack is furthermore reduced compared to the balance of plant.
Hence, incorporating the potential for stack replacement and the associated costs may impact the utilization of the electrolyser given electricity availability and price.

Stack replacement is cheaper than rebuilding a complete plant.
Furthermore, it results in an improved efficiency as it resets the degradation.

## [Introduced types and their fields](@id nodes-elec-fields)

Electrolysis is incorporated through two composite types with the same parameters.
Both types are essentially equal, but [`SimpleElectrolyzer`](@ref) does not utilize the degradation of the stack for the calculation of a reduced efficiency as [`Electrolyzer`](@ref).
Instead, it utilizes it only for stack replacement calculations to avoid bilinear terms as constraints.

!!! danger "Electrolysis with changing capacities"
    The stack degradation calculations do not consider a change in capacity.
    If you want to include investments or only an increased capacity over the course of time, you have to include several electrolysis nodes in which each node corresponds to the capacity in a strategic period with a changing capacity.

### [Standard fields](@id nodes-elec-fields-stand)

The standard fields are given as:

- **`id`**:\
  The field **`id`** is only used for providing a name to the node.
  This is similar to the approach utilized in `EnergyModelsBase`.
- **`cap::TimeProfile`**:\
  The installed capacity of the electrolysis node corresponds to the potential usage of the node.
  The capacity does not have to correspond to the amount of hydrogen produced.
  Instead, it is relative to the specified `input` and `output` ratios.\
  If the node should contain investments through the application of [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`opex_var::TimeProfile`**:\
  The variable operational expenses of an electrolysis node are based on the capacity utilization through the variable [`:cap_use`](@extref EnergyModelsBase man-opt_var-cap).
  Hence, it is directly related to the specified `input` and `output` ratios.
  The variable operating expenses can be provided as `OperationalProfile` as well.
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS-struct-sp)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`input::Dict{<:Resource, <:Real}`** and **`output::Dict{<:Resource, <:Real}`**:\
  Both fields describe the `input` and `output` [`Resource`](@extref EnergyModelsBase.Resource)s with their corresponding conversion factors as dictionaries.
  In the case of electrolysis, `input` should include *electricity* and potentially *water* while the output is *hydrogen* and potentially *heat*, if included in the model.\
  All values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current version of electrolysis, it is only relevant for additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) is used.

!!! warning "Capacity, opex, input and output"
    The fields `capacity` `opex_var`, `opex_fixed`, `input` and `output` dictionaries are directly linked.

    Consider a 10 MWₑₗ electrolyzer which has a maximum electricity input of 10 MW, and variable OPEX of 5 €/MWhₕ₂ (defined _via_ the produced hydrogen), a fixed OPEX of 20000 €/MWₑₗ (defined _via_ the electricity capacity), and an efficiency of 69 %.
    In this situation, you would specify the input as

    ```julia
    cap = FixedProfile(10)
    var_opex = FixedProfile(5/.69)
    fixed_opex = FixedProfile(20000)
    input = Dict(Electricity => 1)
    output = Dict(Hydrogen => 0.69)
    ```

    As the variable OPEX is defined _via_ the produced hydrogen, it is crucial to include the efficiency in the calculation as the model bases the calculation on a value of 1 in the input or output dictionary.

### [Additional fields](@id nodes-elec-fields-new)

- **`load_limits::LoadLimits`**:\
  The `load_limits` specify the lower and upper limit for operating the electrolyzer.
  These limits are included through the type [`LoadLimits`](@ref) and correspond to a fraction of the installed capacity as described in *[Limiting the load](@ref lib-pub-load_limit)*.\
  The lower limit has to be non-negative while the upper limit has to be higher than the lower limit.
- **`degradation_rate::Real`**:\
  The degradation rate is the reduction in efficiency of the electrolyser due to utilization.
  It has to be provided as a percentage drop in efficiency in 1000 time the length of an operational duration (see *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS-struct-sp)* for an explanation).
  If a duration of 1 in an operational period corresponds to an hour, then the unit is %/1000h.\
  The degradation rate has to be given as ``[0, 1)``
- **`stack_replacement_cost::TimeProfile`**:\
  The stack replacement cost corresponds to the costs associated with stack replacement.
  It is smaller that the capital expenditures as only the stack has to be replaced.
  The cost is included in the fixed operational cost variable in the strategic period in which stack replacement occurs.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the stack replacment cost, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`stack_lifetime::Real`**:\
  The stack lifetime affects when the stack has to be replaced.
  The lifetime is given as multiple of the operational duration (see *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS-struct-sp)* for an explanation).
  A typical value is in the range of 60000-100000 h in the case of an operational duration of 1 h.

## [Mathematical description](@id nodes-elec-math)

In the following mathematical equations, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-elec-math-var)

#### [Standard variables](@id nodes-elec-math-var-stand)

The electrolyser node types utilize all standard variables from the `RefNetworkNode`, as described on the page *[Optimization variables](@extref EnergyModelsBase man-opt_var)*.
The variables include:

- [``\texttt{opex\_var}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase man-opt_var-opex)
- [``\texttt{cap\_use}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{cap\_inst}``](@extref EnergyModelsBase man-opt_var-cap)
- [``\texttt{flow\_in}``](@extref EnergyModelsBase man-opt_var-flow)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase man-opt_var-flow)

The variable ``\texttt{opex\_fixed}`` also includes the cost of stack replacement in the strategic periods in which stack replacement occurs.

#### [Additional variables](@id nodes-elec-math-add)

Electrolyzer nodes declare in addition several variables through dispatching on the method [`EnergyModelsBase.variables_node()`](@ref).
These variables are:

- ``\texttt{elect\_on\_b}[n_{el}, t]``: State of electrolyser node ``n_{el}`` in operational period ``t``.\
  This variable is a **_binary_** variable which indiciates whether the electrolyser is on (1) or off (0).
  It is used in the calculation of the stack degradation and the lifetime of the electrolyser stack.
- ``\texttt{elect\_previous\_usage}[n_{el}, t]``: Usage of electrolyser node ``n_{el}`` up to operational period ``t``.\
  The usage of the electrolyser node always corresponds to the accumulated usage since the beginning or the last stack replacement up to the previous period.
  Usage of the node in operational period ``t`` is not included in the calculation.
- ``\texttt{elect\_usage\_sp}[n_{el}, t_{inv}]``: Usage of electrolyser node ``n_{el}`` in strategic period ``t_{inv}``.\
  This variable denotes the total usage within a strategic period.
- ``\texttt{elect\_usage\_rp}[n_{el}, t_{rp}]``: Usage of electrolyser node ``n_{el}`` in representative period ``t_{rp}``.\
  This variable denotes the total usage within a representative period, if the chosen `TimeStructure` includes `RepresentativePeriods`.
- ``\texttt{elect\_stack\_replacement\_b}[n_{el}, t_{inv}]``: Indicator variable of electrolyser node ``n_{el}`` in strategic period ``t_{inv}`` for stack replacement.\
  This variable is a **_binary_** variable which indiciates whether stack replacement is occuring in a strategic period ``t_{inv}`` (1) or not (0).
- ``\texttt{elect\_efficiency\_penalty}[n_{el}, t]``: Efficiency penalty of electrolyser node ``n_{el}`` in operational period ``t``.\
  The efficiency penalty is calculated irrespectively whether you use a [`SimpleElectrolyzer`](@ref) or an [`Electrolyzer`](@ref) node.
  It is a multiplicator for the efficiency for hydrogen production and reset in the strategic period in which stack replacement is occuring.
- ``\texttt{elect\_usage\_mult\_sp\_b}[n_{el}, t_{inv,1}, t_{inv,2}]``: Auxiliary variable for the calculation of stack replacement.\
  This variable is a **_binary_** variable.
  The variable is used for the calculation of the usage of the electrolyser node in previous time periods.
  It corresponds to a square matrix with the number of rows/columns equal to the number of strategic periods.
  Each row corresponds to the previous strategic periods that should be counted for the calculation of the previous usage within a strategic period.

  One example for the matrix for a system with 5 strategic periods is given by

  ```math
  \texttt{elect\_usage\_mult\_sp\_b}[n_{el}, :, :] =
  \begin{bmatrix}
  1 & 1 & 1 & 1 & 1\\
  1 & 1 & 1 & 1 & 1\\
  0 & 0 & 1 & 1 & 1\\
  0 & 0 & 1 & 1 & 1\\
  0 & 0 & 0 & 0 & 1\\
  \end{bmatrix}
  ```

  The first two rows imply that we have to include the usage in strategic period 1 (column 1) in the calculation of the previous usage of strategic period 2 (row 2) while we do not include the usage in strategic periods 1 and 2 (column 1 and 2) in the calculation of the previous usage of strategic period 3 (row 3).
  Correspondingly, we can deduce that stack replacement occurs in strategic periods 3 and 5.

- ``\texttt{elect\_mult\_sp\_aux\_b}[n_{el}, t_{inv,1}, t_{inv,2}, t_{inv,3}]``: Auxiliary variable for the calculation of stack replacement.\
  This variable is a **_binary_** variable.
  The variable is only used internally for a linear reformulation and should not be accessed by the user.

!!! note "Units for usage variables"
    The variables ``\texttt{elect\_previous\_usage}[n_{el}, t]``, ``\texttt{elect\_usage\_sp}[n_{el}, t_{inv}]``, and ``\texttt{elect\_usage\_rp}[n_{el}, t_{rp}]`` have the same unit.
    The units of the variables are given in 1000 times the operational duration of 1 (see *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS-struct-sp)* for an explanation).
    If you use an hourly resolution, they would hence correspond to 1000 h.

### [Constraints](@id nodes-elec-math-con)

The following sections omit the direction inclusion of the vector of electrolyzer nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n_{el} ∈ N^{EL}``, that is both [`SimpleElectrolyzer`](@ref) and [`Electrolyzer`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

#### [Standard constraints](@id nodes-elec-math-con-stand)

The different electrolyzer nodes utilize only a small set of the standard constraints described on *[Constraint functions](@extref EnergyModelsBase man-con)*.
These standard constraints are:

- `constraints_capacity_installed`:

  ```math
  \texttt{cap\_inst}[n_{el}, t] = capacity(n_{el}, t)
  ```

- `constraints_flow_in`:

  ```math
  \texttt{flow\_in}[n_{el}, t, p] = inputs(n_{el}, p) \times \texttt{cap\_use}[n_{el}, t]
  \qquad \forall p \in inputs(n_{el})
  ```

- `constraints_opex_var`:

  ```math
  \texttt{opex\_var}[n_{el}, t_{inv}] = \sum_{t \in t_{inv}} opex_var(n_{el}, t) \times \texttt{cap\_use}[n_{el}, t] \times EMB.multiple(t_{inv}, t)
  ```

- `constraints_data`:\
  This function is only called for specified data of the reformer, see above.

The function `constraints_capacity_installed` is also used in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) to incorporate the potential for investment.
Nodes with investments are then no longer constrained by the parameter capacity.

The function [``EMB.multiple(t_{inv}, t)``](@extref EnergyModelsBase.multiple) calculates the scaling factor between operational and strategic periods.
It also takes into accoun potential operational scenarios and their probability as well as representative periods.

The [`SimpleElectrolyzer`](@ref) node utilizes in addition the default function `constraints_flow_out`:

```math
\texttt{flow\_out}[n_{el}, t, p] =
outputs(n_{el}, p) \times \texttt{cap\_use}[n_{el}, t]
\qquad \forall p \in outputs(n_{el}) \setminus \{\text{CO}_2\}
```

while the [`Electrolyzer`](@ref) node dispatches on the  function `constraints_flow_out` to incorporate the efficiency penalty:

```math
\begin{aligned}
\texttt{flow\_out}&[n_{el}, t, p] = \\ &
outputs(n_{el}, p) \times \texttt{cap\_use}[n_{el}, t] \times \texttt{elect\_efficiency\_penalty}[n_{el}, t]
\qquad \forall p \in outputs(n_{el})
\end{aligned}
```

The incorporation of the efficiency penalty results in a bilinear term as it corresponds to a multiplication of two continuous variables, ``\texttt{cap\_use}[n_{el}, t]`` and ``\texttt{elect\_efficiency\_penalty}[n_{el}, t]``.
Hence, you have to utilize a solver that supports optimization problems with bilinear constraints.

The function `constraints_capacity` is extended with a new method for electrolyzer nodes to account for the minimum and maximum load:

```math
\begin{aligned}
\texttt{cap\_use}[n_{el}, t] & \geq
min\_load(n_{el}, t) \times \texttt{elect\_on\_b}[n_{el}, t] \times capacity(n_{el}, t) \\
\texttt{cap\_use}[n_{el}, t] & \leq
max\_load(n_{el}, t) \times \texttt{elect\_on\_b}[n_{el}, t] \times capacity(n_{el}, t)
\end{aligned}
```

In the case of investment potential in the node, this constraint is reformulated as:

```math
\begin{aligned}
\texttt{cap\_use}[n_{el}, t] & \geq
min\_load(n_{el}, t) \times \texttt{elect\_on\_b}[n_{el}, t] \times \texttt{cap\_inst}[n_{el}, t] \\
\texttt{cap\_use}[n_{el}, t] & \leq
max\_load(n_{el}, t) \times \texttt{elect\_on\_b}[n_{el}, t] \times \texttt{cap\_inst}[n_{el}, t]
\end{aligned}
```

resulting in a bilinear term of a binary and continuous variable.

!!! tip "Handling of bilinearities"
    Bilinearities of this type can be reformulated as linear problem through an auxiliary variable.
    `EnergyModelsHydrogen` provides a linear reformulation through the function [`EnergyModelsHydrogen.linear_reformulation`](@ref).
    The linear reformulation is also explained in *[Linear reformulation](@ref  aux-lin_reform-bin_con)*.
    ``\texttt{cap\_inst}[n_{el}, t]`` is replaced with ``capacity(n_{el}, t)`` if the node does not have the potential for investments.
    The implementation uses the function [`EnergyModelsHydrogen.multiplication_variables`](@ref) for determining which approach should be chosen.

    The function `multiplication_variables` is only called once for each bilinearity to avoid creating the auxiliary variable multiple times.

#### [Additional constraints](@id nodes-elec-math-con-add)

##### [Constraints calculated in `create_node`](@id nodes-elec-math-con-add-node)

The efficiency penalty is calculated as:

```math
\begin{aligned}
\texttt{elect\_efficiency\_penalty}&[n_{el}, t] = \\ &
1 - degradation\_rate(n_{el}) / 100 \times \texttt{elect\_previous\_usage}[n_{el}, t] \times \texttt{elect\_efficiency\_penalty}[n_{el}, t]
\end{aligned}
```

It corresponds to a linear degradation depending on how much the electrolzer is utilized.
The division by 100 is necessary as the rate is defined as percentage value.

The fixed operating expenses include the stack replacement:

```math
\begin{aligned}
\texttt{opex\_fixed}&[n_{el}, t_{inv}] = \\ &
opex\_fixed(n_{el}, t_{inv}) \times \texttt{cap\_inst}[n_{el}, first(t_{inv})] + \\ &
\texttt{elect\_stack\_replacement\_b}[n_{el}, t_{inv}] \times capacity[n_{el}, t_{inv}] \times  \\ &stack\_replacement\_cost(n_{el}, t_{inv}) / duration\_strat(t_{inv})
\end{aligned}
```

There are two contributors to the fixed operating expenses,

1. the standed fixed operating expenses as accessed through the function ``opex\_fixed(n_{el}, t_{inv})`` and
2. the cost for stack replacement.

The first contributions requires to access the installed capacity ``\texttt{cap\_inst}``.
This variable is declared over all operational periods (see the section on *[Capacity variables](@extref EnergyModelsBase man-opt_var-cap)* for further explanations).
Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacity in the first operational period of given strategic period ``t_{inv}``.

The second contribution corresponds to the cost of stack replacement.
The overall contribution is divided by the value of the function ``duration\_strat(t_{inv})`` as the variable ``\texttt{opex\_fixed}[n_{el}, t_{inv}]`` is multiplied with the same value in the objective function.
As you only have to pay once for stack replacement, irrespectively of the length of a strategic period, it is necessary to include this division.

In the case of investment potential in the node, the stack replacement cost is reformulated as:

```math
\begin{aligned}
\texttt{opex\_fixed}&[n_{el}, t_{inv}] = \\ &
opex\_fixed(n_{el}, t_{inv}) \times \texttt{cap\_inst}[n_{el}, first(t_{inv})] + \\ &
\texttt{elect\_stack\_replacement\_b}[n_{el}, t_{inv}] \times \texttt{cap\_current}[n_{el}, t_{inv}] \times \\ &stack\_replacement\_cost(n_{el}, t_{inv}) / duration\_strat(t_{inv})
\end{aligned}
```

resulting in a bilinear term of a binary and continuous variable.
As outlined above, this bilinear term can be reformulated as linear problem, see *[Linear reformulation](@ref  aux-lin_reform-bin_con)*.
The implementation uses the function `EnergyModesHydrogen.multiplication_variables()` for determining which approach should be chosen.

The last constraints are related to the calculation of the variable ``\texttt{elect\_usage\_mult\_sp\_b}[n_{el}, t_{inv}, t_{inv}]`` through the auxiliary variable ``\texttt{elect\_mult\_sp\_aux\_b}[n_{el}, t_{inv}, t_{inv}, t_{inv}]``.
The thought process is that the variable ``\texttt{elect\_mult\_sp\_aux\_b}`` is calculated through the stack replacement, that is ``\forall t_{inv,pre} \in T^{Inv},~ \forall t_{inv} \in T^{Inv}, ~\forall t_{inv, post} \in T^{Inv}``:

```math
\begin{aligned}
    \texttt{elect\_mult\_sp\_aux\_b}&[n_{el}, t_{inv}, t_{inv,pre}, t_{inv,post}] = \\
& \begin{cases}
    1 - \texttt{elect\_stack\_replacement\_sp\_b}[n_{el}, t_{inv}],& \text{if } t_{inv, pre} < t_{inv} \leq t_{inv, post}\\
    1,              & \text{otherwise}
\end{cases}
\end{aligned}
```

``\texttt{elect\_usage\_mult\_sp\_b}`` can subsequently be calculated from the element-wise product of ``\texttt{elect\_mult\_sp\_aux\_b}``.

Consider a case with three strategic periods and stack replacement in the second strategic period.
In this situation, we can for each strategic period ``t_{inv, k}`` declare based on the previous consttraints:

```math
\begin{aligned}
\texttt{elect\_mult\_sp\_aux\_b}[n_{el}, t_{inv, 1}, :, :] & =
  \begin{bmatrix}
  1 & 1 & 1\\
  1 & 1 & 1\\
  1 & 1 & 1\\
  \end{bmatrix} \\
\texttt{elect\_mult\_sp\_aux\_b}[n_{el}, t_{inv, 2}, :, :] & =
  \begin{bmatrix}
  1 & 1 & 1\\
  0 & 1 & 1\\
  0 & 1 & 1\\
  \end{bmatrix} \\
\texttt{elect\_mult\_sp\_aux\_b}[n_{el}, t_{inv, 3}, :, :] & =
  \begin{bmatrix}
  1 & 1 & 1\\
  1 & 1 & 1\\
  1 & 1 & 1\\
  \end{bmatrix}
\end{aligned}
```

If we take now the element-wise product of these three matrices, we receive

```math
\texttt{elect\_usage\_mult\_sp\_b}[n_{el}, :, :] =
  \begin{bmatrix}
  1 & 1 & 1\\
  0 & 1 & 1\\
  0 & 1 & 1\\
  \end{bmatrix}
```

This element-wise product with ``n_{sp}`` strategic periods can be reformulated as a linear problem

```math
\begin{aligned}
\texttt{elect\_usage\_mult\_sp\_b}&[n_{el}, t_{inv,post}, t_{inv,pre}] \leq \\
&\texttt{elect\_mult\_sp\_aux\_b}[n_{el}, t_{inv},  t_{inv,post}, t_{inv,pre}] \qquad \forall t_{inv} \in T^{Inv} \\
\texttt{elect\_usage\_mult\_sp\_b}&[n_{el}, t_{inv,post}, t_{inv,pre}] \geq \\
& \sum_{i=1}^{n_{sp}} \texttt{elect\_mult\_sp\_aux\_b}[n_{el}, t_{inv, i}, t_{inv,post}, t_{inv,pre}] - (n_{sp}-1)
\end{aligned}
```

as explained in *[Linear reformulation](@ref aux-lin_reform-bin_bin)*.

##### [Constraints through separate functions](@id nodes-elec-math-con-add-fun)

The calculation of the previous usage of the electrolyzer node requires the definition of new constraint functions as the approach differs depending on the chosen `TimeStructure`.
The overall approach is similar to the calculation of the level constraints in `EnergyModelsBase`.
This is achieved through the function `constraints_usage()`.

Within this function, we first calculate ``\forall t_{inv, 1} \in T^{Inv},~ t_{inv, 2} \in T^{Inv}`` the linear reformulation of the product

```math
\texttt{elect\_usage\_mult\_sp\_b}[n_{el}, t_{inv, 1}, t_{inv, 2}] \times
\texttt{elect\_usage\_sp}[n_{el}, t_{inv, 2}]
```

in the function `constraints_usage_aux()` as explained in *[Linear reformulation](@ref  aux-lin_reform-bin_con)*.

Subsequently, the usage in each strategic period ``t_{inv}`` is calculated:

```math
\texttt{elect\_usage\_sp}[n_{el}, t_{inv}] = \sum_{t \in t_{inv}}\texttt{elect\_on\_b}[n_{el}, t]
\times EMB.multiple(t_{inv}, t)
```

If the `TImeStructure` includes representative periods, then the usage in each representative period ``t_{rp}`` is calculated (in the function `constraints_usage_iterate`):

```math
\texttt{elect\_usage\_rp}[n_{el}, t_{rp}] = \sum_{t \in t_{rp}}\texttt{elect\_on\_b}[n_{el}, t]
\times EMB.multiple(t_{inv}, t)
```

In addition, if we are in the last operational period (of the last representative period) of a strategic period, we calculate (for each operational scenario) the constraint

```math
\begin{aligned}
stack\_&lifetime(n) \geq \\ &
\texttt{elect\_previous\_usage}[n_{el}, t] \times 1000 + \\ &
\texttt{elect\_usage\_sp}[n_{el}, t_{inv}] \times (duration\_strat(t_{inv}) - 1) \times 1000 + \\
& \texttt{elect\_on\_b}[n_{el}, t] \times EMB.multiple(t_{inv}, t)
\end{aligned}
```

to avoid a violation of the lifetime constraint.
This constraint is only necessary for the last operational period as stack replacement is only allowed at the beginning of a strategic period.

The declaration of the actual constraint for the previous usage can be differentiated in four individual cases:

1. In the first operational period (in the first representative period) in the first strategic period:\
   The variable ``\texttt{elect\_previous\_usage}`` is fixed to 0.
2. In the first operational period (in the first representative period) in subsquent strategic period:\
   The constraint is given as
   ```math
   \begin{aligned}
   \texttt{elect\_}&\texttt{previous\_usage}[n_{el}, t] = \\ &
   \sum_{t_{inv, pre}}
   \texttt{elect\_usage\_mult\_sp\_b}[n_{el}, t_{inv}, t_{inv, pre}] \times
   \texttt{elect\_usage\_sp}[n_{el}, t_{inv, pre}]
   \end{aligned}
   ```
   with ``t_{inv, pre} < t_{inv}``.
3. In the first operational period in subsequent representative period:\
   The constraint is given as
   ```math
   \begin{aligned}
   \texttt{elect\_}&\texttt{previous\_usage}[n_{el}, t] = \\ &
   \texttt{elect\_previous\_usage}[n_{el}, first(t_{rp,prev})] +
   \texttt{elect\_usage\_rp}[n_{el}, t_{rp,prev}]
   \end{aligned}
   ```
   with ``t_{rp,prev}`` denoting the previous representative period.
4. In all other operational periods
   ```math
   \begin{aligned}
   \texttt{elect\_}&\texttt{previous\_usage}[n_{el}, t] = \\ &
   \texttt{elect\_previous\_usage}[n_{el}, t_{prev}] +
   duration(t_{prev}) \times \texttt{elect\_on\_b}[n, t_{prev}]/1000
   \end{aligned}
   ```
   with ``t_{prev}`` denoting the previous operational period.
