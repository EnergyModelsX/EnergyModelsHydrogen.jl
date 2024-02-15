""" Abstract supertype for all electrolyzer nodes."""
abstract type AbstractElectrolyzer <: NetworkNode end

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
- **`data::Array{Data}`** : Additional data (e.g., for investments)
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
    data::Array{Data}
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
- **`opex_var::TimeProfile`** :  Variable operational costs per energy unit produced
- **`opex_fixed::TimeProfile`** : Fixed operating cost
- **`stack_replacement_cost::TimeProfile`**: Replacement cost of electrolyzer stack.
- **`input::Dict{Resource, Real}`**` : Map of input resources to the characteristic flow .
- **`output::Dict{Resource, Real}`** : Map of output resources to characteristic flow.
- **`data::Array{Data}`** : Additional data (e.g., for investments)
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
