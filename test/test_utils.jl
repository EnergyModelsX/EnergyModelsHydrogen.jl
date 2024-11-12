@testset "Linear reformulation" begin

    @testset "One index" begin
        # Create a simple model with lower bounds and upper bounds
        function bound_model(prof::TimeProfile;lb=FixedProfile(0))

            # Create the time structure and the bounds
            𝒯 = SimpleTimes(5, 1)
            ub = FixedProfile(10)
            # Create the simple model
            m = JuMP.Model()
            set_optimizer(m, OPTIMIZER)
            @variable(m, lb[t] ≤ var_cont[t ∈ 𝒯] ≤ ub[t])
            @variable(m, var_bin[𝒯], Bin)

            # Add the multiplication variable
            var_mult = EMH.linear_reformulation(m, 𝒯, var_bin, var_cont, lb, ub)

            # Add the constraints and objective
            @constraint(m, [t ∈ 𝒯], var_mult[t] ≥ prof[t])
            @objective(m, Min, sum(var_mult[t] + var_cont[t] + var_bin[t] for t ∈ 𝒯))

            set_optimizer_attribute(m, MOI.Silent(), true)
            optimize!(m)

            return m, var_mult, 𝒯
        end
        function mult_test(m, var_mult, 𝒯)
            @test all(
                value.(var_mult[t]) ≈
                value.(m[:var_cont][t]) * value.(m[:var_bin][t])
            for t ∈ 𝒯)
        end

        # Create a simple case with a lower bound of 0
        prof = OperationalProfile([0, 5, 10, 2, 4])
        m, var_mult, 𝒯 = bound_model(prof)
        mult_test(m, var_mult, 𝒯)

        # Create a simple case with a lower bound of 4
        prof = OperationalProfile([0, 5, 10, 2, 4])
        lb = FixedProfile(4)
        m, var_mult, 𝒯 = bound_model(prof; lb)
        mult_test(m, var_mult, 𝒯)

        # Create a simple case with a lower bound of -4
        prof = OperationalProfile([0, 5, 10, -8, 4])
        lb = FixedProfile(-4)
        m, var_mult, 𝒯 = bound_model(prof; lb)
        mult_test(m, var_mult, 𝒯)
    end

    @testset "Two indices" begin
        # Create a simple model with lower bounds and upper bounds
        function bound_model(prof::TimeProfile;lb=FixedProfile(0))

            # Create the time structure and the bounds
            𝒯 = SimpleTimes(5, 1)
            ub = FixedProfile(10)
            # Create the simple model
            m = JuMP.Model()
            set_optimizer(m, OPTIMIZER)
            @variable(m, lb[t] ≤ var_cont[t ∈ 𝒯] ≤ ub[t])
            @variable(m, var_bin[𝒯, 𝒯], Bin)

            # Add the multiplication variable
            var_mult = EMH.linear_reformulation(m, 𝒯, 𝒯, var_bin, var_cont, lb, ub)

            # Add the constraints and objective
            @constraint(m, [t_a ∈ 𝒯, t_b ∈ 𝒯], var_mult[t_a, t_b] ≥ prof[t_b])
            @objective(m, Min,
                sum(
                    sum(var_mult[t_a, t_b] + var_bin[t_a, t_b] for t_a ∈ 𝒯) +
                    var_cont[t_b]
                for t_b ∈ 𝒯)
            )

            set_optimizer_attribute(m, MOI.Silent(), true)
            optimize!(m)

            return m, var_mult, 𝒯
        end
        function mult_test(m, var_mult, 𝒯)
            @test all(
                    value.(var_mult[t_a, t_b]) ≈
                    value.(m[:var_bin][t_a, t_b]) * value.(m[:var_cont][t_b])
            for t_a ∈ 𝒯, t_b ∈ 𝒯)
        end

        # Create a simple case with a lower bound of 0
        prof = OperationalProfile([0, 5, 10, 2, 4])
        m, var_mult, 𝒯 = bound_model(prof)
        mult_test(m, var_mult, 𝒯)

        # Create a simple case with a lower bound of 4
        prof = OperationalProfile([0, 5, 10, 2, 4])
        lb = FixedProfile(4)
        m, var_mult, 𝒯 = bound_model(prof; lb)
        mult_test(m, var_mult, 𝒯)

        # Create a simple case with a lower bound of -4
        prof = OperationalProfile([0, 5, 10, -8, 4])
        lb = FixedProfile(-4)
        m, var_mult, 𝒯 = bound_model(prof; lb)
        mult_test(m, var_mult, 𝒯)
    end
end
