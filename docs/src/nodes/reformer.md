# [Reformer node](@id nodes-ref)

Reformer plants are in general large chemical production facilities as they experience significant economies of scale.
Utilizing standard modelling approaches would hence result in an overestimation of the flexibility and operating windows of the plants.
They can be characterized by:

1. a slow change in their operating point due to both heat and mass integration within the process,
2. a minimum operating point under which they cannot operate,
3. significant time requirements for both start-up and shutdown with corresponding costs due to integration of the processes, and
4. a minimum down time once turned off.

In this respect, reformer plants should be represented with unit commitment constraints with 4 distinctive states, startup, online, shutdown, and offline.

## [Introduced type and its field](@id nodes-ref-fields)

Reformer are incorporated through a single composite type [`Reformer`](@ref) although provisions are made to include other types.
The following sections will provide you with an explanation of the individual fields of the type.

### [Standard fields](@id nodes-ref-fields-stand)

The standard fields are given as:

- **`id`**:\
  The field **`id`** is only used for providing a name to the node. This is similar to the approach utilized in `EnergyModelsBase`.
- **`cap::TimeProfile`**:\
  The installed capacity corresponds to the potential usage of the node.
  The capacity does not have to correspond to the amount of hydrogen produced.
  Instead, it is relative to the specified `input` and `output` ratios.
  However, capacities of reformer are in general specified based on the produced hydrogen.\
  If the node should contain investments through the application of [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/), it is important to note that you can only use `FixedProfile` or `StrategicProfile` for the capacity, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`opex_var::TimeProfile`**:\
  The variable operational expenses are based on the capacity utilization through the variable [`:cap_use`](@extref EnergyModelsBase var_cap).
  Hence, it is directly related to the specified `input` and `output` ratios.
  The variable operating expenses can be provided as `OperationalProfile` as well.
- **`opex_fixed::TimeProfile`**:\
  The fixed operating expenses are relative to the installed capacity (through the field `cap`) and the chosen duration of a strategic period as outlined on *[Utilize `TimeStruct`](@extref EnergyModelsBase utilize_timestruct)*.\
  It is important to note that you can only use `FixedProfile` or `StrategicProfile` for the fixed OPEX, but not `RepresentativeProfile` or `OperationalProfile`.
  In addition, all values have to be non-negative.
- **`input::Dict{<:Resource, <:Real}`** and **`output::Dict{<:Resource, <:Real}`**:\
  Both fields describe the `input` and `output` [`Resource`](@extref EnergyModelsBase.Resource)s with their corresponding conversion factors as dictionaries.
  In the case of a reformer, `input` should include *natural gas* and potentially *water* and *electricity* while the output is *hydrogen* and potentially *heat*, if included in the model, and *electricity*.
  Whether *electricity* is an `input` or `output` is depending on the process design for the reformer.\
  All values have to be non-negative.
- **`data::Vector{Data}`**:\
  An entry for providing additional data to the model.
  In the current state of electrolysis, it is only relevant for additional investment data when [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) is used.

!!! warning "CO₂ as output"
    If you include CO₂ capture through the application of [`CaptureData`](@extref EnergyModelsBase.CaptureData) (explained on [*Data functions*](@extref EnergyModelsBase data_functions)), you have to add your CO₂ instance as output to the dictionary.
    The chosen value is not important, as the CO₂ outlet flow is calculated based on the CO₂ intensity of the fuel and the chosen capture rate.

### [New fields for reformer nodes](@id nodes-ref-fields-new)

- **`load_limits::LoadLimits`**:\
  The `load_limits` specify the lower and upper limit for operating the reformer plant.
  These limits are included through the type [`LoadLimits`](@ref) and correspond to a fraction of the installed capacity as described in *[Limiting the load](@ref sec_load_limit)*.\
  The lower limit has to be non-negative while the upper limit has to be higher than the lower limit.
- **`startup::CommitParameters`**, **`shutdown::CommitParameters`**, and **`offline::CommitParameters`**:\
  The fields `startup`, `shutdown`, and `offline` specify the required parameters for unit commitment.
  These parameters are included through the type [`CommitParameters`](@ref) and correspond to both a stage cost and minium time in a stage as described in *[Inclusion of unit commitment](@ref sec_unit_commit)*.\
  It is important to note that you can only use `FixedProfile`, `StrategicProfile`, or `RepresentativeProfile` for the time profiles, but not `OperationalProfile`.
  In addition, all values have to be non-negative.

## [Mathematical description](@id nodes-ref-math)

In the following mathematical experssions, we use the name for variables and functions used in the model.
Variables are in general represented as

``\texttt{var\_example}[index_1, index_2]``

with square brackets, while functions are represented as

``func\_example(index_1, index_2)``

with paranthesis.

### [Variables](@id nodes-ref-math-var)

#### [Standard variables](@id nodes-ref-math-var-stand)

The reformer node types utilize all standard variables from the `RefNetworkNode`, as described on the page *[Optimization variables](@extref EnergyModelsBase optimization_variables)*.
The variables include:

- [``\texttt{opex\_var}``](@extref EnergyModelsBase var_opex)
- [``\texttt{opex\_fixed}``](@extref EnergyModelsBase var_opex)
- [``\texttt{cap\_use}``](@extref EnergyModelsBase var_cap)
- [``\texttt{cap\_inst}``](@extref EnergyModelsBase var_cap)
- [``\texttt{flow\_in}``](@extref EnergyModelsBase var_flow)
- [``\texttt{flow\_out}``](@extref EnergyModelsBase var_flow)

#### [Additional variables](@id nodes-ref-math-add)

Rerformer nodes declare in addition several variables through dispatching on the method [`EnergyModelsBase.variables_node()`](@ref) for including the unit commitment constraints.
These variables are for reformer node ``n_{ref}`` in operational period ``t``:

- ``\texttt{ref\_off\_b}[n_{ref}, t]``: Offline indicator,
- ``\texttt{ref\_start\_b}[n_{ref}, t]``: Startup indicator,
- ``\texttt{ref\_on\_b}[n_{ref}, t]``: Online indicator, and
- ``\texttt{ref\_shut\_b}[n_{ref}, t]``: Shutdown indicator.

These variables are **_binary_** variables which indicate in which state the reformer is operating.
A value of 1 corresponds to an operation in the given stage while a value of 0 implies that the reformer is not operating in a different state

### [Constraints](@id nodes-ref-math-con)

The following sections omit the direction inclusion of the vector of reformer nodes.
Instead, it is implicitly assumed that the constraints are valid ``\forall n_{ref} ∈ N^{Ref}`` for all [`AbstractReformer`](@ref) types if not stated differently.
In addition, all constraints are valid ``\forall t \in T`` (that is in all operational periods) or ``\forall t_{inv} \in T^{Inv}`` (that is in all strategic periods).

#### [Standard constraints](@id nodes-ref-math-con-stand)

The Reformer nodes utilizes only a small set of the standard constraints described on *[Constraint functions](@extref EnergyModelsBase constraint_functions)*.
These standard constraints are:

- `constraints_capacity_installed`:
  ```math
  \texttt{cap\_inst}[n_{ref}, t] = capacity(n_{ref}, t)
  ```
- `constraints_flow_in`:
  ```math
  \texttt{flow\_in}[n_{ref}, t, p] = inputs(n_{ref}, p) \times \texttt{cap\_use}[n_{ref}, t]
  \qquad \forall p \in inputs(n_{ref})
  ```
- `constraints_flow_out`:
  ```math
  \texttt{flow\_out}[n_{ref}, t, p] =
  outputs(n_{ref}, p) \times \texttt{cap\_use}[n_{ref}, t]
  \qquad \forall p \in outputs(n_{ref})
  ```
- `constraints_opex_fixed`:
  ```math
  \texttt{opex\_fixed}[n_{ref}, t_{inv}] = opex\_fixed(n_{ref}, t_{inv}) \times \texttt{cap\_inst}[n_{ref}, first(t_{inv})]
  ```
- `constraints_data`:\
  This function is only called for specified data of the reformer, see above.

The function `constraints_capacity_installed` is also used in [`EnergyModelsInvestments`](https://energymodelsx.github.io/EnergyModelsInvestments.jl/stable/) to incorporate the potential for investment.
Nodes with investments are then no longer constrained by the parameter capacity.

The variable ``\texttt{cap\_inst}`` is declared over all operational periods (see the section on *[Capacity variables](@extref EnergyModelsBase var_cap)* for further explanations).
Hence, we use the function ``first(t_{inv})`` to retrieve the installed capacity in the first operational period of a given strategic period ``t_{inv}`` in the function `constraints_opex_fixed`.

The function `constraints_capacity` is extended with a new method for a reformer node to account for the minimum and maximum load:

```math
\begin{aligned}
\texttt{cap\_use}[n_{ref}, t] & \geq
min\_load(n_{ref}, t) \times \texttt{ref\_on\_b}[n_{ref}, t] \times capacity(n_{ref}, t) \\
\texttt{cap\_use}[n_{ref}, t] & \leq
max\_load(n_{ref}, t) \times \texttt{ref\_on\_b}[n_{ref}, t] \times capacity(n_{ref}, t)
\end{aligned}
```

In the case of investment potential in the node, this constraint is reformulated as:

```math
\begin{aligned}
\texttt{cap\_use}[n_{ref}, t] & \geq
min\_load(n_{ref}, t) \times \texttt{ref\_on\_b}[n_{ref}, t] \times \texttt{cap\_inst}[n_{ref}, t] \\
\texttt{cap\_use}[n_{ref}, t] & \leq
max\_load(n_{ref}, t) \times \texttt{ref\_on\_b}[n_{ref}, t] \times \texttt{cap\_inst}[n_{ref}, t]
\end{aligned}
```

resulting in a bilinear term of a binary and continuous variable.

!!! tip "Handling of bilinearities"
    Bilinearities of this type can be reformulated as linear problem through an auxiliary variable.
    `EnergyModelsHydrogen` provides a linear reformulation through the function [`EnergyModelsHydrogen.linear_reformulation`](@ref).
    The linear reformulation is also explained in *[Linear reformulation](@ref  aux-lin_reform-bin_con)*.
    ``\texttt{cap\_inst}[n_{ref}, t]`` is replaced with ``capacity(n_{ref}, t)`` if the node does not have the potential for investments.
    The implementation uses the function [`EnergyModelsHydrogen.multiplication_variables`](@ref) for determining which approach should be chosen.

    The function `multiplication_variables` is only called once for each bilinearity to avoid creating the auxiliary variable multiple times.

The function `constraints_opex_var` is extended with a new method for a reformer node to account for the costs associated to be within a given state:

```math
\begin{aligned}
\texttt{opex\_var}&[n_{ref}, t] = \sum_{t \in t_{inv}} ( \\ &
opex\_var(n_{ref}, t) \times \texttt{cap\_inst}[n_{ref}, t] + \\ &
opex\_startup(n_{ref}, t) \times \texttt{cap\_inst}[n_{ref}, t] \times \texttt{ref\_start\_b}[n_{ref}, t] + \\ &
opex\_shutdown_(n_{ref}, t) \times \texttt{cap\_inst}[n_{ref}, t] \times \texttt{ref\_shut\_b}[n_{ref}, t] + \\ &
opex\_off(n_{ref}, t) \times \texttt{cap\_inst}[n_{ref}, t] \times \texttt{ref\_off\_b}[n_{ref}, t] \\ &
) \times EMB.multiple(t_{inv}, t)
\end{aligned}
```

The linear reformulation is also explained in *[Linear reformulation](@ref  aux-lin_reform-bin_con)*, as explained previously.
Similarly, ``\texttt{cap\_inst}[n_{ref}, t]`` is replaced with ``capacity(n_{ref}, t)`` if the node does not have the potential for investments.

#### [Additional constraints](@id nodes-ref-math-con-add)

##### [Constraints calculated in `create_node`](@id nodes-ref-math-con-add-node)

A reformer node can only be in a single stage in a given operational period ``t``.
This is enforced through a single constraint given as

```math
\texttt{ref\_off\_b}[n_{ref}, t] + \texttt{ref\_start\_b}[n_{ref}, t] + \texttt{ref\_on\_b}[n_{ref}, t] + \texttt{ref\_shut\_b}[n_{ref}, t] = 1
```

##### [Constraints through separate functions](@id nodes-ref-math-con-add-fun)

Within the function `create_node`, we iterate the through the strategic periods to call two functions, [`EnergyModelsHydrogen.constraints_state_seq_iter`](@ref) for enforcing the correct sequencing of the individual states and [`EnergyModelsHydrogen.constraints_state_time_iter`](@ref) for enforcing the minimum time a node has to be in a given state.
Both functions iterate through the individual time structures (strategic periods, representative periods, operational scenarios) to calculate the proper constraints based on the chosen time structure.
Both functions utilize a cyclic approach in which rhe last operational period ``t_{last}`` within a strategic period (representative period, if included, or operational scenario, if included) is required to be passed to the constraint.

As outlined, the function `constraints_state_seq_iter` iterates through the time structure to determine the correct last operational period.
The constraint is eventually included through the function [`EnergyModelsHydrogen.constraints_state_seq`](@ref) which has two methods:

1. If the previous period ``t_{prev}`` is an `OperationalPeriod`, it imposes the sequencing constraints as:

   ```math
   \begin{aligned}
   \texttt{ref\_off\_b}[n_{ref}, t_{prev}] & \geq \texttt{ref\_start\_b}[n_{ref}, t] - \texttt{ref\_start\_b}[n_{ref}, t_{prev}] \\
   \texttt{ref\_start\_b}[n_{ref}, t_{prev}] & \geq \texttt{ref\_on\_b}[n_{ref}, t] - \texttt{ref\_on\_b}[n_{ref}, t_{prev}] \\
   \texttt{ref\_on\_b}[n_{ref}, t_{prev}] & \geq \texttt{ref\_shut\_b}[n_{ref}, t] - \texttt{ref\_shut\_b}[n_{ref}, t_{prev}] \\
   \texttt{ref\_shut\_b}[n_{ref}, t_{prev}] & \geq \texttt{ref\_off\_b}[n_{ref}, t] - \texttt{ref\_off\_b}[n_{ref}, t_{prev}] \\
   \end{aligned}
   ```

2. If the previous period ``t_{prev}`` is `nothing`, it is replaced by ``t_{last}``.

!!! tip "How does it work?"
    Consider a case in which the former was in the  previous period ``t_{prev}`` offline.
    In this situation, we wil;l have ``\texttt{ref\_off\_b}[n_{ref}, t_{prev}] = 1`` while ``\texttt{ref\_start\_b}[n_{ref}, t_{prev}] = 0``, ``\texttt{ref\_on\_b}[n_{ref}, t_{prev}] = 0``, and ``\texttt{ref\_shut\_b}[n_{ref}, t_{prev}] = 0``.

    - Constraint 1 implies that ``\texttt{ref\_start\_b}[n_{ref}, t]`` can be either 0 or 1.
    - Constraints 2 and 3 enforce that both ``\texttt{ref\_on\_b}[n_{ref}, t]`` and ``\texttt{ref\_shut\_b}[n_{ref}, t]`` are 0 as the left hand side is 0.
    - Constraint 4 implies ``\texttt{ref\_off\_b}[n_{ref}, t]`` can be either 0 or 1.

    As a consequence, we can either remain in the state *offline* or proceed to the state *startup*.

The function `constraints_state_time_iter` utlizes the same iteration approach as the function `constraints_state_seq_iter`.
However, we calculate the the constraints within the function when the operatioanl time structure is given as `SimpleTimes`.
The implementation can utilize different lengths within each state as well as variations in the duration of operational periods.
This is achieved through the function [`TimeStruct.chunk_duration`](@extref) which provides an iterator of time chuncks of at least a given duration.

The constraints are cyclic constraints which utilize the function `zip` to obtain a combined iterator of the individual `chunk_duration` iterators and the current operational period.

This approach is best explained with an example in which we want to force the model to be at least ``time\_startup`` in the startup state:
Consider an operational period ``t``, its previous operator ``t_{prev}``, and the chunck ``t_{next, start}`` which corresponds to an iterator for the next ``n`` operational periods so that the duration of the iterator including the operational period ``t`` is at least as large as the provided value ``time\_startup``.

The constraint is then given as
```math
\begin{aligned}
\sum_{\theta \in t_{next, start}}& \texttt{ref\_start\_b}[m_{ref}, \theta] \geq \\ &
time\_startup(n_{ref}, t) \times (\texttt{ref\_start\_b}[m_{ref}, t]-\texttt{ref\_start\_b}[m_{ref}, t_{prev}])
\end{aligned}
```

It enforces in the case of a state change from 0 to 1 between the previous periods ``t_{prev}`` and the current period ``t`` that the periods following ``t`` up to a total duration of ``time\_startup`` are also 1.