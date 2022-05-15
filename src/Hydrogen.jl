module Hydrogen

using Revise
using EnergyModelsBase
using JuMP
using TimeStructures
using Geography

const EMB = EnergyModelsBase
const TS  = TimeStructures
const Geo = Geography

include("datastructures.jl")
include("model.jl")
include("user_interface.jl")
include("checks.jl")

end
