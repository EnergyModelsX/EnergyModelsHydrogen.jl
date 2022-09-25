module EnergyModelsHydrogen

using EnergyModelsBase
using JuMP
using TimeStructures

const EMB = EnergyModelsBase
const TS  = TimeStructures

include("datastructures.jl")
include("model.jl")
include("user_interface.jl")
include("checks.jl")

end
