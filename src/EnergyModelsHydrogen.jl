"""
Main module for `EnergyModelsHydrogen.jl`.

This module implements constraints for describing an `Electrolyzer`.
"""
module EnergyModelsHydrogen

using JuMP
using TimeStructures
using EnergyModelsBase

const EMB = EnergyModelsBase
const TS  = TimeStructures

include("datastructures.jl")
include("model.jl")
include("user_interface.jl")
include("checks.jl")

export Electrolyzer

end
