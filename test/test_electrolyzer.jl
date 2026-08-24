using LinearAlgebra

# Declare all resources of the case
power = ResourceCarrier("Power", 0.0)
h2 = ResourceCarrier("H₂", 0.0)
co2 = ResourceEmit("CO₂", 1.0)

"""
    elec_test_case(𝒯; kwargs)

Simple test case for testing the electrolyzer type. it can utilize differing input to test
the functionality of an electrolyzer node.
"""
function elec_test_case(
    𝒯;
    elec_type=SimpleElectrolyzer,
    cap=FixedProfile(100),
    data=ExtensionData[],
    limits=LoadLimits(0, 1),
    degradation_rate=0.1,
    stack_cost=FixedProfile(3e5),
    stack_lifetime=60000,
    demand=FixedProfile(50),
    deficit_cost=FixedProfile(1000),
)
    # Declaration of the resources
    𝒫 = [power, h2, co2]

    # Declaration of the nodes
    el_source = RefSource(
        "Electricity source",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(10),   # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(power => 1),   # Ratio of output to characteristic throughput
    )
    elec = elec_type(
        "Electrolyzer",
        cap,                # Installed capacity [MW]
        FixedProfile(5),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(power => 1),   # Input: Ratio of Input flows to characteristic throughput
        Dict(h2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
        data,               # Data
        limits,             # Minimum and maximum load
        degradation_rate,   # Degradation rate
        stack_cost,         # Stack replacement costs
        stack_lifetime,     # Stack lifetime in h
    )
    h2_sink = RefSink(
        "H₂ demand",
        demand,   # Installed capacity [MW]
        Dict(
            :surplus => FixedProfile(0),
            :deficit => deficit_cost,
            ),              # Penalty dict
        Dict(h2 => 1),      # Ratio of sink flows to sink characteristic throughput.
    )
    𝒩= [el_source, elec, h2_sink]

    # Declaration of the links
    ℒ = [
        Direct("l1", el_source, elec)
        Direct("l2", elec, h2_sink)
    ]

    # Create the case and modeltype based on the input
    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]])
    if EMI.has_investment(elec)
        modeltype = InvestmentModel(Dict(co2 => FixedProfile(0)), Dict(co2 => FixedProfile(0)), co2, 0.07)
    else
        modeltype = OperationalModel(Dict(co2 => FixedProfile(0)), Dict(co2 => FixedProfile(0)), co2)
    end

    # Create and run the model
    m = create_model(case, modeltype)
    set_optimizer(m, OPTIMIZER)
    optimize!(m)

    # Test the penalties
    penalty_test(m, case)

    return m, case, modeltype
end

"""
    penalty_test(m, case)

Test function for analysing that the previous operational period has an efficiency
penalty that is at least as large as the one of the current period as well as that
the previous usage with stack replacement is correctly calculated.
"""
function penalty_test(m, case)
    # Extract the required input
    elec = get_nodes(case)[2]
    𝒯 = get_time_struct(case)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Reassign variables
    penalty = value.(m[:elect_efficiency_penalty][elec, :])
    stack_replace = value.(m[:elect_stack_replace_b][elec, :])
    prev_use = value.(m[:elect_prev_use][elec, :])

    # Calculation of the penalty
    @test all(
        penalty[t] ⪅ penalty[t_prev]
        for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)
    )
    @test all(prev_use[t] ⪅ EMH.stack_lifetime(elec) for t ∈ 𝒯)
    @test all(
        isapprox(
            penalty[t], 1 - EMH.degradation_rate(elec)/100 * prev_use[t], atol=1e-6
        )
    for t ∈ 𝒯)

    # Test that the previous usage is correctly calculated
    @test all(isapprox(
        value.(m[:elect_prev_use_sp][elec, t_inv]),
        (
            value.(m[:elect_prev_use_sp][elec, t_inv_prev]) +
            value.(m[:elect_use_sp][elec, t_inv_prev]) * 2
        ) * (1 - stack_replace[t_inv]),
        atol = TEST_ATOL)
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ) if !isnothing(t_inv_prev))

    # Test that the stack lifetime constraint is not violated
    @test all(
        EMH.stack_lifetime(elec)/1000 ⪆
            value.(m[:elect_prev_use_sp][elec, t_inv]) * (1-stack_replace[t_inv]) +
            value.(m[:elect_use_sp][elec, t_inv]) * duration_strat(t_inv)
    for t_inv ∈ 𝒯ᴵⁿᵛ)
end

# Testset for the individual extraction methods incorporated in the model
@testset "Utilities" begin
    # Create the general data for the electrolyzer node
    𝒯 = TwoLevel(2, 1, SimpleTimes(5, 1))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    data = ExtensionData[SingleInvData(
        FixedProfile(4e5),
        FixedProfile(200),
        ContinuousInvestment(
            FixedProfile(0),
            StrategicProfile([0, 100, 0, 0, 0]),
        )
    )]

    # Iterate through both electrolyzer types and check that all functions are working
    for type ∈ [SimpleElectrolyzer, Electrolyzer]
        elec = type(
            "electrolyzer",
            FixedProfile(10),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(0),    # Fixed Opex
            Dict(power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(h2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            data,
            LoadLimits(0.1, 1.2),   # Minimum and maximum load
            0.1,                # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )

        # Test the EMB utility functions
        @test capacity(elec) == FixedProfile(10)
        @test opex_var(elec) == FixedProfile(5)
        @test opex_fixed(elec) == FixedProfile(0)
        @test inputs(elec) == [power]
        @test outputs(elec) == [h2]
        @test node_data(elec) == data

        # Test the EMH utility functions
        @test EMH.degradation_rate(elec) == 0.1
        @test EMH.stack_replacement_cost(elec) == FixedProfile(3e5)
        @test EMH.stack_replacement_cost(elec, first(𝒯ᴵⁿᵛ)) == 3e5
        @test EMH.stack_lifetime(elec) == 60000
        @test EMH.min_load(elec) == FixedProfile(0.1)
        @test EMH.min_load(elec, first(𝒯)) == 0.1
        @test EMH.max_load(elec) == FixedProfile(1.2)
        @test EMH.max_load(elec, first(𝒯)) == 1.2

        # Test the other functions
        modeltype = OperationalModel(Dict(co2 => FixedProfile(0)), Dict(co2 => FixedProfile(0)), co2)
        @test EMH.capacity_max(elec, first(𝒯ᴵⁿᵛ), modeltype) == 10
        modeltype = InvestmentModel(Dict(co2 => FixedProfile(0)), Dict(co2 => FixedProfile(0)), co2, 0.07)
        @test EMH.capacity_max(elec, first(𝒯ᴵⁿᵛ), modeltype) == 200
    end
end

# Test set for simple degradation tests without stack replacement due to the
# prohibitive costs for the replacement of the stack
@testset "Degradation tests" begin
    # Specifying the input parameters
    𝒯 = TwoLevel(8, 2, SimpleTimes(20, 8760/20); op_per_strat=8760)
    deficit_cost = StrategicProfile([25, 25, 25, 25, 30])
    stack_cost = FixedProfile(3e8)

    # Run and test the model
    m, case, modeltype = elec_test_case(𝒯; stack_cost, deficit_cost)

    # Test that no stack replacement is happening
    # (duration(t) * duration_strat(t_inv))
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    elec = get_nodes(case)[2]
    @test sum(value.(m[:elect_on_b])[elec, t] for t ∈ 𝒯) * 438 * 2 ≈ 59568
    @test all(value.(m[:elect_stack_replace_b][elec, t_inv]) == 0 for t_inv ∈ 𝒯ᴵⁿᵛ)

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))
    finalize(backend(m).optimizer.model)

    # Test for stack lifetimes shorter than op_per_strat
    𝒯 = TwoLevel(8, 2, SimpleTimes(20, 1); op_per_strat=8760)
    stack_lifetime = 8000
    # Run and test the model
    m, case, modeltype = elec_test_case(𝒯; stack_cost, deficit_cost, stack_lifetime)
end

# Test set for the used load limits allowing for both production above and below capacity
@testset "Load limit tests" begin
    # Specifying the input parameters
    𝒯 = TwoLevel(8, 2, SimpleTimes(10, 1); op_per_strat=8760)
    cap = FixedProfile(80)
    demand = OperationalProfile([20, 30, 40, 50, 100, 60, 20, 20, 25, 50] * 0.62)
    limits = LoadLimits(0.3, 1.1)

    # Run and test the model
    m, case, modeltype = elec_test_case(𝒯; cap, limits, demand)

    # Test that the minimum usage is enforced and there is a surplus in some periods
    elec, sink = get_nodes(case)[2:3]

    # Test that the minimum usage is not violated
    # (min_load * capacity)
    @test all(value.(m[:cap_use][elec, t]) ≥ 0.3*80 for t ∈ 𝒯)

    # Test that there is a surplus in the sink
    # Surplus given by
    # (demand of 20 * number of strategic periods)
    @test sum(value.(m[:sink_surplus][sink, t]) ≈ (0.3*80-20)*.62 for t ∈ 𝒯) == 3 * 8
    @test sum(value.(m[:sink_surplus][sink, t]) > 0 + TEST_ATOL for t ∈ 𝒯) == 3 * 8

    # Test that there is a deficit in the sink
    # (demand of 20 * number of strategic periods)
    @test sum(value.(m[:sink_deficit][sink, t]) ≈ (100-1.1*80)*.62 for t ∈ 𝒯) == 1 * 8
    @test sum(value.(m[:sink_deficit][sink, t]) > 0 + TEST_ATOL for t ∈ 𝒯) == 1 * 8

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))
    finalize(backend(m).optimizer.model)
end

# Test set for the extension with investments allowed
@testset "Investment extension test" begin
    @testset "Without investment data" begin
        # Specifying the input parameters
        𝒯 = TwoLevel(8, 2, SimpleTimes(20, 1); op_per_strat=8760)
        deficit_cost = StrategicProfile([25, 25, 25, 25, 30])
        stack_cost = FixedProfile(3e8)

        # Run and test the model
        m, case, modeltype = elec_test_case(𝒯; stack_cost, deficit_cost)

        # Overwrite the modeltype
        modeltype = InvestmentModel(Dict(co2 => FixedProfile(0)), Dict(co2 => FixedProfile(0)), co2, 0.07)

        # Create and run the model
        m = create_model(case, modeltype)
        set_optimizer(m, OPTIMIZER)
        optimize!(m)

        # Test the penalties
        penalty_test(m, case)
    end
    @testset "With investment data" begin
        # Specifying the input parameters
        𝒯 = TwoLevel(5, 2, SimpleTimes(50, 8760/50); op_per_strat=8760)
        cap = FixedProfile(0)
        data = ExtensionData[SingleInvData(
            FixedProfile(4e5),
            FixedProfile(200),
            ContinuousInvestment(
                FixedProfile(0),
                StrategicProfile([0, 100, 0, 0, 0]),
            )
        )]
        stack_cost = FixedProfile(1e5)
        stack_lifetime = 20000

        # Run and test the model
        m, case, modeltype = elec_test_case(𝒯; cap, data, stack_cost, stack_lifetime)

        # Reassign types
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        elec = get_nodes(case)[2]

        # Test that there are no quadratic constraints for SimpleElectrolyzer types
        @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

        # Test for invested capacity
        @test sum(value.(m[:cap_current][elec, t_inv]) ≈ 50/.62 for t_inv ∈ 𝒯ᴵⁿᵛ) == 4
        finalize(backend(m).optimizer.model)
    end
end

# Test set for analysing the correct implementation of stack replacement
# Set deficit cost to be high to motivate electrolyzer use.
# params are adjusted that stack replacement is done once the lifetime is reached.
@testset "Stack replacement tests with SimpleTimes" begin
    # Specifying the input parameters
    𝒯 = TwoLevel(8, 2, SimpleTimes(20, 8760/20); op_per_strat=8760)
    stack_cost = FixedProfile(3e6)

    # Run and test the model
    m, case, modeltype = elec_test_case(𝒯)

    # Reassign types
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    elec = get_nodes(case)[2]
    stack_replace = m[:elect_stack_replace_b][elec, :]
    penalty = m[:elect_efficiency_penalty][elec, :]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ length(𝒯ᴵⁿᵛ) - 6
    @test sum(value.(penalty[t]) ≈ 1 for t ∈ 𝒯) ≈ length(𝒯ᴵⁿᵛ) - 6 + 1

    # Test that the electrolyzer is operating at all times
    @test all(value.(m[:elect_on_b])[elec, t] == 1 for t ∈ 𝒯)

    # Test that the fixed OPEX is including the stack replacement costs
    # (binary * cost * capacity / duration_strat)
    @test all(
        value.(m[:opex_fixed])[elec, t_inv] ≈
        value.(stack_replace[t_inv]) * 3e5 * 100 / 2
    for t_inv ∈ 𝒯ᴵⁿᵛ)

    # Test that the previus usage is correctly calculated for all periods
    @test all(
        value.(m[:elect_prev_use])[elec, t] ≈
            value.(m[:elect_prev_use])[elec, t_prev] +
            value.(m[:elect_on_b])[elec, t_prev] * duration(t_prev) / 1e3
    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

    finalize(backend(m).optimizer.model)
end

# Test set for analysing the correct implementation of stack replacement when considering
# operational scenarios .
@testset "Stack replacement tests with OperationalScenarios" begin
    # Specifying the input parameters
    oper = SimpleTimes(10, 8760/10/4)
    𝒯 = TwoLevel(8, 2,
        OperationalScenarios(2, [oper, oper], [0.5, 0.5]);
        op_per_strat = 8760.0
    )

    # Run and test the model
    m, case, modeltype = elec_test_case(𝒯)

    # Reassign types
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    elec = get_nodes(case)[2]
    stack_replace = m[:elect_stack_replace_b][elec, :]
    penalty = m[:elect_efficiency_penalty][elec, :]

    # General test for the number of stack_replacements and the resetting of the penalty
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ length(𝒯ᴵⁿᵛ) - 6
    @test sum(value.(penalty[t]) ≈ 1 for t ∈ 𝒯) ≈ (length(𝒯ᴵⁿᵛ) - 6 + 1)*2

    # Test that the electrolyzer is operating at all times
    @test all(value.(m[:elect_on_b])[elec, t] == 1 for t ∈ 𝒯)

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

    finalize(backend(m).optimizer.model)
end

# Test set for analysing the correct implementation of stack replacement when considering
# representative periods.
@testset "Stack replacement tests with RepresentativePeriods" begin
    # Specifying the input parameters
    oper = SimpleTimes(10, 8760/10/4)
    𝒯 = TwoLevel(8, 2, RepresentativePeriods(2, 8760, [0.5, 0.5], [oper, oper]))

    # Run and test the model
    m, case, modeltype = elec_test_case(𝒯)

    # Reassign types
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    elec = get_nodes(case)[2]
    stack_replace = m[:elect_stack_replace_b][elec, :]
    penalty = m[:elect_efficiency_penalty][elec, :]

    # General test for the number of stack_replacements and the resetting of the penalty
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ length(𝒯ᴵⁿᵛ) - 6
    @test sum(value.(penalty[t]) ≈ 1 for t ∈ 𝒯) ≈ length(𝒯ᴵⁿᵛ) - 6 + 1

    # Test that the electrolyzer is operating at all times
    @test all(value.(m[:elect_on_b])[elec, t] == 1 for t ∈ 𝒯)

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

    finalize(backend(m).optimizer.model)
end

# Test set for correct implementation of the quadratic constraints for `Electrolyzer` nodes
@testset "Quadratic expression" begin
    # Specifying the input parameters
    𝒯 = TwoLevel(8, 2, SimpleTimes(20, 8760/20); op_per_strat=8760)
    elec_type = Electrolyzer

    # Run and test the model
    m, case, modeltype = elec_test_case(𝒯; elec_type)

    # Reassign types
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    elec = get_nodes(case)[2]
    stack_replace = m[:elect_stack_replace_b][elec, :]
    penalty = m[:elect_efficiency_penalty][elec, :]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ length(𝒯ᴵⁿᵛ) - 6
    @test sum(value.(penalty[t]) ≈ 1 for t ∈ 𝒯) ≈ length(𝒯ᴵⁿᵛ) - 6 + 1

    # Test that there are quadratic constraints for Electrolyzer types
    @test length(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64})) ==
        length(𝒯)

    # Test that the penalty is correctly calculated
    # - EMB.constraints_flow_out(m, n::Electrolyzer, 𝒯::TimeStructure, modeltype::EnergyModel)
    @test all(
        norm(
            value.(m[:flow_out][elec, t, h2]) -
            value.(m[:cap_use][elec, t]) * outputs(elec, h2) *
            value.(m[:elect_efficiency_penalty][elec, t])
        ) ≤ TEST_ATOL for t ∈ 𝒯
    )

    finalize(backend(m).optimizer.model)
end
