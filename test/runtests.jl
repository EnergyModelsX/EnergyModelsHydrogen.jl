using Revise
using Test
using EnergyModelsHydrogen

@testset "Wind Turbine -> Electrolyzer -> H2-consumer" begin
    include("test_electrolyzer_degradation.jl")
end
