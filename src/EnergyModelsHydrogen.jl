"""
Main module for `EnergyModelsHydrogen`.

This module implements constraints for describing electrolysis through the types
`SimpleElectrolyzer` and `Electrolyzer` as well as natural gas reforming through the type
`Reformer`.
"""
module EnergyModelsHydrogen

using JuMP
using TimeStruct
using EnergyModelsBase

const EMB = EnergyModelsBase
const TS  = TimeStruct

include(joinpath("structures", "node.jl"))
include(joinpath("structures", "misc.jl"))
include("model.jl")
include("user_interface.jl")
include("checks.jl")
include("constraint_functions.jl")
include("utils.jl")

export SimpleElectrolyzer, Electrolyzer
export Reformer

export LoadLimits, CommitParameters

end
