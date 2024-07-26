"""
    variables_node(m, 𝒩ˢᵗᵒʳ::Vector{<:AbstractElectrolyzer}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** electrolyzer nodes:
- `:elect_on_b` - binary variable which is 1 if electrolyzer n is running in time step t.
- `:elect_previous_usage` - variable denoting number of previous operation
  periods until time t in which the electrolyzer n has been switched on. The value is provided
  in 1000 operational periods duration to avoid a too large matrix range.
- `:elect_usage_sp` - total time of electrolyzer usage in a strategic period.
- `:elect_usage_rp` - total time of electrolyzer usage in a representative period, only
  declared if the `TimeStructure` includes `RepresentativePeriods`.
- `:elect_usage_mult_sp_b` - multiplier for resetting `:elect_previous_usage`
  when stack replacement occured.
- `:elect_stack_replacement_sp_b` - binary variable, 1 if stack is replaced at the
  first operational period of strategic period.
- `:elect_efficiency_penalty` - coefficient that accounts for drop in efficiency at
  each operational period due to degradation in the electrolyzer. Starts at 1.
"""
function EMB.variables_node(m, 𝒩ᴱᴸ::Vector{AbstractElectrolyzer}, 𝒯, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Variables for degredation
    @variable(m, elect_on_b[𝒩ᴱᴸ, 𝒯], Bin)
    @variable(m, elect_previous_usage[𝒩ᴱᴸ, 𝒯] ≥ 0)
    @variable(m, elect_usage_sp[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ] ≥ 0)
    if 𝒯 isa TwoLevel{S,T,U} where {S,T,U<:RepresentativePeriods}
        𝒯ʳᵖ = repr_periods(𝒯)
        @variable(m, elect_usage_rp[𝒩ᴱᴸ, 𝒯ʳᵖ])
    end
    @variable(m, elect_usage_mult_sp_b[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ, 𝒯ᴵⁿᵛ], Bin)
    @variable(m, elect_mult_sp_aux_b[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ, 𝒯ᴵⁿᵛ, 𝒯ᴵⁿᵛ], Bin)
    @variable(m, elect_stack_replacement_sp_b[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ], Bin)
    @variable(m, 0.0 ≤ elect_efficiency_penalty[𝒩ᴱᴸ, 𝒯] ≤ 1.0)


end

"""
    EMB.create_node(m, n::AbstractElectrolyzer, 𝒯, 𝒫,  modeltype::EnergyModel)

Method to set specialized constraints for electrolyzers including stack degradation and
replacement costs for the stack.
"""
function EMB.create_node(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    mult_sp_aux_b = m[:elect_mult_sp_aux_b][n,:,:,:]

    # Initiate the stack replacement multiplier variable `:elect_usage_mult_sp_b` that is
    # used in the constraints for the previous usage calculation `:elect_previous_usage`
    # at the beginning of a strategic period.
    # The approach is based on the element-wise multiplication of the auxiliary variable
    # `mult_sp_aux_b`. The auxiliary variable creates a multiplier matrix for each
    # strategic period. The elementwise multiplication will then lead to the situation that the
    # previous periods are not counted if there was a stack replacement in between.
    for t_inv ∈ 𝒯ᴵⁿᵛ, t_inv_pre ∈ 𝒯ᴵⁿᵛ
        for t_inv_post ∈ 𝒯ᴵⁿᵛ
            # The following constraints set the auxiliary variable `mult_sp_aux_b`
            # in all previous periods to 0 if there is a stack replacements.
            # Otherwise, it fixs them to 1.
            if isless(t_inv_pre, t_inv) && t_inv_post.sp ≥ t_inv.sp
                @constraint(m,
                    mult_sp_aux_b[t_inv, t_inv_post, t_inv_pre] ==
                        1-m[:elect_stack_replacement_sp_b][n, t_inv]
                )
            else
                JuMP.fix(mult_sp_aux_b[t_inv, t_inv_post, t_inv_pre], 1)
            end

            # Auxiliary constraint for linearizing the elementwise multiplication forcing
            # the multpiplier for the sum of `:elect_usage_sp`, `:elect_usage_mult_sp_b`,
            # to be equal or smaller to the auxiliary variable `mult_sp_aux_b`
            @constraint(m,
                m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre] ≤
                    mult_sp_aux_b[t_inv_post, t_inv, t_inv_pre]
            )
        end

        # Auxiliary constraint for linearizing the elementwise multiplication forcing
        # the multpiplier for the sum of `:elect_usage_sp`, `:elect_usage_mult_sp_b`:
        # to be equal or larger than the sum of the auxiliary variable `mult_sp_aux_b`
        @constraint(m,
            m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre] ≥
                sum(mult_sp_aux_b[t_inv_aux, t_inv, t_inv_pre] for t_inv_aux ∈ 𝒯ᴵⁿᵛ) -
                (𝒯.len-1)
        )
    end

    # Constraints for the calculation of the usage of the electrolyzer in the previous
    # time periods
    constraints_usage(m, n, 𝒯ᴵⁿᵛ, modeltype)

    # Fix the variable `:elect_on_b` for operational periods without capacity
    fix_elect_on_b(m, n, 𝒯, 𝒫, modeltype)

    # Determine the efficiency penalty at current timestep due to degradation:
    # Linearly decreasing to zero with increasing `n.degradation_rate` and `:elect_previous_usage`.
    # With `n.degradation_rate` = 0, the degradation is disabled,
    # Note that `n.degradation_rate` is a percentage and is normalized to the
    # interval [0, 1] in the constraint.
    @constraint(m, [t ∈ 𝒯],
        m[:elect_efficiency_penalty][n, t] ==
            1 - (degradation_rate(n)/100) * m[:elect_previous_usage][n, t]
    )

    # Outlet flow constraint including the efficiency penalty, if an `Electrolyzer` node is
    # used.
    constraints_flow_out(m, n, 𝒯, modeltype)

    # Calculation of auxiliary variables used in the calculation of the usage bound and
    # stack replacement
    prod_on = multiplication_variables(m, n, 𝒯, m[:elect_on_b][n, :], modeltype)
    stack_replace = multiplication_variables(m, n, 𝒯ᴵⁿᵛ, m[:elect_stack_replacement_sp_b][n, :], modeltype)

    # Constraint for the maximum and minimum production volume
    constraints_capacity(m, n, 𝒯, prod_on, modeltype)

    # Constraint for the fixed OPEX contributions. The division by duration_strat(t_inv) for the
    # stack replacement is requried due to multiplication with the duration in the objective
    # calculation
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] ==
            opex_fixed(n, t_inv) * m[:cap_inst][n, first(t_inv)]
            + stack_replace[t_inv] * stack_replacement_cost(n, t_inv) / duration_strat(t_inv)
    )

    # Call of the function for the inlet flow to the `Electrolyzer` node
    constraints_flow_in(m, n, 𝒯, modeltype)

    # Call of the functions for the variable OPEX constraint introduction
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    EMB.variables_node(m, 𝒩ʳᵉᶠ::Vector{Reformer}, 𝒯, modeltype::EnergyModel)


Creates the following additional variables for **ALL** reformer nodes:
- `:ref_off_b` - binary variable which is 1 if reformer `n` is in state `off` in time step `t`.
- `:ref_start_b` - binary variable which is 1 if reformer `n` is in state `start-up` in time step `t`.
- `:ref_on_b` - binary variable which is 1 if reformer `n` is in state `on` in time step `t`.
- `:ref_shut_b` - binary variable which is 1 if reformer `n` is in state `shutdown` in time step `t`.
"""
function EMB.variables_node(m, 𝒩ʳᵉᶠ::Vector{Reformer}, 𝒯, modeltype::EnergyModel)
    # Define the states and binary variables
    @variable(m, ref_off_b[𝒩ʳᵉᶠ, 𝒯], Bin)
    @variable(m, ref_start_b[𝒩ʳᵉᶠ, 𝒯], Bin)
    @variable(m, ref_on_b[𝒩ʳᵉᶠ, 𝒯], Bin)
    @variable(m, ref_shut_b[𝒩ʳᵉᶠ, 𝒯], Bin)
end

"""
    EMB.create_node(m, n::Reformer, 𝒯, 𝒫, modeltype::EnergyModel)

Sets all constraints for a reformer technology node.
"""
function EMB.create_node(m, n::Reformer, 𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets.
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # General flow in and out constraints
    constraints_flow_in(m, n, 𝒯, modeltype)
    constraints_flow_out(m, n, 𝒯, modeltype)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Calculation of auxiliary variables used in the calculation of the usage bounds
    prod_on = multiplication_variables(m, n, 𝒯, m[:ref_on_b][n, :], modeltype)

    # Constraint for the maximum and minimum production volume
    constraints_capacity(m, n, 𝒯, prod_on, modeltype)

    # Only one state active in each time-step
    @constraint(m, [t ∈ 𝒯],
        m[:ref_off_b][n, t] + m[:ref_start_b][n, t] + m[:ref_on_b][n, t] + m[:ref_shut_b][n, t]
            == 1
    )

    for t_inv ∈ 𝒯ᴵⁿᵛ
        # Calaculation of the last operational period
        t_last  = last(t_inv)

        # Constraints for the order of the states of the reformer node
        constraints_state_seq_iter(m, n, t_inv, t_last, t_inv.operational, modeltype)

        # Constraints for the minimum time of the individual states
        constraints_state_time_iter(m, n, t_inv, t_last, t_inv.operational, modeltype)
    end

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end
