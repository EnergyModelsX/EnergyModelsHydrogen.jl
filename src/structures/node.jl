""" Abstract supertype for all hydrogen network nodes."""
abstract type AbstractHydrogenNetworkNode <: NetworkNode end

"""
    AbstractLoadLimits{T}

Abstract type for the load limits. This type can be used to incorporate other types for the
load limit.
"""
abstract type AbstractLoadLimits{T} end

"""
    LoadLimits{T<:Real} <: AbstractLoadLimits{T}

Type for the incorporation of limits on the capacity utilization of the node through
constraining the variable [`:cap_use`](@extref EnergyModelsBase man-opt_var-cap).

# Fields
- **`min`** is the minimum load as fraction of the installed capacity.
- **`max`** is the maximum load as fraction of the installed capacity.
"""
struct LoadLimits{T<:Real} <: AbstractLoadLimits{T}
    min::T
    max::T
end

"""
    min_load(load_lim::AbstractLoadLimits)
    min_load(load_lim::AbstractLoadLimits, t)

Returns the minimum load of `AbstractLoadLimits` load_lim as `TimeProfile` *or* in operational
period `t`.

!!! note
    The default [`LoadLimits`](@ref) does not allow for time dependent load limits. In this
    case, the function returns a `FixedProfile` of the provided value.
"""
min_load(load_lim::AbstractLoadLimits) = FixedProfile(load_lim.min)
min_load(load_lim::AbstractLoadLimits, t) = load_lim.min
"""
    min_load(n::EMB.Node)
    min_load(n::EMB.Node, t)

Returns the minimum load of `Node` n as `TimeProfile` *or* in operational period `t`.
"""
min_load(n::EMB.Node) = min_load(n.load_limits)
min_load(n::EMB.Node, t) = min_load(n.load_limits, t)

"""
    max_load(load_lim::AbstractLoadLimits)
    min_load(load_lim::AbstractLoadLimits, t)

Returns the maximum load of `AbstractLoadLimits` load_lim as `TimeProfile` *or* in operational
period `t`.

!!! note
    The default [`LoadLimits`](@ref) does not allow for time dependent load limits. In this
    case, the function returns a `FixedProfile` of the provided value.
"""
max_load(load_lim::AbstractLoadLimits) = FixedProfile(load_lim.max)
max_load(load_lim::AbstractLoadLimits, t) = load_lim.max
"""
    max_load(n::EMB.Node)
    max_load(n::EMB.Node, t)

Returns the maximum load of `Node` n.
"""
max_load(n::EMB.Node) = max_load(n.load_limits)
max_load(n::EMB.Node, t) = max_load(n.load_limits, t)

"""
    AbstractElectrolyzer <: AbstractHydrogenNetworkNode

Abstract supertype for all electrolyzer nodes.
"""
abstract type AbstractElectrolyzer <: AbstractHydrogenNetworkNode end

"""
    Electrolyzer <: AbstractElectrolyzer

Description of an electrolyzer node with minimum and maximum load as well as degredation
and stack replacement.

New fields: `min_load`, `max_load`, `stack_lifetime`, `stack_replacement_cost`, and
`degradation_rate`.

# Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed capacity.
- **`opex_var::TimeProfile`** is the variable operating expense per capacity used (through
  the variable `:cap_use`).
- **`opex_fixed::TimeProfile`** is the fixed operating expense per installed capacity.
- **`input::Dict{<:Resource, <:Real}`** are the input
  [`Resource`](@extref EnergyModelsBase.Resource)s with conversion value `Real`.
- **`output::Dict{<:Resource, <:Real}`** are the produced
  [`Resource`](@extref EnergyModelsBase.Resource)s with conversion value `Real`.
- **`data::Vector{Data}`** is the additional data (e.g. for investments).
- **`load_limits::LoadLimits`** are limits on the utilization load of the electrolyser.
  [`LoadLimits`](@ref) can provide both lower and upper limits on the actual load.
- **`degradation_rate::Real`** is the percentage drop in efficiency due to degradation in
  %/1000 h.
- **`stack_replacement_cost::TimeProfile`** is the replacement cost of electrolyzer stacks.
- **`stack_lifetime::Real`** is the total operational stack life time.

!!! note
    - The nominal electrolyzer efficiency is captured through the combination of `input`
      and `output`.
    - The fixed and variable operating expenses are always related to installed capacity and
      its usage. This implies if you define the capacity *via* the input through a value of
      1, then the variable operating expense is calaculated through the required electricity.
    - Stack replacement can only be done once a strategic period, in the first operational
      period. The thought process behind is that it would otherwise lead to issues if a
      strategic period is repeated.
"""
struct Electrolyzer <: AbstractElectrolyzer
    id
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{Resource, Real}
    output::Dict{Resource, Real}
    data::Array{<:Data}
    load_limits::AbstractLoadLimits
    degradation_rate::Real
    stack_replacement_cost::TimeProfile
    stack_lifetime::Real
end

"""
    SimpleElectrolyzer <: AbstractElectrolyzer

Description of a simple electrolyzer node with minimum and maximum load as well as stack
replacement. Degradation is calculated, but not used for the efficiency calculations.

New fields compared to `NetworkNode`: `min_load`, `max_load`, `degradation_rate`,
`stack_lifetime`, and `stack_replacement_cost`.

# Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed capacity.
- **`opex_var::TimeProfile`** is the variable operating expense per capacity usage.
- **`opex_fixed::TimeProfile`** is the fixed operating expense per installed capacity.
- **`input::Dict{<:Resource, <:Real}`** are the input
  [`Resource`](@extref EnergyModelsBase.Resource)s with conversion value `Real`.
- **`output::Dict{<:Resource, <:Real}`** are the produced
  [`Resource`](@extref EnergyModelsBase.Resource)s with conversion value `Real`.
- **`data::Vector{Data}`** is the additional data (e.g. for investments).
- **`load_limits::LoadLimits`** are limits on the utilization load of the electrolyser.
  [`LoadLimits`](@ref) can provide both lower and upper limits on the actual load.
- **`degradation_rate::Real`** is the percentage drop in efficiency due to degradation in
  %/1000 h.
- **`stack_replacement_cost::TimeProfile`** is the replacement cost of electrolyzer stacks.
- **`stack_lifetime::Real`** is the total operational stack life time.

!!! note
    - The nominal electrolyzer efficiency is captured through the combination of `input`
      and `output`.
    - The fixed and variable operating expenses are always related to installed capacity and
      its usage. This implies if you define the capacity *via* the input through a value of
      1, then the variable operating expense is calaculated through the required electricity.
    - Stack replacement can only be done once a strategic period, in the first operational
      period. The thought process behind is that it would otherwise lead to issues if a
      strategic period is repeated.
"""
struct SimpleElectrolyzer <: AbstractElectrolyzer
    id
    cap::TimeProfile
    opex_var::TimeProfile
    opex_fixed::TimeProfile
    input::Dict{Resource, Real}
    output::Dict{Resource, Real}
    data::Array{Data}
    load_limits::AbstractLoadLimits
    degradation_rate::Real
    stack_replacement_cost::TimeProfile
    stack_lifetime::Real
end

"""
    degradation_rate(n::Electrolyzer)
Returns the degradation rate of electrolyzer `n`.
"""
degradation_rate(n::AbstractElectrolyzer) = n.degradation_rate

"""
    stack_replacement_cost(n::Electrolyzer)
    stack_replacement_cost(n::Electrolyzer, t_inv)

Returns the stack replacement costs of electrolyzer `n` as `TimeProfile` *or* in strategic
period `t_inv`.
"""
stack_replacement_cost(n::AbstractElectrolyzer) = n.stack_replacement_cost
stack_replacement_cost(n::AbstractElectrolyzer, t_inv) = n.stack_replacement_cost[t_inv]

"""
    stack_lifetime(n::Electrolyzer)
Returns the stack lfetime of electrolyzer `n`.
"""
stack_lifetime(n::AbstractElectrolyzer) = n.stack_lifetime

"""
    struct CommitParameters

Type for providing parameters required in unit commitment constraints.

# Fields
- **`opex::TimeProfile`** is the cost profile per installed capacity and operational
  duration if the node is within the state.
- **`time::TimeProfile`** is the minimum time the node has to remain in the state before
  it can transition to the next state.
"""
struct CommitParameters
    opex::TimeProfile
    time::TimeProfile
end
"""
    AbstractRampParameters

Abstract type for different ramp parameter configurations.
"""
abstract type AbstractRampParameters end

"""
    struct RampBi <: AbstractRampParameters

Parameters for both positive and negative ramping constraints for a node.

# Fields
- **`up::TimeProfile`** is the maximum positive rate of change of a node.
- **`down::TimeProfile`** is the maximum negative rate of change of a node.

!!! note
    The same profile is used for positive and negative bounds if you provide only a single
    `TimeProfile` as input.
"""
struct RampBi <: AbstractRampParameters
    up::TimeProfile
    down::TimeProfile
end
RampBi(profile) = RampBi(profile, profile)

"""
    struct RampUp <: AbstractRampParameters

Parameters for positive ramping constraints for a node.

# Fields
- **`up::TimeProfile`** is the maximum positive rate of change of a node.
"""
struct RampUp <: AbstractRampParameters
    up::TimeProfile
end

"""
    struct RampDown <: AbstractRampParameters

Parameters for negative ramping constraints for a node.

# Fields
- **`down::TimeProfile`** is the maximum negative rate of change of a node.
"""
struct RampDown <: AbstractRampParameters
    down::TimeProfile
end

"""
    struct RampNone <: AbstractRampParameters

Parameters when no ramping constraints should be included.
"""
struct RampNone <: AbstractRampParameters
end

UnionRampDown = Union{RampBi, RampDown}
"""
    ramp_down(ramp_param::UnionRampDown)
    ramp_down(ramp_param::UnionRampDown, t)

Returns the maximum negative rate of change aof UnionRampDown `ramp_param` as `TimeProfile`
*or* in operational period `t`.
"""
ramp_down(ramp_param::UnionRampDown) = ramp_param.down
ramp_down(ramp_param::UnionRampDown, t) = ramp_param.down[t]

UnionRampUp = Union{RampBi, RampUp}
"""
    ramp_up(ramp_param::UnionRampUp)
    ramp_up(ramp_param::UnionRampUp, t)

Returns the maximum positive rate of change of UnionRampUp `ramp_param` as `TimeProfile`
*or* in operational period `t`.
"""
ramp_up(ramp_param::UnionRampUp) = ramp_param.up
ramp_up(ramp_param::UnionRampUp, t) = ramp_param.up[t]

""" Abstract supertype for all reformer nodes."""
abstract type AbstractReformer <: AbstractHydrogenNetworkNode end

"""
    opex_state(com_par::CommitParameters)
    opex_state(com_par::CommitParameters, t)

Returns the unit commitment OPEX as `TimeProfile` *or* in operational period `t`.
"""
opex_state(com_par::CommitParameters) = com_par.opex
opex_state(com_par::CommitParameters, t) = com_par.opex[t]

"""
    time_state(com_par::CommitParameters)
    time_state(com_par::CommitParameters, t)

Returns the minimum time in the state as `TimeProfile` *or* in operational period `t`.
"""
time_state(com_par::CommitParameters) = com_par.time
time_state(com_par::CommitParameters, t) = com_par.time[t]

"""
    Reformer <: AbstractReformer

A network node with start-up and shut-down time and costs that should be used for reformer
technology descriptions.

# Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** is the installed capacity.
- **`opex_var::TimeProfile`** is the variable operating expense per capacity usage.
- **`opex_fixed::TimeProfile`** is the fixed operating expense per installed capacity.
- **`input::Dict{<:Resource, <:Real}`** are the input
  [`Resource`](@extref EnergyModelsBase.Resource)s with conversion value `Real`.
- **`output::Dict{<:Resource, <:Real}`** are the produced
  [`Resource`](@extref EnergyModelsBase.Resource)s with conversion value `Real`.
- **`data::Array{Data}`** is an array of additional data (e.g., for investments).

- **`load_limits::LoadLimits`** are limits on the utilization load of the electrolyser.
  [`LoadLimits`](@ref) can provide both lower and upper limits on the actual load.

- **`startup::CommitParameters`** are parameters for the startup state constraints.
- **`shutdown::CommitParameters`** are parameters for the shutdown state constraints.
- **`offline::CommitParameters`** are parameters for the offline state constraints.

- **`ramp_limit::AbstractRampParameters`** are the limit on the allowable change in the
  capacity usage.

!!! note
    - If you introduce CO₂ capture through the application of
      [`CaptureEnergyEmissions`](@extref EnergyModelsBase.CaptureEnergyEmissions),
      you have to add your CO₂ instance as output. The reason for this is that we declare the
      variable `:output` through the `output` dictionary.
    - The specified startup, shutdown, and offline costs are relative to the installed
      capacity and a duration of 1 of an operational period.
    - The rate limit is relative to the installed capacity and a duration of 1 of an
      operational period.
"""
struct Reformer <: AbstractReformer
	id::Any
	cap::TimeProfile
	opex_var::TimeProfile
	opex_fixed::TimeProfile
	input::Dict{Resource, Real}
	output::Dict{Resource, Real}
	data::Array{Data}

    load_limits::AbstractLoadLimits

    startup::CommitParameters
    shutdown::CommitParameters
    offline::CommitParameters

    ramp_limit::AbstractRampParameters
end

"""
    opex_startup(n::AbstractReformer)
    opex_startup(n::AbstractReformer, t)

Returns the startup OPEX of AbstractReformer `n` as `TimeProfile` *or* in
in operational period `t`.
"""
opex_startup(n::AbstractReformer) = opex_state(n.startup)
opex_startup(n::AbstractReformer, t) = opex_state(n.startup, t)

"""
    opex_shutdown(n::AbstractReformer)
    opex_shutdown(n::AbstractReformer, t)

Returns the shutdown OPEX of AbstractReformer `n` as `TimeProfile` *or* in
in operational period `t`.
"""
opex_shutdown(n::AbstractReformer) = opex_state(n.shutdown)
opex_shutdown(n::AbstractReformer, t) = opex_state(n.shutdown, t)

"""
    opex_off(n::AbstractReformer)
    opex_off(n::AbstractReformer, t)

Returns the offline OPEX of AbstractReformer `n` as `TimeProfile` *or* in
in operational period `t`.
"""
opex_off(n::AbstractReformer) = opex_state(n.offline)
opex_off(n::AbstractReformer, t) = opex_state(n.offline, t)

"""
    time_startup(n::AbstractReformer)
    time_startup(n::AbstractReformer, t)

Returns the minimum startup time of AbstractReformer `n` as `TimeProfile` *or* in
in operational period `t`.
"""
time_startup(n::AbstractReformer) = time_state(n.startup)
time_startup(n::AbstractReformer, t) = time_state(n.startup, t)

"""
    time_shutdown(n::AbstractReformer)
    time_shutdown(n::AbstractReformer, t)

Returns the minimum shutdown time of AbstractReformer `n` as `TimeProfile` *or* in
in operational period `t`.
"""
time_shutdown(n::AbstractReformer) = time_state(n.shutdown)
time_shutdown(n::AbstractReformer, t) = time_state(n.shutdown, t)

"""
    time_off(n::AbstractReformer)
    time_off(n::AbstractReformer, t)

Returns the minimum offline time of AbstractReformer `n` as `TimeProfile` *or* in
in operational period `t`.
"""
time_off(n::AbstractReformer) = time_state(n.offline)
time_off(n::AbstractReformer, t) = time_state(n.offline, t)

"""
    ramp_limit(n::AbstractReformer)

Returns the `AbstractRampParameters` type of AbstractReformer `n`.
"""
ramp_limit(n::AbstractReformer) = n.ramp_limit

"""
    ramp_up(n::AbstractReformer)
    ramp_up(n::AbstractReformer, t)

Returns the maximum positive rate of change of AbstractReformer `n` as `TimeProfile` *or* in
operational period `t`.
"""
ramp_up(n::AbstractReformer) = ramp_up(ramp_limit(n))
ramp_up(n::AbstractReformer, t) = ramp_up(ramp_limit(n), t)

"""
    ramp_down(n::AbstractReformer)
    ramp_down(n::AbstractReformer, t)

Returns the maximum negative rate of change of AbstractReformer `n` as `TimeProfile` *or* in
operational period `t`.
"""
ramp_down(n::AbstractReformer) = ramp_down(ramp_limit(n))
ramp_down(n::AbstractReformer, t) = ramp_down(ramp_limit(n), t)

"""
    AbstractH2Storage{T} <: Storage{T}

Abstract type for different implementations of hydrogen storage nodes.
"""
abstract type AbstractH2Storage{T} <: Storage{T} end

"""
    SimpleHydrogenStorage{T} <: AbstractH2Storage{T}

`Storage` node in which the maximum discharge usage is directly linked to the charge
capacity, that is it is not possbible to have a larger discharge usage than the charge
capacity and a multiplier `discharge_charge`.

# Fields
- **`id`** is the name/identifier of the node.
- **`charge::EMB.UnionCapacity`** are the charging parameters of the `SimpleHydrogenStorage` node.
  Depending on the chosen type, the charge parameters can include variable OPEX, fixed OPEX,
  and/or a capacity.
- **`level::EMB.UnionCapacity`** are the level parameters of the `SimpleHydrogenStorage` node.
  Depending on the chosen type, the charge parameters can include variable OPEX and/or fixed OPEX.
- **`stor_res::Resource`** is the stored [`Resource`](@extref EnergyModelsBase.Resource).
- **`input::Dict{<:Resource, <:Real}`** are the input [`Resource`](@extref EnergyModelsBase.Resource)s
  with conversion value `Real`.
- **`output::Dict{<:Resource, <:Real}`** are the generated [`Resource`](@extref EnergyModelsBase.Resource)s
  with conversion value `Real`. Only relevant for linking and the stored
  [`Resource`](@extref EnergyModelsBase.Resource) as the output value is not utilized in the calculations.
- **`data::Vector{<:Data}`** is the additional data (*e.g.*, for investments). The field `data`
  is conditional through usage of a constructor.
- **`discharge_charge::Float64`** is the multiplier for specifying the maximum discharge
  rate relative to the charge rate. A value of `2.0` would imply that it is possible to have
  double the discharge rate compared to the installed charge capacity.
- **`level_charge::Float64`** is the multiplier for specifying the installed storage
  level capacity relative to the installed storage charge capacity. It is used for
  checking input data in the case of a generic model and for limiting investments in
  the case of an [`AbstractInvestmentModel`](@extref EnergyModelsBase.AbstractInvestmentModel).
"""
struct SimpleHydrogenStorage{T} <: AbstractH2Storage{T}
    id::Any
    charge::EMB.UnionCapacity
    level::EMB.UnionCapacity
    stor_res::Resource
    input::Dict{<:Resource,<:Real}
    output::Dict{<:Resource,<:Real}
    data::Vector{<:Data}
    discharge_charge::Float64
    level_charge::Float64
end
function SimpleHydrogenStorage{T}(
    id::Any,
    charge::EMB.UnionCapacity,
    level::EMB.UnionCapacity,
    stor_res::Resource,
    input::Dict{<:Resource,<:Real},
    output::Dict{<:Resource,<:Real},
    discharge_charge::Float64,
    level_charge::Float64,
) where {T<:EMB.StorageBehavior}
    return SimpleHydrogenStorage{T}(
        id,
        charge,
        level,
        stor_res,
        input,
        output,
        Data[],
        discharge_charge,
        level_charge,
    )
end


"""
    discharge_charge(n::AbstractH2Storage)

Returns the discharge to charge ratio of AbstractH2Storage `n`.
"""
discharge_charge(n::AbstractH2Storage) = n.discharge_charge

"""
    level_charge(n::AbstractH2Storage)

Returns the level to charge ratio of AbstractH2Storage `n`.
"""
level_charge(n::AbstractH2Storage) = n.level_charge
