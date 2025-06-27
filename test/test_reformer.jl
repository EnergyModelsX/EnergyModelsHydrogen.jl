# Declare all resources of the Case
power = ResourceCarrier("Power", 0.0)
ng = ResourceCarrier("NG", 0.2)
h2 = ResourceCarrier("H₂", 0.0)
co2 = ResourceEmit("CO₂", 1.0)

"""
    reformer_test_case(𝒯; kwargs)

Simple test case for testing the reformer type. it can utilize differing input to test
the functionality of an reformer node.
"""
function reformer_test_case(
    𝒯;
    data=ExtensionData[CaptureEnergyEmissions(0.92)],
    load_limits=LoadLimits(0.2, 1.0),
    rate_change=RampNone(),
    demand=FixedProfile(50),
    deficit_cost=FixedProfile(100),
    co2_limit=8760,
)
    # Declaration of the resources
    𝒫 = [power, ng, h2, co2]

    # Declaration of the nodes
    ng_source = RefSource(
        "ng source",
        FixedProfile(100),
        FixedProfile(9),
        FixedProfile(0),
        Dict(ng => 1),
    )
    el_source = RefSource(
        "Electricity source",
        FixedProfile(100),
        FixedProfile(30),
        FixedProfile(0),
        Dict(power => 1),
    )
    if (typeof(data[1]) <: EMB.CaptureData)
        output = Dict(h2 => 1.0, co2 => 0)
    else
        output = Dict(h2 => 1.0)
    end
    reformer = Reformer(
        "reformer",
        FixedProfile(50),   # Installed capacity [MW]
        FixedProfile(5),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(ng => 1.25, power => 0.11),   # Input: Ratio of Input flows to characteristic throughput
        output,             # Ouput: Ratio of Output flow to characteristic throughput
        data,               # Data
        load_limits,        # Minimum and maximum load
        # Hourly cost for startup [€/MW/h] and startup time [h]
        CommitParameters(FixedProfile(0.2), FixedProfile(5)),
        # Hourly cost for shutdown [€/MW/h] and shutdown time [h]
        CommitParameters(FixedProfile(0.2), FixedProfile(5)),
        # Hourly cost when offline [€/MW/h] and minimum off time [h]
        CommitParameters(FixedProfile(0.02), FixedProfile(10)),
        rate_change,        # Rate of change limit [-/h]
    )
    H2_sink = RefSink(
        "h2_demand",
        demand,
        Dict(:surplus => FixedProfile(0), :deficit => deficit_cost),
        Dict(h2 => 1),
    )
    𝒩 = [ng_source, el_source, reformer, H2_sink]

    # Declaration of the links
    ℒ = [
        Direct("ng_source-ref", ng_source, reformer)
        Direct("el_source-ref", el_source, reformer)
        Direct("ref-h2_sink", reformer, H2_sink)
    ]

    #  Add the co2 sink, if required
    if (typeof(data[1]) <: EMB.CaptureData)
        CO2_sink = RefSink(
            "co2 sink",
            FixedProfile(0),
            Dict(:surplus => FixedProfile(9.1), :deficit => FixedProfile(20)),
            Dict(co2 => 1),
        )
        push!(𝒩, CO2_sink)
        append!(ℒ, [Direct("ref-co2_stor", reformer, CO2_sink)])
    end

    # Create the case and modeltype based on the input
    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]])
    if EMI.has_investment(reformer)
        modeltype = InvestmentModel(
            Dict(co2 => FixedProfile(co2_limit)),
            Dict(co2 => FixedProfile(0)),
            co2,
            0.07,
        )
    else
        modeltype = OperationalModel(
            Dict(co2 => FixedProfile(co2_limit)),
            Dict(co2 => FixedProfile(0)),
            co2,
        )
    end

    # Create and run the model
    m = create_model(case, modeltype)
    set_optimizer(m, OPTIMIZER)
    optimize!(m)

    # Test that there is production
    reformer_test(m, case)

    return m, case, modeltype
end

"""
    reformer_test(m, case)

Test function for analysing that the reformer is producing at least in a single period.
"""
function reformer_test(m, case)
    𝒯 = get_time_struct(case)
    ref = get_nodes(case)[3]

    @test termination_status(m) == MOI.OPTIMAL
    @test sum(value.(m[:ref_on_b][ref, t]) for t ∈ 𝒯) > 0
    @test sum(value.(m[:cap_use][ref, t]) for t ∈ 𝒯) > 0
end

# Testset for the individual extraction methods incorporated in the model
@testset "Utilities" begin
    # Create the general data for the reformer node
    𝒯 = TwoLevel(2, 1, SimpleTimes(5, 1))
    t = first(𝒯)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    data = ExtensionData[
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

    # Test the ramping parameters
    @test RampBi(FixedProfile(.1)) == RampBi(FixedProfile(.1), FixedProfile(.1))
    ramp = RampBi(FixedProfile(.1), FixedProfile(.2))
    @test EMH.ramp_up(ramp) == FixedProfile(0.1)
    @test EMH.ramp_up(ramp, t) == 0.1
    @test EMH.ramp_down(ramp) == FixedProfile(0.2)
    @test EMH.ramp_down(ramp, t) == 0.2
    ramp = RampUp(FixedProfile(.1))
    @test EMH.ramp_up(ramp) == FixedProfile(0.1)
    @test EMH.ramp_up(ramp, t) == 0.1
    ramp = RampDown(FixedProfile(.2))
    @test EMH.ramp_down(ramp) == FixedProfile(0.2)
    @test EMH.ramp_down(ramp, t) == 0.2

    reformer = Reformer(
        "reformer",
        FixedProfile(50),   # Installed capacity [MW]
        FixedProfile(5),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(ng => 1.25, power => 0.11),    # Input: Ratio of Input flows to characteristic throughput
        Dict(h2 => 1.0, co2 => 0), # Ouput: Ratio of Output flow to characteristic throughput
        data,               # Data
        LoadLimits(0.2, 1.0),   # Minimum and maximum load
        # Hourly cost for startup [€/MW/h] and startup time [h]
        CommitParameters(FixedProfile(0.2), FixedProfile(5)),
        # Hourly cost for shutdown [€/MW/h] and shutdown time [h]
        CommitParameters(FixedProfile(0.3), FixedProfile(6)),
        # Hourly cost when offline [€/MW/h] and minimum off time [h]
        CommitParameters(FixedProfile(0.02), FixedProfile(10)),
        RampBi(FixedProfile(.1), FixedProfile(.2)), # Rate of change limit [-/h]
    )

    # Test the EMB utility functions
    @test capacity(reformer) == FixedProfile(50)
    @test opex_var(reformer) == FixedProfile(5)
    @test opex_fixed(reformer) == FixedProfile(0)
    @test inputs(reformer) == [ng, power] || inputs(reformer) == [power, ng]
    @test outputs(reformer) == [h2, co2] || outputs(reformer) == [co2, h2]
    @test node_data(reformer) == data

    # Test the EMH utility functions
    @test EMH.opex_startup(reformer) == FixedProfile(0.2)
    @test EMH.opex_startup(reformer, t) == 0.2
    @test EMH.opex_shutdown(reformer) == FixedProfile(0.3)
    @test EMH.opex_shutdown(reformer, t) == 0.3
    @test EMH.opex_off(reformer) == FixedProfile(0.02)
    @test EMH.opex_off(reformer, t) == 0.02
    @test EMH.time_startup(reformer) == FixedProfile(5)
    @test EMH.time_startup(reformer, t) == 5
    @test EMH.time_shutdown(reformer) == FixedProfile(6)
    @test EMH.time_shutdown(reformer, t) == 6
    @test EMH.time_off(reformer) == FixedProfile(10)
    @test EMH.time_off(reformer, t) == 10

    @test EMH.ramp_limit(reformer) == RampBi(FixedProfile(.1), FixedProfile(.2))
    @test EMH.ramp_up(reformer) == FixedProfile(0.1)
    @test EMH.ramp_up(reformer, t) == 0.1
    @test EMH.ramp_down(reformer) == FixedProfile(0.2)
    @test EMH.ramp_down(reformer, t) == 0.2
end

# Test set for investigating startup and shutdown
@testset "Constraints for timing" begin
    @testset "SimpleTimes" begin
        # Specify the input parameters
        𝒯 = TwoLevel(1, 1, SimpleTimes(30, 2); op_per_strat=8760)
        demand = OperationalProfile([ones(10)*50; ones(10)*0; ones(10)*50])
        deficit_cost = OperationalProfile([ones(20)*60; ones(10)*55])

        # Run and test the model
        m, case, modeltype = reformer_test_case(𝒯; demand, deficit_cost)

        # Extract the required parameters
        ref = get_nodes(case)[3]
        ops = collect(𝒯)

        # Test that always a single state is active
        @test all(
                value.(m[:ref_on_b][ref, t]) + value.(m[:ref_off_b][ref, t]) +
                value.(m[:ref_start_b][ref, t]) + value.(m[:ref_shut_b][ref, t])
            ≈ 1 for t ∈ 𝒯)

        # Test that the states have at least a given time
        # Note that the system can choose to not supply
        @test sum(value.(m[:ref_shut_b][ref, t]) for t ∈ ops[11:13]) ≈ 3
        @test sum(value.(m[:ref_off_b][ref, t]) for t ∈ ops[14:18]) ≈ 5
        @test sum(value.(m[:ref_start_b][ref, t]) for t ∈ ops[19:22]) ≈ 3

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
    @testset "OperationalScenarios" begin
        # Specify the input parameters
        oper = SimpleTimes(30, 2)
        𝒯 = TwoLevel(1, 1,
            OperationalScenarios(2, [oper, oper], [0.5, 0.5]);
            op_per_strat = 8760.0
        )
        demand = OperationalProfile([ones(10)*50; ones(10)*0; ones(10)*50])
        deficit_cost = OperationalProfile([ones(20)*60; ones(10)*55])

        # Run and test the model
        m, case, modeltype = reformer_test_case(𝒯; demand, deficit_cost)

        # Extract the required parameters
        ref = get_nodes(case)[3]
        ops = collect(𝒯)

        # Test that always a single state is active
        @test all(
                value.(m[:ref_on_b][ref, t]) + value.(m[:ref_off_b][ref, t]) +
                value.(m[:ref_start_b][ref, t]) + value.(m[:ref_shut_b][ref, t])
            ≈ 1 for t ∈ 𝒯)

        # Test that the states have at least a given time
        # Note that the system can choose to not supply
        @test sum(value.(m[:ref_shut_b][ref, t]) for t ∈ ops[11:13]) ≈ 3
        @test sum(value.(m[:ref_shut_b][ref, t]) for t ∈ ops[41:43]) ≈ 3
        @test sum(value.(m[:ref_off_b][ref, t]) for t ∈ ops[14:18]) ≈ 5
        @test sum(value.(m[:ref_off_b][ref, t]) for t ∈ ops[44:48]) ≈ 5
        @test sum(value.(m[:ref_start_b][ref, t]) for t ∈ ops[19:22]) ≈ 3
        @test sum(value.(m[:ref_start_b][ref, t]) for t ∈ ops[49:52]) ≈ 3

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
    @testset "RepresentativePeriods" begin
        # Specify the input parameters
        oper = SimpleTimes(30, 2)
        𝒯 = TwoLevel(1, 1, RepresentativePeriods(2, 8760, [0.5, 0.5], [oper, oper]))
        demand = OperationalProfile([ones(10)*50; ones(10)*0; ones(10)*50])
        deficit_cost = OperationalProfile([ones(20)*60; ones(10)*55])

        # Run and test the model
        m, case, modeltype = reformer_test_case(𝒯; demand, deficit_cost)

        # Extract the required parameters
        ref = get_nodes(case)[3]
        ops = collect(𝒯)

        # Test that always a single state is active
        @test all(
                value.(m[:ref_on_b][ref, t]) + value.(m[:ref_off_b][ref, t]) +
                value.(m[:ref_start_b][ref, t]) + value.(m[:ref_shut_b][ref, t])
            ≈ 1 for t ∈ 𝒯)

        # Test that the states have at least a given time
        # Note that the system can choose to not supply
        @test sum(value.(m[:ref_shut_b][ref, t]) for t ∈ ops[11:13]) ≈ 3
        @test sum(value.(m[:ref_shut_b][ref, t]) for t ∈ ops[41:43]) ≈ 3
        @test sum(value.(m[:ref_off_b][ref, t]) for t ∈ ops[14:18]) ≈ 5
        @test sum(value.(m[:ref_off_b][ref, t]) for t ∈ ops[44:48]) ≈ 5
        @test sum(value.(m[:ref_start_b][ref, t]) for t ∈ ops[19:22]) ≈ 3
        @test sum(value.(m[:ref_start_b][ref, t]) for t ∈ ops[49:52]) ≈ 3

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
end

# Test set for investigating minimum and maximum usage constraints
@testset "Minimum and maximum usage constraint" begin
    @testset "Without investments" begin
        # Specify the input parameters
        𝒯 = TwoLevel(1, 1, SimpleTimes(30, 2); op_per_strat=8760)
        demand = OperationalProfile([ones(14)*50; ones(1)*0; ones(15)*70])

        # Run and test the model
        m, case, modeltype = reformer_test_case(𝒯; demand)

        # Extract the required parameters and variables
        ref = get_nodes(case)[3]
        ops = collect(𝒯)
        cap_use = m[:cap_use][ref, :]

        # Test that the system is limited by the minimum and maximum usage
        @test value.(cap_use[ops[15]]) ≈ 10
        @test all(value.(cap_use[t]) ⪅ 50 for t ∈ 𝒯)

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
    @testset "With investments" begin
        # Specify the input parameters
        𝒯 = TwoLevel(1, 1, SimpleTimes(30, 2); op_per_strat=8760)
        demand = OperationalProfile([ones(14)*30; ones(1)*0; ones(15)*50])
        data = ExtensionData[
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

        # Run and test the model
        m, case, modeltype = reformer_test_case(𝒯; data, demand)

        # Extract the required parameters and variables
        ref = get_nodes(case)[3]
        ops = collect(𝒯)
        cap_use = m[:cap_use][ref, :]

        # Test that the system is limited by the minimum and maximum usage
        @test value.(cap_use[ops[15]]) ≈ 10
        @test all(value.(cap_use[t]) ⪅ 50 for t ∈ 𝒯)

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
end

# Test set for investigating rate of change constraints
@testset "Rate of change (ramping) constraint" begin
    # General input set
    𝒯 = TwoLevel(1, 1, SimpleTimes(30, 2); op_per_strat=8760)

    @testset "Without state change and investments" begin
        # Specify the input parameters
        rate_change = RampBi(FixedProfile(.1))
        demand = OperationalProfile([ones(15)*50; ones(15)*10])

        # Run and test the model
        m, case, modeltype = reformer_test_case(𝒯; rate_change, demand)

        # Extract the required parameters and variables
        ref = get_nodes(case)[3]
        cap_use = m[:cap_use][ref, :]

        # Test that the system is behaving exactly the way it should
        @test sum(value.(cap_use[t]) ≈ 50 for t ∈ 𝒯) == 15
        @test sum(value.(cap_use[t]) ≈ 40 for t ∈ 𝒯) == 2
        @test sum(value.(cap_use[t]) ≈ 30 for t ∈ 𝒯) == 2
        @test sum(value.(cap_use[t]) ≈ 20 for t ∈ 𝒯) == 2
        @test sum(value.(cap_use[t]) ≈ 10 for t ∈ 𝒯) == 9

        # Test that the system is limited by the rate of change constraint
        @test all(value.(cap_use[t_prev]) - value.(cap_use[t]) ⪅
                    capacity(ref, t) * EMH.ramp_down(ref, t) * duration(t)
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))
        @test value.(cap_use[last(𝒯)]) - value.(cap_use[first(𝒯)]) ⪅
                capacity(ref, first(𝒯)) * EMH.ramp_down(ref, first(𝒯)) * duration(first(𝒯))

        @test all(value.(cap_use[t]) - value.(cap_use[t_prev]) ⪅
                    capacity(ref, t) * EMH.ramp_up(ref, t) * duration(t)
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))
        @test value.(cap_use[first(𝒯)]) - value.(cap_use[last(𝒯)]) ⪅
                capacity(ref, first(𝒯)) * EMH.ramp_up(ref, first(𝒯)) * duration(first(𝒯))

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
    @testset "With state change and without investments" begin
        # Specify the input parameters
        rate_change = RampBi(FixedProfile(.1))
        demand = OperationalProfile([zeros(10); ones(5)*10; ones(5)*50; ones(10)*30])
        deficit_cost = FixedProfile(150)

        # Run and test the model
        m, case, modeltype = reformer_test_case(𝒯; rate_change, demand, deficit_cost)

        # Extract the required parameters and variables
        ref = get_nodes(case)[3]
        cap_use = m[:cap_use][ref, :]

        # Test that the system is behavioung exactly the way it should
        @test sum(value.(cap_use[t]) ≈ 50 for t ∈ 𝒯) == 5
        @test sum(value.(cap_use[t]) ≈ 40 for t ∈ 𝒯) == 2
        @test sum(value.(cap_use[t]) ≈ 30 for t ∈ 𝒯) == 10
        @test sum(value.(cap_use[t]) ≈ 20 for t ∈ 𝒯) == 1
        @test sum(value.(cap_use[t]) ≈ 10 for t ∈ 𝒯) == 1
        @test sum(value.(cap_use[t]) ≤ TEST_ATOL for t ∈ 𝒯) == 11

        # Test that the system is limited by the rate of change constraint except when
        # turned off in the last period
        @test all(value.(cap_use[t_prev]) - value.(cap_use[t]) ⪅
                    capacity(ref, t) * EMH.ramp_down(ref, t) * duration(t)
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))
        @test all(value.(cap_use[t]) - value.(cap_use[t_prev]) ⪅
                    capacity(ref, t) * EMH.ramp_up(ref, t) * duration(t)
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))
        @test value.(cap_use[last(𝒯)]) - value.(cap_use[first(𝒯)]) ⪆
                capacity(ref, first(𝒯)) * EMH.ramp_up(ref, first(𝒯)) * duration(first(𝒯))

        # Release the environment
        finalize(backend(m).optimizer.model)
    end

    @testset "With state change and investments" begin
        # Specify the input parameters
        data = ExtensionData[
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
        rate_change = RampBi(FixedProfile(.1))
        deficit_cost = FixedProfile(150)
        demand = OperationalProfile([zeros(10); ones(5)*10; ones(5)*50; ones(10)*30])

        # Run and test the model
        m, case, modeltype = reformer_test_case(𝒯; data, rate_change, demand, deficit_cost)

        # Extract the required parameters and variables
        ref = get_nodes(case)[3]
        cap_use = m[:cap_use][ref, :]

        # Test that the system is behavioung exactly the way it should
        @test sum(value.(cap_use[t]) ≈ 50 for t ∈ 𝒯) == 5
        @test sum(value.(cap_use[t]) ≈ 40 for t ∈ 𝒯) == 2
        @test sum(value.(cap_use[t]) ≈ 30 for t ∈ 𝒯) == 10
        @test sum(value.(cap_use[t]) ≈ 20 for t ∈ 𝒯) == 1
        @test sum(value.(cap_use[t]) ≈ 10 for t ∈ 𝒯) == 1
        @test sum(value.(cap_use[t]) ≤ TEST_ATOL for t ∈ 𝒯) == 11

        # Test that the system is limited by the rate of change constraint except when
        # turned off in the last period
        @test all(value.(cap_use[t_prev]) - value.(cap_use[t]) ⪅
                    capacity(ref, t) * EMH.ramp_down(ref, t) * duration(t)
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))
        @test all(value.(cap_use[t]) - value.(cap_use[t_prev]) ⪅
                    capacity(ref, t) * EMH.ramp_up(ref, t) * duration(t)
                    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))
        @test value.(cap_use[last(𝒯)]) - value.(cap_use[first(𝒯)]) ⪆
                capacity(ref, first(𝒯)) * EMH.ramp_up(ref, first(𝒯)) * duration(first(𝒯))

        # Test that the system is limited by the maximum installed
        @test all(value.(cap_use[t]) ⪅ 50 for t ∈ 𝒯)

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
end
