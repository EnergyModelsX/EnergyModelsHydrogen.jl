"""
Main module for `EnergyModelsHydrogen.jl`.

This module implements constraints for describing an `Electrolyzer`.
"""
module EnergyModelsHydrogen

using JuMP
using TimeStruct
using EnergyModelsBase

const EMB = EnergyModelsBase
const TS  = TimeStruct

include("datastructures.jl")
include("model.jl")
include("user_interface.jl")
include("checks.jl")
include("constraint_functions.jl")
include("utils.jl")

export SimpleElectrolyzer, Electrolyzer

end