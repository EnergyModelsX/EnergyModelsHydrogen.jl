module EMIExt

using EnergyModelsBase
using EnergyModelsHydrogen
using EnergyModelsInvestments
using JuMP
using TimeStruct

const EMB = EnergyModelsBase
const EMH = EnergyModelsHydrogen
const EMI = EnergyModelsInvestments
const TS = TimeStruct

include("checks.jl")
include("model.jl")
include("constraint_functions.jl")
include("utils.jl")

end
