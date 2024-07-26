""" Abstract supertype for all hydrogen network nodes."""
abstract type AbstractHydrogenNetworkNode <: NetworkNode end


abstract type AbstractLoadLimits{T} end
"""
    LoadLimits{T<:Real} <: AbstractLoadLimits{T}

Type for the incorporation of limits on the capacity utilization of the node through
constraining the variable [`:cap_use`](@extref EnergyModelsBase var_cap).

# Fields
- **`min`** is the minimum load as fraction of the installed capacity.
- **`max`** is the maximum load as fraction of the installed capacity.
"""
struct LoadLimits{T<:Real} <: AbstractLoadLimits{T}
    min::T
    max::T
end

"""
    min_load(n::EMB.Node)
Returns the minimum load of `Node` n.
"""
min_load(n::EMB.Node) = n.load_limits.min
"""
    min_load(n::EMB.Node, t)
Returns the maximum load of `Node` n in operational period `t`.
"""
min_load(n::EMB.Node, t) = n.load_limits.min

"""
    max_load(n::EMB.Node)
Returns the maximum load of `Node` n.
"""
max_load(n::EMB.Node) = n.load_limits.max
"""
    max_load(n::EMB.Node, t)
Returns the maximum load of `Node` n in operational period `t`.
"""
max_load(n::EMB.Node, t) = n.load_limits.max

""" Abstract supertype for all electrolyzer nodes."""
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
Returns the stack replacement costs of electrolyzer `n` as `TimeProfile`.
"""
stack_replacement_cost(n::AbstractElectrolyzer) = n.stack_replacement_cost
"""
    stack_replacement_cost(n::Electrolyzer, t_inv)
Returns the stack replacement costs of electrolyzer `n` in investment period `t_inv`.
"""
stack_replacement_cost(n::AbstractElectrolyzer, t_inv) = n.stack_replacement_cost[t_inv]

"""
    stack_lifetime(n::Electrolyzer)
Returns the stack lfetime of electrolyzer `n`.
"""
stack_lifetime(n::AbstractElectrolyzer) = n.stack_lifetime

""" Abstract supertype for all reformer nodes."""
abstract type AbstractReformer <: AbstractHydrogenNetworkNode end

EMB.has_emissions(n::AbstractReformer) = true

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
    opex(com_par::CommitParameters)

Returns the unit commitment OPEX as `TimeProfile`.
"""
opex(com_par::CommitParameters) = com_par.opex
"""
    opex(com_par::CommitParameters, t)

Returns the unit commitment OPEX in operational period `t`.
"""
opex(com_par::CommitParameters, t) = com_par.opex[t]

"""
    opex(com_par::CommitParameters)

Returns the minimum time in the state as `TimeProfile`.
"""
state_time(com_par::CommitParameters) = com_par.time
"""
    opex(com_par::CommitParameters, t)

Returns the minimum time in the state in operational period `t`.
"""
state_time(com_par::CommitParameters, t) = com_par.time[t]

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

- **`opex_startup::TimeProfile`** is the start-up cost per installed capacity and
  operational duration.
- **`opex_shutdown::TimeProfile`** is the shut-down cost per installed capacity and
  operational duration.
- **`opex_off::TimeProfile`** is the operational cost when the node is offline per installed
  capacity and operational duration.

- **`t_startup::TimeProfile`** is the minimum start-up time.
- **`t_shutdown::TimeProfile`** is the minimum shut-down time.
- **`t_off::TimeProfile`** is the minimum time the node is offline.


!!! note
    - If you introduce CO₂ capture through the application of
      [`CaptureEnergyEmissions`](@extref EnergyModelsBase.CaptureEnergyEmissions),
      you have to add your CO₂ instance as output. The reason for this is that we declare the
      variable `:output` through the output dictionary.
    - The specified startup, shutdown, and offline costs are relative to the installed
      capacity and a duration of 1 of an operational period.
"""
struct Reformer <: AbstractReformer
	id::Any
	cap::TimeProfile
	opex_var::TimeProfile
	opex_fixed::TimeProfile
	input::Dict{Resource, Real}
	output::Dict{Resource,Real}
	data::Array{Data}

    load_limits::AbstractLoadLimits

    startup::CommitParameters
    shutdown::CommitParameters
    offline::CommitParameters
end

"""
    opex_startup(n::Reformer)

Returns the startup OPEX of a Reformer `n` as `TimeProfile`.
"""
opex_startup(n::Reformer) = opex(n.startup)
"""
    opex_startup(n::Reformer, t)

Returns the startup OPEX of a Reformer `n` in operational period `t`.
"""
opex_startup(n::Reformer, t) = opex(n.startup, t)

"""
    opex_shutdown(n::Reformer)

Returns the shutdown OPEX of a Reformer `n` as `TimeProfile`.
"""
opex_shutdown(n::Reformer) = opex(n.shutdown)
"""
    opex_shutdown(n::Reformer, t)

Returns the shutdown OPEX of a Reformer `n` in operational period `t`.
"""
opex_shutdown(n::Reformer, t) = opex(n.shutdown, t)

"""
    opex_off(n::Reformer)

Returns the offline OPEX of a Reformer `n` as `TimeProfile`.
"""
opex_off(n::Reformer) = opex(n.offline)
"""
    opex_off(n::Reformer, t)

Returns the offline OPEX of a Reformer `n` in operational period `t`.
"""
opex_off(n::Reformer, t) = opex(n.offline, t)

"""
    t_startup(n::Reformer)

Returns the minimum startup time of a Reformer `n` as `TimeProfile`.
"""
t_startup(n::Reformer) = state_time(n.startup)
"""
    t_startup(n::Reformer, t)

Returns the minimum startup time of a Reformer `n` in operational period `t`.
"""
t_startup(n::Reformer, t) = state_time(n.startup, t)

"""
    t_shutdown(n::Reformer)

Returns the minimum shutdown time of a Reformer `n` as `TimeProfile`.
"""
t_shutdown(n::Reformer) = state_time(n.shutdown)
"""
    t_shutdown(n::Reformer, t)

Returns the minimum shutdown time of a Reformer `n` in operational period `t`.
"""
t_shutdown(n::Reformer, t) = state_time(n.shutdown, t)

"""
    t_off(n::Reformer)

Returns the minimum offline time of a Reformer `n` as `TimeProfile`.
"""
t_off(n::Reformer) = state_time(n.offline)
"""
    t_off(n::Reformer, t)

Returns the minimum offline time of a Reformer `n` in operational period `t`.
"""
t_off(n::Reformer, t) = state_time(n.offline, t)
