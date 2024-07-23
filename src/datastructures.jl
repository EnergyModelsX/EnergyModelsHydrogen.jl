""" Abstract supertype for all hydrogen network nodes."""
abstract type AbstractHydrogenNetworkNode <: NetworkNode end

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
- **`cap::TimeProfile`** : Nominal installed capacity
- **`opex_var::TimeProfile`** :  Variable operational costs per energy unit produced
- **`opex_fixed::TimeProfile`** : Fixed operating cost
- **`stack_replacement_cost::TimeProfile`**: Replacement cost of electrolyzer stack.
- **`input::Dict{Resource, Real}`**` : Map of input resources to the characteristic flow .
- **`output::Dict{Resource, Real}`** : Map of output resources to characteristic flow.
- **`data::Array{<:Data}`** : Additional data (e.g., for investments)
- **`min_load::Real`** : Minimum load as a fraction of the nominal installed
capacity with potential for investments.
- **`max_load::Real`** : Maximum load as a fraction of the nominal installed
capacity with potential for investments.
- **`stack_lifetime::Real`** :Total operational equipment life time in hours.
- **`degradation_rate::Real`**: Percentage drop in efficiency due to degradation in %/1000 h.

**Notes**
- The nominal electrolyzer efficiency is captured through the combination of `input`
and `output`.
- Stack replacement can only be done once a strategic period, in the first op.
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

New fields: `min_load`, `max_load`, `stack_lifetime`, `stack_replacement_cost`, and
`degradation_rate`.

# Fields
- **`id`** is the name/identifier of the node.
- **`cap::TimeProfile`** : Nominal installed capacity
- **`opex_var::TimeProfile`** is the variable operating expense per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operating expense.
- **`stack_replacement_cost::TimeProfile`** is the replacement cost of electrolyzer stacks.
- **`input::Dict{<:Resource, <:Real}`** are the input `Resource`s with conversion
  value `Real`.
- **`output::Dict{<:Resource, <:Real}`** are the generated `Resource`s with
  conversion value `Real`.
- **`data::Array{Data}`** : Additional data (e.g., for investments)
- **`min_load::Real`** is the minimum load as a fraction of the nominal installed capacity
  with potential for investments.
- **`max_load::Real`** is the maximum load as a fraction of the nominal installed capacity
  with potential for investments.
- **`stack_lifetime::Real`** is the total operational stack life time.
- **`degradation_rate::Real`** is the percentage drop in efficiency due to degradation in
  %/1000 h.

**Notes**
- The nominal electrolyzer efficiency is captured through the combination of `input`
and `output`.
- Stack replacement can only be done once a strategic period, in the first op.
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
    min_load(n)
Returns the minimum load of `Node` n.
"""
min_load(n::EMB.Node) = n.min_load

"""
    max_load(n)
Returns the maximum load of `Node` n.
"""
max_load(n::EMB.Node) = n.max_load

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
- **`opex_var::TimeProfile`** is the variational operational costs per energy unit produced.
- **`opex_fixed::TimeProfile`** is the fixed operational costs.
- **`input::Dict{Resource, Real}`** is a dictionary of input resources.
- **`output::Dict{Resource, Real}`** is a dictionary of output resources.
- **`data::Array{Data}`** is an array of additional data (e.g., for investments

- **`opex_startup::TimeProfile`** is the start-up cost.
- **`opex_shutdown::TimeProfile`** is the shut-down cost.
- **`opex_off::TimeProfile`** is the operational cost when the node is offline.

- **`t_startup::TimeProfile`** is the start-up time.
- **`t_shutdown::TimeProfile`** is the shut-down time.
- **`t_off::TimeProfile`** is the time the node is off.

- **`min_load::Real`** is the minimum load as a fraction of the nominal installed capacity
  with potential for investments.
- **`max_load::Real`** is the maximum load as a fraction of the nominal installed capacity
  with potential for investments.
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

opex_startup(n::Reformer) = n.opex_startup
opex_startup(n::Reformer, t) = n.opex_startup[t]
opex_shutdown(n::Reformer) = n.opex_shutdown
opex_shutdown(n::Reformer, t) = n.opex_shutdown[t]
opex_off(n::Reformer) = n.opex_off
opex_off(n::Reformer, t) = n.opex_off[t]


t_startup(n::Reformer) = n.t_startup
t_startup(n::Reformer, t) = n.t_startup[t]
t_shutdown(n::Reformer) = n.t_shutdown
t_shutdown(n::Reformer, t) = n.t_shutdown[t]
t_off(n::Reformer) = n.t_off
t_off(n::Reformer, t) = n.t_off[t]
