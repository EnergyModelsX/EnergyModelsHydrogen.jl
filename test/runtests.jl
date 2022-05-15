using Revise
using Test
using Hydrogen
using GLPK
using JuMP

m, case = Hydrogen.run_model("",GLPK.Optimizer)
println(objective_value(m))
value.(m[:cap_use])
#=
@testset "Hydrogen module electrolyzer" begin
    println(objective_value(m))
    @test 0 == 0
    # Write your tests here.in
end
=#
