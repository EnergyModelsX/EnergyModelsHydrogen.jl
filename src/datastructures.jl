
# This file contains the additional data structures required for the EnergyModelsHydrogen package. 
# The new structure members are added after listing all the original members.
"""
    `Electrolyzer` subtype of `EnergyModelsBase.Network`.
New fields: `Startup_time`, `Minimum_load`, `Maximum_load`, `Equipment_lifetime`. `Degradation_rate` 
# Fields
- **`id`** : Name of node
- **`Cap::TimeProfile`** : Nominal installed capacity
- **`Opex_var::TimeProfile`** :  Variable operational costs per energy unit produced 
- **`Opex_fixed::TimeProfile`** : Fixed operating cost
- **`Stack_replacement_cost::TimeProfile`**: Replacement cost of electrolyzer stack. **Note**: Stack replacement can only be done once a strategic period, in first op.
- **`Input::Dict{EMB.Resource, Real}`**` : Map of input resources to the characteristic flow 
- **`Output::Dict{EMB.Resource, Real}`** : Map of output resources to characteristic flow. 
- **`Emissions::Dict{EMB.ResourceEmit, Real}`** : Map of emitting outputs to characteristic flow
- **`CO2_capture::Real`** : CO2 capture rate
- **`Data::Dict{String,EMB.Data}`** : Additional data (e.g., for investments)
- **`Startup_time::Real`** : [WIP - Not implemented] Startup time of the electrolyzer as a fraction of the operational period (time step)
- **`Minimum_load::Real`** : Minimum load as a fraction of the nominal installed capacity `Cap` above
- **`Maximum_load::Real`** : Maximum load as a fraction of the nominal installed capacity `Cap` above
- **`Equipment_lifetime::Real`** :Total operational equipment life time as multiple of operational period (time step)
- **`Degradation_rate::Real`**: Percentage drop in efficiency due to degradation

**Notes**
- The nominal electrolyzer efficiency is captured in one of the values in "Input" or "Output".

"""
struct Electrolyzer <: Network
    id
    Cap::TimeProfile
    Opex_var::TimeProfile
    Opex_fixed::TimeProfile
    Stack_replacement_cost::TimeProfile # Question: indexed by t_inv?
    Input::Dict{Resource, Real} 
    Output::Dict{Resource, Real}
    Emissions::Dict{ResourceEmit, Real} 
    CO2_capture::Real 
    Data::Dict{String, Data}
    Startup_time::Real 
    Minimum_load::Real
    Maximum_load::Real
    Equipment_lifetime::Real 
    Degradation_rate::Real
end