"""
    variables_node(m, 𝒩ˢᵗᵒʳ::Vector{<:Electrolyzer}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** electrolyzer nodes:
- `:elect_on_b` - binary variable which is 1 if electrolyzer n is running in time step t. 
- `:elect_previous_usage` - tnteger variable denoting number of previous operation 
periods until time t in which the electrolyzer n has been switched on.
- `:elect_usage_sp` - total time of electrolyzer usage in a strategic period.
- `:elect_usage_mult_sp_b` - multiplier for resetting `:elect_previous_usage`  
when stack replacement occured.
- `:elect_usage_mult_sp_aux_b` - auxiliary variable for calculating the 
multiplier matrix `elect_usage_mult_sp_b`.
- `:elect_stack_replacement_sp_b` - binary variable, 1 if stack is replaced at the 
first operational period of strategic period.
- `:elect_efficiency_penalty` - coefficient that accounts for drop in efficiency at
each operational period due to degradation in the electrolyzer. Starts at 1.
"""
function EMB.variables_node(m, 𝒩ᴱᴸ::Vector{Electrolyzer}, 𝒯, modeltype::EnergyModel)
    
    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Variables for degredation
    @variable(m, elect_on_b[𝒩ᴱᴸ, 𝒯], Bin)
    @variable(m, elect_previous_usage[𝒩ᴱᴸ, 𝒯] >= 0, Int)
    @variable(m, elect_usage_sp[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ] >= 0, Int)
    @variable(m, elect_usage_mult_sp_b[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ, 𝒯ᴵⁿᵛ], Bin, start = 1)
    @variable(m, elect_usage_mult_sp_aux_b[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ, 𝒯ᴵⁿᵛ, 𝒯ᴵⁿᵛ], Bin, start = 1)
    @variable(m, elect_stack_replacement_sp_b[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ], Bin)
    @variable(m, 0.0 <= elect_efficiency_penalty[𝒩ᴱᴸ, 𝒯] <= 1.0)
end

"""
    EMB.create_node(m, n::Electrolyzer, 𝒯, 𝒫,  modeltype::EnergyModel)

Method to set specialized constraints for electrolyzers including stack degradation and
replacement costs for the stack.
"""
function EMB.create_node(m, n::Electrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    𝒫ᵒᵘᵗ = keys(n.Output)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Initiate the stack replacement multiplier variable `:elect_usage_mult_sp_b` that is
    # used in the constraints for the previous usage calculation `:elect_previous_usage`
    # at the beginning of a strategic period
    # The approach is based on the element-wise multiplication of the auxiliary variable
    # `:elect_usage_mult_sp_aux_b`. The auxiliary variable creates a multiplier matrix for each
    # strategic period. The elementwise multiplication will then lead to the situation that the
    # previous periods are not counted if there was a stack replacement in between. 
    for t_inv ∈ 𝒯ᴵⁿᵛ, t_inv_pre ∈ 𝒯ᴵⁿᵛ
        for t_inv_post ∈ 𝒯ᴵⁿᵛ
            # The following constraints set the auxiliary variable `:elect_usage_mult_sp_aux_b`
            # in all previous periods to 0 if there is a stack replacements. Otherwise, it sets
            # them to 1.
            if isless(t_inv_pre, t_inv) && t_inv_post.sp >= t_inv.sp
                @constraint(m,
                    m[:elect_usage_mult_sp_aux_b][n, t_inv, t_inv_post, t_inv_pre] == 
                        1-m[:elect_stack_replacement_sp_b][n, t_inv]
                )
            else
                @constraint(m,
                    m[:elect_usage_mult_sp_aux_b][n, t_inv, t_inv_post, t_inv_pre] == 
                        1
                )
            end

            # Auxiliary constraint for linearizing the elementwise multiplication forcing
            # the multpiplier for the sum of `:elect_usage_sp`, `:elect_usage_mult_sp_b`,
            # to be equal or smaller to the auxiliary variable `:elect_usage_mult_sp_aux_b`
            @constraint(m,
                m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre] <=
                    m[:elect_usage_mult_sp_aux_b][n, t_inv, t_inv_post, t_inv_pre]
            )
        end
        # Auxiliary constraint for linearizing the elementwise multiplication forcing
        # the multpiplier for the sum of `:elect_usage_sp`, `:elect_usage_mult_sp_b`:
        # to be equal or larger than the sum of the auxiliary variable `:elect_usage_mult_sp_aux_b`
        @constraint(m,
            m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre] >= 
                sum(m[:elect_usage_mult_sp_aux_b][n, t_inv_aux, t_inv, t_inv_pre] for t_inv_aux ∈ 𝒯ᴵⁿᵛ) - 
                (𝒯.len-1)
        )
    end

    # Previous usage, logic:
    # Within all the years (in `sp.duration`) we assume the degradation is the same as it
    # is in the 1st year of that strategic period (optimistic assumption). However, when 
    # we move to the next strategic period, we sum up the total usage in the previous
    # strategic periods
    # This ensures that the next strategic period starts after accounting for all prior usage.
    # Stack replacement resets the previous usage via the multiplier variable `:elect_usage_mult_sp_b`
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m,
            m[:elect_usage_sp][n, t_inv] == 
                sum(m[:elect_on_b][n, t]*duration(t) for t ∈ t_inv) *
                duration(t_inv)
        )
        for (t_prev, t) ∈ withprev(t_inv)
            if isnothing(t_prev)
                @constraint(m,
                    m[:elect_previous_usage][n, t] ==
                        sum(
                            m[:elect_usage_sp][n, t_inv_pre] * 
                            m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre]
                            for t_inv_pre ∈ 𝒯ᴵⁿᵛ if isless(t_inv_pre, t_inv)
                        )
                )
            else
                @constraint(m,
                    m[:elect_previous_usage][n, t] ==
                        m[:elect_previous_usage][n, t_prev] + 
                        duration(t_prev) * m[:elect_on_b][n, t_prev]
                )
            end
        end
    end

    # Constraint total usage of the electrolyzer including at the current time step.
    # This ensures that the last time step is appropriately constrained. 
    @constraint(m, [t ∈ 𝒯],
        m[:elect_previous_usage][n,t] + duration(t)*m[:elect_on_b][n, t] <= n.Stack_lifetime
    )

    # Determine the efficiency penalty at current timestep due to degradation:
    # Linearly decreasing to zero with increasing `n.Degradation_rate` and `:elect_previous_usage`.
    # With `n.Degradation_rate` = 0, the degradation is disabled,
    # Note that `n.Degradation_rate` is a percentage and is normalized to the 
    # interval [0, 1] in the constraint.
    @constraint(m, [t ∈ 𝒯],
        m[:elect_efficiency_penalty][n,t] == 1 - (n.Degradation_rate/100)*m[:elect_previous_usage][n,t]
    )

    # Outlet flow constraint including the efficiency penalty
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ], 
        m[:flow_out][n, t, p] == m[:cap_use][n, t]*n.Output[p]*m[:elect_efficiency_penalty][n,t]
    )

    # Definition of the helper variable for the linear reformulation of the product of
    # `:cap_inst` and `:elect_on_b`. This reformulation requires the introduction of both an
    # cap_upper_bound and a cap_lower_bound of the variable `:cap_inst`. These bounds are 
    # depending on whether Investments are allowed or not. In the case of no investments,
    # this removes the bilinear term.
    product_on = @variable(m, [𝒯], lower_bound = 0)
    cap_upper_bound = n.Cap
    cap_lower_bound = n.Cap
    for d ∈ n.Data
        if hasproperty(d, :Cap_max_inst)
            cap_upper_bound = d.Cap_max_inst
            cap_lower_bound = FixedProfile(0)
            break
        end
    end

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable. This reformulation requires the definition 
    # of a new variable `:product_on = :cap_inst * :elect_on_b`.
    @constraints(m, begin 
        [t ∈ 𝒯], product_on[t] >= cap_lower_bound[t] * m[:elect_on_b][n,t]
        [t ∈ 𝒯], product_on[t] >= cap_upper_bound[t]*(m[:elect_on_b][n,t]-1) + m[:cap_inst][n, t]
        [t ∈ 𝒯], product_on[t] <= cap_upper_bound[t] * m[:elect_on_b][n,t]
        [t ∈ 𝒯], product_on[t] <= cap_lower_bound[t]*(m[:elect_on_b][n,t]-1) + m[:cap_inst][n, t]
    end)

    # Constraint for the maximum and minimum production volume
    @constraint(m, [t ∈ 𝒯],
        n.Minimum_load * product_on[t] <= m[:cap_use][n, t]
    )
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= n.Maximum_load * product_on[t]
    )

    # Constraint for the emissions associated to using the electrolyzer
    @constraint(m, [t ∈ 𝒯, p_em ∈ 𝒫ᵉᵐ],
        m[:emissions_node][n, t, p_em] == 0)

    # Constraints for the linear reformulation of the mulitplication of the stack
    # replacement binary and the installed capacity. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable. This reformulation requires the definition 
    # of a new variable `:product_replace = :cap_inst * :elect_stack_replacement_sp_b`.
    product_replace = @variable(m, [𝒯ᴵⁿᵛ], lower_bound = 0)
    @constraints(m, begin 
        [t_inv ∈ 𝒯ᴵⁿᵛ], product_replace[t_inv] >= 
                            cap_lower_bound[t_inv] * m[:elect_stack_replacement_sp_b][n,t_inv]

        [t_inv ∈ 𝒯ᴵⁿᵛ], product_replace[t_inv] >= 
                            cap_upper_bound[t_inv]*(m[:elect_stack_replacement_sp_b][n,t_inv]-1) + m[:cap_inst][n, first(t_inv)]

        [t_inv ∈ 𝒯ᴵⁿᵛ], product_replace[t_inv] <= 
                            cap_upper_bound[t_inv] * m[:elect_stack_replacement_sp_b][n,t_inv]

        [t_inv ∈ 𝒯ᴵⁿᵛ], product_replace[t_inv] <= 
                            cap_lower_bound[t_inv]*(m[:elect_stack_replacement_sp_b][n,t_inv]-1) + m[:cap_inst][n, first(t_inv)]
    end)

    # Constraint for the fixed OPEX contributions. The division by duration(t_inv) for the
    # stack replacement is requried due to multiplication with the duration in the objective
    # calculation
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] == 
            n.Opex_fixed[t_inv] * m[:cap_inst][n, first(t_inv)]
            + product_replace[t_inv] * n.Stack_replacement_cost[t_inv] / duration(t_inv)
    )

    # Call of the function for the inlet flow to the `Electrolyzer` node
    EMB.constraints_flow_in(m, n, 𝒯, modeltype)
            
    # Call of the functions for the variable OPEX constraint introduction
    EMB.constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end