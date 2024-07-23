# The optimization model expects these default keys
params_dict = Dict(
    :deficit_cost => FixedProfile(100),
    :demand => FixedProfile(50),
    :num_op => 100,
    :dur_op => 2,
    :rep => false,
    :simple => false,
    :data => Data[CaptureEnergyEmissions(0.92)],
    :co2_limit => 8760,
)

# Test set for running the model
@testset "Reformer - running" begin
    # Modify the parameter set
    params_used = deepcopy(params_dict)
    (m, case) = build_run_reformer_model(params_used)

    # Conduct the general tests
    reformer_test(m, case, params_used)

    # Release the environment
    finalize(backend(m).optimizer.model)
end

# Test set for investigating startup and shutdown
@testset "Reformer - constraints for timing" begin
    # Modify the parameter set
    params_used = deepcopy(params_dict)
    params_used[:num_op] = 30
    params_used[:demand] = OperationalProfile([ones(10)*50; ones(10)*0; ones(10)*50])
    params_used[:deficit_cost] = OperationalProfile([ones(20)*60; ones(10)*55])
    (m, case) = build_run_reformer_model(params_used)

    # Conduct the general tests
    reformer_test(m, case, params_used)

    # Extract the required parameters
    𝒯 = case[:T]
    ref = case[:nodes][3]
    ops = collect(𝒯)

    # Test that always a single state is active
    @test sum(
            value.(m[:ref_on_b][ref, t]) + value.(m[:ref_off_b][ref, t]) +
            value.(m[:ref_start_b][ref, t]) + value.(m[:ref_shut_b][ref, t])
        ≈ 1 for t ∈ 𝒯) ≈ length(𝒯)

    # Test that the states have at least a given time
    # Note that the system can choose to not supply
    @test sum(value.(m[:ref_shut_b][ref, t]) for t ∈ ops[11:13]) ≈ 3
    @test sum(value.(m[:ref_off_b][ref, t]) for t ∈ ops[14:18]) ≈ 5
    @test sum(value.(m[:ref_start_b][ref, t]) for t ∈ ops[19:22]) ≈ 3

    # Release the environment
    finalize(backend(m).optimizer.model)
end

# Test set for investigating minimum and maximum usage constraints
@testset "Reformer - minimum and maximum usage constraint" begin
    # Modify the parameter set
    params_used = deepcopy(params_dict)
    params_used[:num_op] = 30
    params_used[:demand] = OperationalProfile([ones(14)*50; ones(1)*0; ones(15)*70])
    (m, case) = build_run_reformer_model(params_used)

    # Conduct the general tests
    reformer_test(m, case, params_used)

    # Extract the required parameters
    𝒯 = case[:T]
    ref = case[:nodes][3]
    ops = collect(𝒯)

    # Test that the system is limited by the minimum and maximum usage
    @test value.(m[:cap_use][ref, ops[15]]) ≈ 10
    @test sum(value.(m[:cap_use][ref, t]) ⪅ 50 for t ∈ 𝒯) == length(𝒯)

    # Release the environment
    finalize(backend(m).optimizer.model)
end

# Test set for considering investments
@testset "Reformer - minimum and maximum usage constraint with investments" begin
    # Modify the parameter set
    params_used = deepcopy(params_dict)
    params_used[:num_op] = 30
    params_used[:demand] = OperationalProfile([ones(14)*30; ones(1)*0; ones(15)*50])
    params_used[:deficit_cost] = FixedProfile(1e3)
    params_used[:data] = Data[
        CaptureEnergyEmissions(0.92)
        SingleInvData(
            FixedProfile(9e5),
            FixedProfile(200),
            0,
            ContinuousInvestment(
                FixedProfile(0),
                FixedProfile(100),
            )
        )
    ]

    (m, case) = build_run_reformer_model(params_used)

    # Conduct the general tests
    reformer_test(m, case, params_used)

    # Extract the required parameters
    𝒯 = case[:T]
    ref = case[:nodes][3]
    ops = collect(𝒯)

    # Test that the system is limited by the minimum and maximum usage
    @test value.(m[:cap_use][ref, ops[15]]) ≈ 10
    @test sum(value.(m[:cap_use][ref, t]) ⪅ 50 for t ∈ 𝒯) == length(𝒯)

    # Release the environment
    finalize(backend(m).optimizer.model)
end
