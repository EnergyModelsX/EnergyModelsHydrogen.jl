#=
This file contains the additional data structures required for the hydrogen package. The new structure members are added after listing all the original members.
=#
"Electrolyzer with degradation, load ranges and equipment lifetime"
struct Electrolyzer <: EMB.Network
    id
    Cap::TimeProfile # Nominal installed capacity
    Opex_var::TimeProfile # Variable operating cost 
    Opex_fixed::TimeProfile # Fixed operating cost
    Input::Dict{EMB.Resource, Real} # Map of input resources to the characteristic flow 
    Output::Dict{EMB.Resource, Real} # Map of output resources to characteristic flow. The NOMINAL electrolyzer efficiency is captured in one of the values in "Input" or "Output"
    Emissions::Dict{EMB.ResourceEmit, Real} # Map of emitting outputs to characteristic flow
    CO2_capture::Real # CO2 capture rate
    Data::Dict{String,EMB.Data} # Additional data
    Startup_time::Real # Startup time of the electrolyzer as a fraction of the operational period
    Minimum_load::Real # Minimum load as a fraction of the nominal installed capacity "Cap" above
    Maximum_load::Real # Maximum load as a fraction of the nominal installed capacity "Cap" above
    Equipment_lifetime::Real # Total operational equipment life time as a multiple of the operational period
    Degradation_rate::Real # Percentage drop in efficiency in each operational period [QN: Make it in %drop in effective installed capacity for easier reasoning?]
end