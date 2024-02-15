using Test
using JuMP
using TimeStruct
using EnergyModelsBase
using EnergyModelsInvestments
using EnergyModelsHydrogen

const TS = TimeStruct
const EMB = EnergyModelsBase
const EMH = EnergyModelsHydrogen

const TEST_ATOL = 1e-6

function ⪆(x,y)
    x > y || isapprox(x,y; atol = TEST_ATOL)
end

using SCIP
const scip = optimizer_with_attributes(SCIP.Optimizer,
                                         MOI.Silent() => true)
optim = scip

@testset "Wind Turbine -> Electrolyzer -> H2-consumer" begin
    include("test_electrolyzer_degradation.jl")
end
