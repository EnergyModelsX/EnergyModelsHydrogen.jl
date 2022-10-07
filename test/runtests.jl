using Revise
using Test
using JuMP
using TimeStructures
using EnergyModelsBase
using EnergyModelsHydrogen

const TS = TimeStructures
const EMB = EnergyModelsBase
const EMH = EnergyModelsHydrogen

#using SCIP
#optim = SCIP.Optimizer

using Gurobi
const env = Gurobi.Env()
optim = () -> Gurobi.Optimizer(env)

@testset "Wind Turbine -> Electrolyzer -> H2-consumer" begin
    include("test_electrolyzer_degradation.jl")
end
finalize(env)