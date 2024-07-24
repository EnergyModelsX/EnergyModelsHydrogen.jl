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
    :data => Data[]
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
    params_inv[:data] = Data[SingleInvData(
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
    elect = data[:nodes][3]
    𝒯     = data[:T]
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
    elect = data[:nodes][3]
    𝒯     = data[:T]
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
    stack_replace = m[:elect_stack_replacement_sp_b][elect, :]
    stack_mult   = m[:elect_usage_mult_sp_b][elect, :, :]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 𝒯.len - 6

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

    # Test for the multiplier matrix that it is 0 for the block if there was a stack
    # replacement. It will reset the block via the variable `t_replace` to the new
    # `t_inv`, if the variable`:elect_stack_replacement_sp_b` is 1
    @testset "Multiplier test" begin
        t_replace = nothing
        logic     = false
        for t_inv ∈ 𝒯ᴵⁿᵛ, t_inv_pre ∈ 𝒯ᴵⁿᵛ
            if value.(stack_replace[t_inv]) ≈ 1
                t_replace = t_inv
                logic = true
            elseif t_inv.sp == 1
                t_replace = t_inv
                logic = false
            end
            if logic
                if isless(t_inv_pre, t_replace)
                    @test value.(stack_mult[t_inv, t_inv_pre]) ≈ 0 atol = TEST_ATOL
                else
                    @test value.(stack_mult[t_inv, t_inv_pre]) ≈ 1
                end
            else
                @test value.(stack_mult[t_inv, t_inv_pre]) ≈ 1
            end
        end
    end

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
    elect = data[:nodes][3]
    𝒯     = data[:T]
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
    stack_replace = m[:elect_stack_replacement_sp_b][elect, :]
    stack_mult   = m[:elect_usage_mult_sp_b][elect, :, :]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 𝒯.len - 6

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test isempty(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64}))

    # Test for the multiplier matrix that it is 0 for the block if there was a stack
    # replacement. It will reset the block via the variable `t_replace` to the new
    # `t_inv`, if the variable`:elect_stack_replacement_sp_b` is 1
    @testset "Multiplier test" begin
        t_replace = nothing
        logic     = false
        for t_inv ∈ 𝒯ᴵⁿᵛ, t_inv_pre ∈ 𝒯ᴵⁿᵛ
            if value.(stack_replace[t_inv]) ≈ 1
                t_replace = t_inv
                logic = true
            elseif t_inv.sp == 1
                t_replace = t_inv
                logic = false
            end
            if logic
                if isless(t_inv_pre, t_replace)
                    @test value.(stack_mult[t_inv, t_inv_pre]) ≈ 0 atol = TEST_ATOL
                else
                    @test value.(stack_mult[t_inv, t_inv_pre]) ≈ 1
                end
            else
                @test value.(stack_mult[t_inv, t_inv_pre]) ≈ 1
            end
        end
    end

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
    elect = data[:nodes][3]
    hydrogen = data[:products][2]
    𝒯     = data[:T]
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
    stack_replace = m[:elect_stack_replacement_sp_b][elect, :]
    stack_mult   = m[:elect_usage_mult_sp_b][elect, :, :]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 𝒯.len - 6

    # Test that there are no quadratic constraints for SimpleElectrolyzer types
    @test length(all_constraints(m, QuadExpr, MOI.EqualTo{MOI.Float64})) ==
        params_elec[:num_op] * params_elec[:num_sp]

    # Test that the penalty is correctly calculated
    # - EMB.constraints_flow_out(m, n::Electrolyzer, 𝒯::TimeStructure, modeltype::EnergyModel)
    @test sum(
                value.(m[:flow_out][elect, t, hydrogen]) ≈
                value.(m[:cap_use][elect, t]) * outputs(elect, hydrogen) *
                value.(m[:elect_efficiency_penalty][elect, t]) for t ∈ 𝒯, atol=TEST_ATOL
            ) == length(𝒯)


    finalize(backend(m).optimizer.model)
end
