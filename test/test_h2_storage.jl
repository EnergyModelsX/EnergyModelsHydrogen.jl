# The optimization model expects these default keys
params_dict = Dict(
    :supply => FixedProfile(10),
    :demand => FixedProfile(50),
    :num_op => 30,
    :dur_op => 1,
    :rep => false,
    :simple => true,
)

# Test set for the type `SimpleHydrogenStorage`
@testset "SimpleHydrogenStorage" begin

    # Modify the parameter set
    params_used = deepcopy(params_dict)
    params_used[:num_op] = 5
    params_used[:supply] = OperationalProfile([10, 15, 10, 20, 0])
    params_used[:demand] = OperationalProfile([5, 15, 5, 15, 15])
    (m, case) = build_run_h2_storage_model(params_used)

    # Extract the sets and variables
    power = case[:products][1]
    h2 = case[:products][2]
    h2_stor = case[:nodes][3]
    h2_demand = case[:nodes][4]
    flow_in = value.(m[:flow_in][h2_stor, :, :])
    𝒯 = case[:T]

    # Test that the electricity demand is correctly included
    # (showing that we do not need a new function)
    @test all(flow_in[t, power] ≈ 0.01 * flow_in[t, h2] for t ∈ 𝒯)

    # Test that the maximum discharge is limited by the charge capacity and the multiplier
    #   EMB.constraints_capacity(m, n::AbstractH2Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
    @test all(
        value.(m[:stor_discharge_use][h2_stor, t]) ≤
            2 * value.(m[:stor_charge_inst][h2_stor, t]) + TEST_ATOL
    for t ∈ 𝒯)
    # Test that the maximum discharge is only occuring a single time and that there is a
    # total deficit of 5 in the system, although the supplier and the demand equal
    @test sum(value.(m[:stor_discharge_use][h2_stor, t]) ≈ 10 for t ∈ 𝒯) == 1
    @test sum(params_used[:supply][t] for t ∈ 𝒯) == sum(params_used[:demand][t] for t ∈ 𝒯)
    @test sum(value.(m[:sink_deficit][h2_demand, t]) ≈ 5 for t ∈ 𝒯) == 1

    # Release the environment
    finalize(backend(m).optimizer.model)
end
