""" Abstract supertype for all hydrogen network nodes."""
abstract type AbstractHydrogenNetworkNode <: NetworkNode end

"""
    min_load(n::AbstractHydrogenNetworkNode)
Returns the minimum load of `Node` n.
"""
min_load(n::AbstractHydrogenNetworkNode) = n.min_load

"""
    max_load(n::AbstractHydrogenNetworkNode)
Returns the maximum load of `Node` n.
"""
max_load(n::AbstractHydrogenNetworkNode) = n.max_load

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
- **`min_load::Real`** is the minimum load as a fraction of the nominal installed capacity
  with potential for investments.
- **`max_load::Real`** is the maximum load as a fraction of the nominal installed capacity
  with potential for investments.
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
    min_load::Real
    max_load::Real
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
- **`min_load::Real`** is the minimum load as a fraction of the nominal installed capacity
  with potential for investments.
- **`max_load::Real`** is the maximum load as a fraction of the nominal installed capacity
  with potential for investments.
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
    min_load::Real
    max_load::Real
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

- **`opex_startup::TimeProfile`** is the start-up cost per installed capacity and
  operational duration.
- **`opex_shutdown::TimeProfile`** is the shut-down cost per installed capacity and
  operational duration.
- **`opex_off::TimeProfile`** is the operational cost when the node is offline per installed
  capacity and operational duration.

- **`t_startup::TimeProfile`** is the minimum start-up time.
- **`t_shutdown::TimeProfile`** is the minimum shut-down time.
- **`t_off::TimeProfile`** is the minimum time the node is offline.

- **`min_load::Real`** is the minimum load as a fraction of the nominal installed capacity
  with potential for investments.
- **`max_load::Real`** is the maximum load as a fraction of the nominal installed capacity
  with potential for investments.


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

	opex_startup::TimeProfile
	opex_shutdown::TimeProfile
	opex_off::TimeProfile

	t_startup::TimeProfile
	t_shutdown::TimeProfile
	t_off::TimeProfile

    min_load::Real
    max_load::Real
end

"""
    opex_startup(n::Reformer)

Returns the startup OPEX of a Reformer `n` as `TimeProfile`.
"""
opex_startup(n::Reformer) = n.opex_startup
"""
    opex_startup(n::Reformer, t)

Returns the startup OPEX of a Reformer `n` in operational period `t`.
"""
opex_startup(n::Reformer, t) = n.opex_startup[t]

"""
    opex_shutdown(n::Reformer)

Returns the shutdown OPEX of a Reformer `n` as `TimeProfile`.
"""
opex_shutdown(n::Reformer) = n.opex_shutdown
"""
    opex_shutdown(n::Reformer, t)

Returns the shutdown OPEX of a Reformer `n` in operational period `t`.
"""
opex_shutdown(n::Reformer, t) = n.opex_shutdown[t]

"""
    opex_off(n::Reformer)

Returns the offline OPEX of a Reformer `n` as `TimeProfile`.
"""
opex_off(n::Reformer) = n.opex_off
"""
    opex_off(n::Reformer, t)

Returns the offline OPEX of a Reformer `n` in operational period `t`.
"""
opex_off(n::Reformer, t) = n.opex_off[t]

"""
    t_startup(n::Reformer)

Returns the minimum startup time of a Reformer `n` as `TimeProfile`.
"""
t_startup(n::Reformer) = n.t_startup
"""
    t_startup(n::Reformer, t)

Returns the minimum startup time of a Reformer `n` in operational period `t`.
"""
t_startup(n::Reformer, t) = n.t_startup[t]

"""
    t_shutdown(n::Reformer)

Returns the minimum shutdown time of a Reformer `n` as `TimeProfile`.
"""
t_shutdown(n::Reformer) = n.t_shutdown
"""
    t_shutdown(n::Reformer, t)

Returns the minimum shutdown time of a Reformer `n` in operational period `t`.
"""
t_shutdown(n::Reformer, t) = n.t_shutdown[t]

"""
    t_off(n::Reformer)

Returns the minimum offline time of a Reformer `n` as `TimeProfile`.
"""
t_off(n::Reformer) = n.t_off
"""
    t_off(n::Reformer, t)

Returns the minimum offline time of a Reformer `n` in operational period `t`.
"""
t_off(n::Reformer, t) = n.t_off[t]
