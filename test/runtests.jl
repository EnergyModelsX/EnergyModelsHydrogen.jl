using Test
using JuMP
using TimeStruct
using EnergyModelsBase
using EnergyModelsInvestments
using EnergyModelsHydrogen
using SCIP

const TS = TimeStruct
const EMB = EnergyModelsBase
const EMI = EnergyModelsInvestments
const EMH = EnergyModelsHydrogen


include("utils.jl")

@testset "Hydrogen" begin
    @testset "Hydrogen | Electrolyzer" begin
        include("test_electrolyzer_degradation.jl")
    end

    @testset "Hydrogen | Reformer" begin
        include("test_reformer.jl")
    end

    @testset "Hydrogen | Checks" begin
        include("test_checks.jl")
    end

    @testset "Hydrogen | examples" begin
        include("test_examples.jl")
    end
end
