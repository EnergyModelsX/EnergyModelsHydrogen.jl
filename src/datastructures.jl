"""
    `Electrolyzer` subtype of `EnergyModelsBase.Network`.

New fields: `Startup_time`, `Minimum_load`, `Maximum_load`, `Stack_lifetime`. `Degradation_rate` 

# Fields
- **`id`** is the name/identifier of the node.
- **`Cap::TimeProfile`** : Nominal installed capacity
- **`Opex_var::TimeProfile`** :  Variable operational costs per energy unit produced 
- **`Opex_fixed::TimeProfile`** : Fixed operating cost
- **`Stack_replacement_cost::TimeProfile`**: Replacement cost of electrolyzer stack.
- **`Input::Dict{Resource, Real}`**` : Map of input resources to the characteristic flow .
- **`Output::Dict{Resource, Real}`** : Map of output resources to characteristic flow. 
- **`Data::Array{Data}`** : Additional data (e.g., for investments)
- **`Startup_time::Real`** : [WIP - Not implemented] Startup time of the electrolyzer
as a fraction of the operational period (time step).
- **`Minimum_load::Real`** : Minimum load as a fraction of the nominal installed
capacity with potential for investments.
- **`Maximum_load::Real`** : Maximum load as a fraction of the nominal installed
capacity with potential for investments.
- **`Stack_lifetime::Real`** :Total operational equipment life time in hours.
- **`Degradation_rate::Real`**: Percentage drop in efficiency due to degradation in %/1000 h.

**Notes**
- The nominal electrolyzer efficiency is captured through the combination of `Input`
and `Output`.
- Stack replacement can only be done once a strategic period, in the first op.
"""
struct Electrolyzer <: Network
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Stack_replacement_cost::TimeProfile
    Input::Dict{Resource, Real} 
    Output::Dict{Resource, Real}
    Data::Array{Data}
    Startup_time::Real 
    Minimum_load::Real
    Maximum_load::Real
    Stack_lifetime::Real 
    Degradation_rate::Real
end