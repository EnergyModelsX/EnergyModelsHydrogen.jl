using Test
using JuMP
using TimeStructures
using EnergyModelsBase
using EnergyModelsHydrogen

const TS = TimeStructures
const EMB = EnergyModelsBase
const EMH = EnergyModelsHydrogen

# TODO: Switch to SCIP when open source release available
# using SCIP
# optim = optimizer_with_attributes(SCIP.Optimizer, MOI.Silent()=>true)
const TEST_ATOL = 1e-6
function ⪆(x,y)
    x > y || isapprox(x,y; atol = TEST_ATOL)
end
using Xpress
const xpress = optimizer_with_attributes(Xpress.Optimizer, 
                                         MOI.Silent() => true) 
# NLP optimizer
using Ipopt
const ipopt = optimizer_with_attributes(Ipopt.Optimizer, 
                                        MOI.Silent() => true, 
                                        "sb" => "yes", 
                                        "max_iter"   => 9999)

using Pavito
const pavito = optimizer_with_attributes(
                                        Pavito.Optimizer,
                                        MOI.Silent() => true,
                                        "mip_solver" => xpress,
                                        "cont_solver" => ipopt,
                                        "mip_solver_drives" => false)

# Global optimizer
using Alpine
const alpine = optimizer_with_attributes(Alpine.Optimizer, 
                                         "nlp_solver" => ipopt,
                                         "mip_solver" => xpress,
                                         "minlp_solver" => pavito)

optim = alpine

# TODO: Set up optim with attributes as follows:
# using Gurobi
# const env = Gurobi.Env()
# const gurobi = optimizer_with_attributes(
#                                         () -> Gurobi.Optimizer(env),
#                                         MOI.Silent() => true,
#                                         "NonConvex" => 2,
#                                         "MIPGap" => 1e-3,
#                                         "OutputFlag" => 0,)

# optim = gurobi

@testset "Wind Turbine -> Electrolyzer -> H2-consumer" begin
    include("test_electrolyzer_degradation.jl")
end
# finalize(env)