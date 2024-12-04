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
    If you want to include investments or only an increased capacity over the course of time, you have to include several electrolysis nodes in which each node corresponds to the capacity in an investment period with a changing capacity.

### [Standard fields](@id nodes-elec-fields-stand)

The standard fields are given as:

- **`id`**:\
  The field `id` is only used for providing a name to the node.
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
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of an investment period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS-struct-sp)*.\
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
  These limits are included through the type [`LoadLimits`](@ref) and correspond to a fraction of the installed capacity as described in *[Limiting the load](@ref lib-pub-add-load_limit)*.\
  The lower limit has to be non-negative while the upper limit has to be higher than the lower limit.
- **`degradation_rate::Real`**:\
  The degradation rate is the reduction in efficiency of the electrolyser due to utilization.
  It has to be provided as a percentage drop in efficiency in 1000 time the length of an operational duration (see *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS-struct-sp)* for an explanation).
  If a duration of 1 in an operational period corresponds to an hour, then the unit is %/1000h.\
  The degradation rate has to be given as ``[0, 1)``.
- **`stack_replacement_cost::TimeProfile`**:\
  The stack replacement cost corresponds to the costs associated with stack replacement.
  It is smaller than the capital expenditures as only the stack has to be replaced.
  The cost is included in the fixed operational cost variable in the investment period in which stack replacement occurs.\
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

The variable ``\texttt{opex\_fixed}`` also includes the cost of stack replacement in the investment periods in which stack replacement occurs.

#### [Additional variables](@id nodes-elec-math-add)

Electrolyzer nodes declare in addition several variables through dispatching on the method [`EnergyModelsBase.variables_node()`](@ref).
These variables are:

- ``\texttt{elect\_on\_b}[n_{el}, t]``: State of electrolyser node ``n_{el}`` in operational period ``t``.\
  This variable is a **_binary_** variable which indiciates whether the electrolyser is on (1) or off (0).
  It is used in the calculation of the stack degradation and the lifetime of the electrolyser stack.
- ``\texttt{elect\_prev\_use}[n_{el}, t]``: Usage of electrolyser node ``n_{el}`` up to operational period ``t``.\
  The usage of the electrolyser node always corresponds to the accumulated usage since the beginning or the last stack replacement up to the previous period.
  Usage of the node in operational period ``t`` is not included in the calculation.
- ``\texttt{elect\_prev\_use\_sp}[n_{el}, t_{inv}]``: Usage of electrolyser node ``n_{el}`` up to investment period ``t_{inv}``.\
  The usage of the electrolyser node always corresponds to the accumulated usage since the beginning or the last stack replacement up to the current investment period.
  Usage of the node in investment period ``t_{inv}`` is not included in the calculation.
- ``\texttt{elect\_use\_sp}[n_{el}, t_{inv}]``: Usage of electrolyser node ``n_{el}`` in investment period ``t_{inv}``.\
  This variable denotes the total usage within an investment period.
- ``\texttt{elect\_use\_rp}[n_{el}, t_{rp}]``: Usage of electrolyser node ``n_{el}`` in representative period ``t_{rp}``.\
  This variable denotes the total usage within a representative period, if the chosen `TimeStructure` includes `RepresentativePeriods`.
- ``\texttt{elect\_stack\_replace\_b}[n_{el}, t_{inv}]``: Indicator variable of electrolyser node ``n_{el}`` in investment period ``t_{inv}`` for stack replacement.\
  This variable is a **_binary_** variable which indiciates whether stack replacement is occuring at the beginning of  investment period ``t_{inv}`` (1) or not (0).
- ``\texttt{elect\_efficiency\_penalty}[n_{el}, t]``: Efficiency penalty of electrolyser node ``n_{el}`` in operational period ``t``.\
  The efficiency penalty is calculated irrespectively whether you use a [`SimpleElectrolyzer`](@ref) or an [`Electrolyzer`](@ref) node.
  It is a multiplicator for the efficiency for hydrogen production and reset in the investment period in which stack replacement is occuring.

!!! note "Units for usage variables"
    The variables ``\texttt{elect\_prev\_use}[n_{el}, t]``, ``\texttt{elect\_use\_sp}[n_{el}, t_{inv}]``, and ``\texttt{elect\_use\_rp}[n_{el}, t_{rp}]`` have the same unit.
    The units of the variables are given in 1000 times the operational duration of 1 (see *[Utilize `TimeStruct`](@extref EnergyModelsBase how_to-utilize_TS-struct-sp)* for an explanation).
    If you use an hourly resolution, they would hence correspond to 1000 h.

### [Constraints](@id nodes-elec-math-con)

The following sections omit the direction inclusion of the vector of electrolyzer nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n_{el} ∈ N^{EL}``, that is both [`SimpleElectrolyzer`](@ref) and [`Electrolyzer`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all investment periods).

#### [Standard constraints](@id nodes-elec-math-con-stand)

The different electrolyzer nodes utilize only a small set of the standard constraints described on *[Constraint functions](@extref EnergyModelsBase man-con)*.
These standard constraints are:

- `constraints_capacity_installed`:

  ```math
  \texttt{cap\_inst}[n_{el}, t] = capacity(n_{el}, t)
  ```

  !!! tip "Using investments"
      The function `constraints_capacity_installed` is also used in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) to incorporate the potential for investment.
      Nodes with investments are then no longer constrained by the parameter capacity.

- `constraints_flow_in`:

  ```math
  \texttt{flow\_in}[n_{el}, t, p] = inputs(n_{el}, p) \times \texttt{cap\_use}[n_{el}, t]
  \qquad \forall p \in inputs(n_{el})
  ```

- `constraints_opex_var`:

  ```math
  \texttt{opex\_var}[n_{el}, t_{inv}] = \sum_{t \in t_{inv}} opex_var(n_{el}, t) \times \texttt{cap\_use}[n_{el}, t] \times scale\_op\_sp(t_{inv}, t)
  ```

  !!! tip "The function `scale_op_sp`"
      The function [``scale\_op\_sp(t_{inv}, t)``](@extref EnergyModelsBase.scale_op_sp) calculates the scaling factor between operational and investment periods.
      It also takes into account potential operational scenarios and their probability as well as representative periods.

- `constraints_data`:\
  This function is only called for specified data of the reformer, see above.

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
    The linear reformulation is also explained in *[Linear reformulation](@ref aux-lin_reform-bin_con)*.
    ``\texttt{cap\_inst}[n_{el}, t]`` is replaced with ``capacity(n_{el}, t)`` if the node does not have the potential for investments.
    The implementation uses the function [`EnergyModelsHydrogen.multiplication_variables`](@ref) for determining which approach should be chosen.

    The function `multiplication_variables` is only called once for each bilinearity to avoid creating the auxiliary variable multiple times.

#### [Additional constraints](@id nodes-elec-math-con-add)

##### [Constraints calculated in `create_node`](@id nodes-elec-math-con-add-node)

The efficiency penalty is calculated as:

```math
\begin{aligned}
\texttt{elect\_efficiency\_penalty}&[n_{el}, t] = \\ &
1 - degradation\_rate(n_{el}) / 100 \times \texttt{elect\_prev\_use}[n_{el}, t]
\end{aligned}
```

It corresponds to a linear degradation depending on how much the electrolzer is utilized.
The division by 100 is necessary as the rate is defined as percentage value.

The fixed operating expenses include the stack replacement:

```math
\begin{aligned}
\texttt{opex\_fixed}&[n_{el}, t_{inv}] = \\ &
opex\_fixed(n_{el}, t_{inv}) \times \texttt{cap\_inst}[n_{el}, first(t_{inv})] + \\ &
\texttt{elect\_stack\_replace\_b}[n_{el}, t_{inv}] \times capacity[n_{el}, t_{inv}] \times  \\ &stack\_replacement\_cost(n_{el}, t_{inv}) / duration\_strat(t_{inv})
\end{aligned}
```

!!! tip "Why do we use `first()`"
    The variables ``\texttt{cap\_inst}`` are declared over all operational periods (see the section on *[Capacity variables](@extref EnergyModelsBase man-opt_var-cap)* for further explanations).
    Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacities in the first operational period of a given investment period ``t_{inv}``.

There are two contributors to the fixed operating expenses,

1. the standed fixed operating expenses and
2. the cost for stack replacement.

The first contributions is similar to the standard function to the function [`constraints_opex_fixed`](@extref EnergyModelsBase.constraints_opex_fixed).

The second contribution corresponds to the cost of stack replacement.
The overall contribution is divided by the value of the function ``duration\_strat(t_{inv})`` as the variable ``\texttt{opex\_fixed}[n_{el}, t_{inv}]`` is multiplied with the same value in the objective function.
As you only have to pay once for stack replacement, irrespectively of the length of an investment period, it is necessary to include this division.

In the case of investment potential in the node, the stack replacement cost is reformulated as:

```math
\begin{aligned}
\texttt{opex\_fixed}&[n_{el}, t_{inv}] = \\ &
opex\_fixed(n_{el}, t_{inv}) \times \texttt{cap\_inst}[n_{el}, first(t_{inv})] + \\ &
\texttt{elect\_stack\_replace\_b}[n_{el}, t_{inv}] \times \texttt{cap\_current}[n_{el}, t_{inv}] \times \\ &stack\_replacement\_cost(n_{el}, t_{inv}) / duration\_strat(t_{inv})
\end{aligned}
```

resulting in a bilinear term of a binary and continuous variable.
As outlined above, this bilinear term can be reformulated as linear problem, see *[Linear reformulation](@ref  aux-lin_reform-bin_con)*.
The implementation uses the function `EnergyModesHydrogen.multiplication_variables()` for determining which approach should be chosen.

##### [Electrolyzer use constraints](@id nodes-elec-math-con-add-use)

The calculation of the previous usage of the electrolyzer node requires the definition of new constraint functions as the approach differs depending on the chosen `TimeStructure`.
The overall approach is similar to the calculation of the level constraints in `EnergyModelsBase`.
This is achieved through the function `constraints_usage()` and the individual functions calculated from the function.

Within this function, we first calculate ``\forall t_{inv, 1} \in T^{Inv},~ t_{inv, 2} \in T^{Inv}`` the linear reformulation of the product

First, the usage in each investment period ``t_{inv}`` is calculated:

```math
\texttt{elect\_use\_sp}[n_{el}, t_{inv}] \times 1000 = \sum_{t \in t_{inv}}\texttt{elect\_on\_b}[n_{el}, t]
\times scale\_op\_sp(t_{inv}, t)
```

The previous usage up the current investment period ``t_{inv}`` is calculated through the function `constraints_usage_sp`.
In the first investment period, the previous usage is fixed to a value of 0:

```math
\texttt{elect\_prev\_use\_sp}[n_{el}, t_{inv}] = 0
```

while the implementation within subsequent investment periods require considering potential stack replacement.
This is achieved through introducing the auxiliary variable ``\texttt{aux\_var}`` given by

```math
\begin{aligned}
\texttt{aux\_var}&[n_{el}, t_{inv}] = \\ &
  \texttt{elect\_prev\_use\_sp}[n_{el}, t_{inv,prev}] + \\ &
  \texttt{elect\_use\_sp}[n_{el}, t_{inv,prev}] \times duration\_strat(t_{inv,prev}) \\
\end{aligned}
```

The previous usage in the subsequent investment periods is then given by

```math
\begin{aligned}
\texttt{elect\_prev\_use\_sp}&[n_{el}, t_{inv}] = \\ &
  \texttt{aux\_var}[n_{el}, t_{inv}] \times (1-\texttt{elect\_stack\_replace\_b}[n_{el}, t_{inv}]) \\
\end{aligned}
```

using a direct implememtation of the linear reformulation explained in the section *[linear reformulation](@ref  aux-lin_reform-bin_con)*

```math
\begin{aligned}
\texttt{elect\_prev\_use\_sp}&[n_{el}, t_{inv}] \geq 0 \\

\texttt{elect\_prev\_use\_sp}&[n_{el}, t_{inv}] \geq \\ &
  ub(t_{inv}) \times ((1-\texttt{elect\_stack\_replace\_b}[n_{el}, t_{inv}]) - 1) + \\ &
  \texttt{aux\_var}[n_{el}, t_{inv}] \\

\texttt{elect\_prev\_use\_sp}&[n_{el}, t_{inv}] \leq \\ &
  ub(t_{inv}) \times (1-\texttt{elect\_stack\_replace\_b}[n_{el}, t_{inv}]) \\

\texttt{elect\_prev\_use\_sp}&[n_{el}, t_{inv}] \leq \texttt{aux\_var}[n_{el}, t_{inv}] \\
\end{aligned}
```

in which the upper bound ``ub`` is either the installed capacity or the maximum installed capacity, depending on whether the electrolyzer includes investments, or not.
These constraints enforce that if stack replacement occurs, that is ``\texttt{elect\_stack\_replace\_b} = 1``, ``\texttt{elect\_prev\_use\_sp}`` is reset to a value of 0.

If the `TimeStructure` includes representative periods, then the usage in each representative period ``t_{rp}`` is calculated (in the function `constraints_usage_sp_iterate`):

```math
\texttt{elect\_use\_rp}[n_{el}, t_{rp}] \times 1000 = \sum_{t \in t_{rp}}\texttt{elect\_on\_b}[n_{el}, t]
\times scale\_op\_sp(t_{inv}, t)
```

In addition, if we are in the last operational period (of the last representative period) of an investment period, we calculate (for each operational scenario) the constraint

```math
\begin{aligned}
stack\_&lifetime(n) \geq \\ &
\texttt{elect\_prev\_use}[n_{el}, t] \times 1000 + \\ &
\texttt{elect\_use\_sp}[n_{el}, t_{inv}] \times (duration\_strat(t_{inv}) - 1) \times 1000 + \\
& \texttt{elect\_on\_b}[n_{el}, t] \times scale\_op\_sp(t_{inv}, t)
\end{aligned}
```

to avoid a violation of the lifetime constraint.
This constraint is only necessary for the last operational period as stack replacement is only allowed at the beginning of an investment period.

The declaration of the actual constraint for the previous usage can be differentiated in four individual cases:

1. In the first operational period (in the first representative period) in the first investment period:\
   The variable ``\texttt{elect\_prev\_use}`` is fixed to 0.
2. In the first operational period (in the first representative period) in subsquent investment periods:\
   The constraint is given as

   ```math
   \texttt{elect\_previous\_use}[n_{el}, t] = \texttt{elect\_prev\_use\_sp}[n_{el}, t_{inv}]
   ```

3. In the first operational period in subsequent representative period:\
   The constraint is given as
   ```math
   \begin{aligned}
   \texttt{elect\_}&\texttt{previous\_use}[n_{el}, t] = \\ &
   \texttt{elect\_prev\_use}[n_{el}, first(t_{rp,prev})] +
   \texttt{elect\_use\_rp}[n_{el}, t_{rp,prev}]
   \end{aligned}
   ```
   with ``t_{rp,prev}`` denoting the previous representative period.
4. In all other operational periods
   ```math
   \begin{aligned}
   \texttt{elect\_}&\texttt{previous\_use}[n_{el}, t] = \\ &
   \texttt{elect\_prev\_use}[n_{el}, t_{prev}] +
   duration(t_{prev}) \times \texttt{elect\_on\_b}[n, t_{prev}]/1000
   \end{aligned}
   ```
   with ``t_{prev}`` denoting the previous operational period.
