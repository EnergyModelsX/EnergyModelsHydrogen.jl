using LinearAlgebra

# The optimization model expects these default keys
params_dict = Dict(
    :deficit_cost => FixedProfile(0),
    :num_op => 2,
    :num_sp => 5,
    :degradation_rate => .1,
    :stack_lifetime => 60000,
    :stack_cost => FixedProfile(3e5),
    :rep => false,
    :simple => true,
    :data => ExtensionData[]
)

# Test set for simple degradation tests without stack replacement due to the
# prohibitive costs for the replacement of the stack
@testset "Electrolyzer - Degradation tests" begin
    # Modifying the input parameters
    params_deg = deepcopy(params_dict)
    params_deg[:num_op] = 100
    params_deg[:deficit_cost] = StrategicProfile([10, 10, 20, 25, 30])
    params_deg[:stack_cost] = FixedProfile(3e8)

    # Run and test the model
    (m, data) = build_run_electrolyzer_model(params_deg)
    penalty_test(m, data, params_deg)

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))
    finalize(backend(m).optimizer.model)
end

# Test set for the extension with investments allowed
@testset "Electrolyzer - Investment extension test" begin
    # Modifying the input parameters
    params_inv = deepcopy(params_dict)
    params_inv[:num_op] = 2000
    params_inv[:deficit_cost] = FixedProfile(1e4)
    params_inv[:data] = ExtensionData[SingleInvData(
        FixedProfile(4e5),
        FixedProfile(200),
        ContinuousInvestment(
            FixedProfile(0),
            StrategicProfile([0, 100, 0, 0, 0]),
        )
    )]
    cap = FixedProfile(0)
    params_inv[:stack_cost] = FixedProfile(1e5)
    params_inv[:stack_lifetime] = 20000

    # Run and test the model
    (m, data) = build_run_electrolyzer_model(params_inv; cap)
    penalty_test(m, data, params_inv)

    # Reassign types
    elect = get_nodes(data)[3]
    𝒯     = get_time_struct(data)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

    # Test for invested capacity
    @test sum(value.(m[:cap_current][elect, t_inv]) ≈ 50/.62 for t_inv ∈ 𝒯ᴵⁿᵛ) == 4
    finalize(backend(m).optimizer.model)
end

# Test set for analysing the correct implementation of stack replacement
# Set deficit cost to be high to motivate electrolyzer use.
# params are adjusted that stack replacement is done once the lifetime is reached.
@testset "Electrolyzer - Stack replacement tests with SimpleTimes" begin
    # Modifying the input parameters
    params_stack = deepcopy(params_dict)
    params_stack[:num_op] = 20
    params_stack[:num_sp] = 8
    params_stack[:deficit_cost] = FixedProfile(1000)
    params_stack[:stack_cost] = FixedProfile(3e6)

    # Run and test the model
    (m, data) = build_run_electrolyzer_model(params_stack)
    penalty_test(m, data, params_stack)

    # Reassign types
    elect = get_nodes(data)[3]
    𝒯     = get_time_struct(data)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
    stack_replace = m[:elect_stack_replace_b][elect, :]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 𝒯.len - 6

    # Test that the previus usage is correctly calculated for all periods
    @test all(
        value.(m[:elect_prev_use])[elect, t] ≈
            value.(m[:elect_prev_use])[elect, t_prev] +
            value.(m[:elect_on_b])[elect, t_prev] * duration(t_prev) / 1e3
    for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev))

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

    finalize(backend(m).optimizer.model)
end

# Test set for analysing the correct implementation of stack replacement when considering
# representative periods.
@testset "Electrolyzer - Stack replacement tests with RepresentativePeriods" begin
    # Modifying the input parameters
    params_rep = deepcopy(params_dict)
    params_rep[:num_op] = 20
    params_rep[:num_sp] = 8
    params_rep[:deficit_cost] = FixedProfile(1000)
    params_rep[:stack_cost] = FixedProfile(3e5)
    params_rep[:rep] = true

    # Run and test the model
    (m, data) = build_run_electrolyzer_model(params_rep)
    penalty_test(m, data, params_rep)

    # Reassign types
    elect = get_nodes(data)[3]
    𝒯     = get_time_struct(data)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
    stack_replace = m[:elect_stack_replace_b][elect, :]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 𝒯.len - 6

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

    finalize(backend(m).optimizer.model)
end

# Test set for correct implementation of the quadratic constraints for `Electrolyzer` nodes
@testset "Electrolyzer - Quadratic expression" begin
    # Modifying the input parameters
    params_elec = deepcopy(params_dict)
    params_elec[:num_op] = 20
    params_elec[:num_sp] = 8
    params_elec[:deficit_cost] = FixedProfile(1000)
    params_elec[:stack_cost] = FixedProfile(3e5)
    params_elec[:simple] = false

    # Run and test the model
    (m, data) = build_run_electrolyzer_model(params_elec)
    penalty_test(m, data, params_elec)

    # Reassign types
    elect = get_nodes(data)[3]
    hydrogen = get_products(data)[2]
    𝒯     = get_time_struct(data)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
    stack_replace = m[:elect_stack_replace_b][elect, :]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 𝒯.len - 6

    # Test that there are quadratic constraints for Electrolyzer types
    @test length(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64})) ==
        params_elec[:num_op] * params_elec[:num_sp]

    # Test that the penalty is correctly calculated
    # - EMB.constraints_flow_out(m, n::Electrolyzer, 𝒯::TimeStructure, modeltype::EnergyModel)
    @test all(
        norm(
            value.(m[:flow_out][elect, t, hydrogen]) -
            value.(m[:cap_use][elect, t]) * outputs(elect, hydrogen) *
            value.(m[:elect_efficiency_penalty][elect, t])
        ) ≤ TEST_ATOL for t ∈ 𝒯
    )

    finalize(backend(m).optimizer.model)
end
