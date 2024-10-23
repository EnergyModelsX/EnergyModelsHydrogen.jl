# The optimization model expects these default keys
params_dict = Dict(
    :deficit_cost => FixedProfile(100),
    :demand => FixedProfile(50),
    :num_op => 30,
    :dur_op => 2,
    :rep => false,
    :simple => false,
    :data => Data[CaptureEnergyEmissions(0.92)],
    :rate_change => RampNone(),
    :load_limits => LoadLimits(0.2, 1.0),
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
    @testset "Without investments" begin
        # Modify the parameter set
        params_used = deepcopy(params_dict)
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
    @testset "With investments" begin
        # Modify the parameter set
        params_used = deepcopy(params_dict)
        params_used[:demand] = OperationalProfile([ones(14)*30; ones(1)*0; ones(15)*50])
        params_used[:data] = Data[
            CaptureEnergyEmissions(0.92)
            SingleInvData(
                FixedProfile(9e5),
                FixedProfile(200),
                FixedProfile(0),
                ContinuousInvestment(
                    FixedProfile(0),
                    FixedProfile(100),
                ),
                RollingLife(FixedProfile(30)),
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
end

# Test set for investigating rate of change constraints
@testset "Reformer - rate of change (ramping) constraint" begin
    @testset "Without state change and investments" begin
        # Modify the parameter set
        params_used = deepcopy(params_dict)
        params_used[:demand] = OperationalProfile([ones(15)*50; ones(15)*10])
        params_used[:rate_change] = RampBi(FixedProfile(.1))
        (m, case) = build_run_reformer_model(params_used)

        # Conduct the general tests
        reformer_test(m, case, params_used)

        # Extract the required parameters
        𝒯 = case[:T]
        ref = case[:nodes][3]
        ops = collect(𝒯)

        # Test that the system is behavioung exactly the way it should
        @test sum(value.(m[:cap_use][ref, t]) ≈ 50 for t ∈ 𝒯) == 15
        @test sum(value.(m[:cap_use][ref, t]) ≈ 40 for t ∈ 𝒯) == 2
        @test sum(value.(m[:cap_use][ref, t]) ≈ 30 for t ∈ 𝒯) == 2
        @test sum(value.(m[:cap_use][ref, t]) ≈ 20 for t ∈ 𝒯) == 2
        @test sum(value.(m[:cap_use][ref, t]) ≈ 10 for t ∈ 𝒯) == 9

        # Test that the system is limited by the rate of change constraint
        @test sum(value.(m[:cap_use][ref, t_prev]) - value.(m[:cap_use][ref, t]) ⪅
                    capacity(ref, t) * EMH.ramp_down(ref, t) * params_used[:dur_op]
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)) == length(𝒯)-1
        @test value.(m[:cap_use][ref, last(𝒯)]) - value.(m[:cap_use][ref, first(𝒯)]) ⪅
                capacity(ref, first(𝒯)) * EMH.ramp_down(ref, first(𝒯)) * params_used[:dur_op]

        @test sum(value.(m[:cap_use][ref, t]) - value.(m[:cap_use][ref, t_prev]) ⪅
                    capacity(ref, t) * EMH.ramp_up(ref, t) * params_used[:dur_op]
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)) == length(𝒯)-1
        @test value.(m[:cap_use][ref, first(𝒯)]) - value.(m[:cap_use][ref, last(𝒯)]) ⪅
                capacity(ref, first(𝒯)) * EMH.ramp_up(ref, first(𝒯)) * params_used[:dur_op]

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
    @testset "With state change and without investments" begin
        # Modify the parameter set
        params_used = deepcopy(params_dict)
        params_used[:deficit_cost] = FixedProfile(150)
        params_used[:demand] = OperationalProfile([zeros(10); ones(5)*10; ones(5)*50; ones(10)*30])
        params_used[:rate_change] = RampBi(FixedProfile(.1))
        (m, case) = build_run_reformer_model(params_used)

        # Conduct the general tests
        reformer_test(m, case, params_used)

        # Extract the required parameters
        𝒯 = case[:T]
        ref = case[:nodes][3]
        ops = collect(𝒯)

        # Test that the system is behavioung exactly the way it should
        @test sum(value.(m[:cap_use][ref, t]) ≈ 50 for t ∈ 𝒯) == 5
        @test sum(value.(m[:cap_use][ref, t]) ≈ 40 for t ∈ 𝒯) == 2
        @test sum(value.(m[:cap_use][ref, t]) ≈ 30 for t ∈ 𝒯) == 10
        @test sum(value.(m[:cap_use][ref, t]) ≈ 20 for t ∈ 𝒯) == 1
        @test sum(value.(m[:cap_use][ref, t]) ≈ 10 for t ∈ 𝒯) == 1
        @test sum(value.(m[:cap_use][ref, t]) ≤ TEST_ATOL for t ∈ 𝒯) == 11

        # Test that the system is limited by the rate of change constraint except when
        # turned off in the last period
        @test sum(value.(m[:cap_use][ref, t_prev]) - value.(m[:cap_use][ref, t]) ⪅
                    capacity(ref, t) * EMH.ramp_down(ref, t) * params_used[:dur_op]
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)) == length(𝒯)-1
        @test sum(value.(m[:cap_use][ref, t]) - value.(m[:cap_use][ref, t_prev]) ⪅
                    capacity(ref, t) * EMH.ramp_up(ref, t) * params_used[:dur_op]
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)) == length(𝒯)-1
        @test value.(m[:cap_use][ref, last(𝒯)]) - value.(m[:cap_use][ref, first(𝒯)]) ⪆
                capacity(ref, first(𝒯)) * EMH.ramp_up(ref, first(𝒯)) * params_used[:dur_op]

        # Release the environment
        finalize(backend(m).optimizer.model)
    end

    @testset "With state change and investments" begin
        # Modify the parameter set
        params_used = deepcopy(params_dict)
        params_used[:deficit_cost] = FixedProfile(150)
        params_used[:demand] = OperationalProfile([zeros(10); ones(5)*10; ones(5)*50; ones(10)*30])
        params_used[:rate_change] = RampBi(FixedProfile(.1))
        params_used[:data] = Data[
            CaptureEnergyEmissions(0.92)
            SingleInvData(
                FixedProfile(9e5),
                FixedProfile(200),
                FixedProfile(0),
                ContinuousInvestment(
                    FixedProfile(0),
                    FixedProfile(100),
                ),
                RollingLife(FixedProfile(30)),
            )
        ]

        (m, case) = build_run_reformer_model(params_used)

        # Conduct the general tests
        reformer_test(m, case, params_used)

        # Extract the required parameters
        𝒯 = case[:T]
        ref = case[:nodes][3]
        ops = collect(𝒯)

        # Test that the system is behavioung exactly the way it should
        @test sum(value.(m[:cap_use][ref, t]) ≈ 50 for t ∈ 𝒯) == 5
        @test sum(value.(m[:cap_use][ref, t]) ≈ 40 for t ∈ 𝒯) == 2
        @test sum(value.(m[:cap_use][ref, t]) ≈ 30 for t ∈ 𝒯) == 10
        @test sum(value.(m[:cap_use][ref, t]) ≈ 20 for t ∈ 𝒯) == 1
        @test sum(value.(m[:cap_use][ref, t]) ≈ 10 for t ∈ 𝒯) == 1
        @test sum(value.(m[:cap_use][ref, t]) ≤ TEST_ATOL for t ∈ 𝒯) == 11

        # Test that the system is limited by the rate of change constraint except when
        # turned off in the last period
        @test sum(value.(m[:cap_use][ref, t_prev]) - value.(m[:cap_use][ref, t]) ⪅
                    capacity(ref, t) * EMH.ramp_down(ref, t) * params_used[:dur_op]
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)) == length(𝒯)-1
        @test sum(value.(m[:cap_use][ref, t]) - value.(m[:cap_use][ref, t_prev]) ⪅
                    capacity(ref, t) * EMH.ramp_up(ref, t) * params_used[:dur_op]
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)) == length(𝒯)-1
        @test value.(m[:cap_use][ref, last(𝒯)]) - value.(m[:cap_use][ref, first(𝒯)]) ⪆
                capacity(ref, first(𝒯)) * EMH.ramp_up(ref, first(𝒯)) * params_used[:dur_op]

        # Test that the system is limited by the maximum installed
        @test sum(value.(m[:cap_use][ref, t]) ⪅ 50 for t ∈ 𝒯) == length(𝒯)

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
end
