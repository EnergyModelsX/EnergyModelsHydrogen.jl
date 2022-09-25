module EnergyModelsHydrogen

using EnergyModelsBase
using JuMP
using TimeStructures

include("datastructures.jl")
include("model.jl")
include("user_interface.jl")
include("checks.jl")

end
