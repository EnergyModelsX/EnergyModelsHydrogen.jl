"""
    variables_node(m, 𝒩, 𝒯, node::Electrolyzer, modeltype)

Creates the following additional variables for **ALL** electrolyzer nodes:
1) `elect_on_b[n,t]` - Binary variable which is 1 if electrolyzer n is running in time step t. 
2) `elect_previous_usage[n,t]` - Integer variable denoting number of previous operation periods until
    time t in which the electrolyzer n has been switched on.
    TODO: `elect_previous_usage[n,t]` can potentially be left as a continuous variable. Test if the
    computational performance with SCIP/Gurobi is better or worse.
3) `elect_usage_in_sp[n, t_in]`: Amount of electrolyzer usage in strategic period.
4 `elect_stack_replacement_sp_b[n, t_in]`: Binary variable, 1 if stack is replaced at first op of strategic period.
5) `elect_efficiency_penalty[n,t]` - Coefficient that accounts for drop in efficiency at time t due
to degradation in electrolyzer n. Drops from 1 at start. 
"""
function EMB.variables_node(m, 𝒩, 𝒯, node::Electrolyzer, modeltype::EnergyModel)
    
    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
    𝒩ᴴ = EMB.node_sub(𝒩, Electrolyzer)

    # Variables for degredation
    @variable(m, elect_on_b[𝒩ᴴ, 𝒯], Bin)
    @variable(m, elect_previous_usage[𝒩ᴴ, 𝒯] >= 0, Int)
    @variable(m, elect_usage_in_sp[𝒩ᴴ, 𝒯ᴵⁿᵛ] >= 0, Int)
    @variable(m, elect_stack_replacement_sp_b[𝒩ᴴ, 𝒯ᴵⁿᵛ], Bin)
    @variable(m, 0.0 <= elect_efficiency_penalty[𝒩ᴴ, 𝒯] <= 1.0)
end

"""
    is_prior(t_prev::TS.StrategicPeriod, t::TS.StrategicPeriod)
Returns true if the `t_prev` timestep occurs chronologically before the timestep `t`.
"""
function is_prior(t_prev::TS.StrategicPeriod, t::TS.StrategicPeriod)
    if (t_prev.sp < t.sp)
        return true
    else
        return false
    end
end


"""
    create_node(m, n::Electrolyzer, 𝒯, 𝒫)
Method to set specialized constraints for electrolyzers including stack degradation and
replacement costs.
"""
function EMB.create_node(m, n::Electrolyzer, 𝒯, 𝒫)


    # Declaration of the required subsets
    𝒫ⁱⁿ  = keys(n.Input)
    𝒫ᵒᵘᵗ = keys(n.Output)
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, ResourceEmit)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)


    # Constraints for inflow to the node
    for p ∈ 𝒫ⁱⁿ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_in][n, t, p] == m[:cap_use][n, t]*n.Input[p])
    end

    # Previous usage, logic:
    # Within all the years (in `sp.duration`) we assume the degradation is the same as it
    # is in the 1st year of that strategic period (optimistic assumption). However, when 
    # we move to the next strategic period, we sum up the total usage in the previous
    # strategic periods
    # This ensures that the next strategic period starts after accounting for all prior usage. 
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(m,
            m[:elect_usage_in_sp][n, t_inv] == 
                sum(m[:elect_on_b][n, t]*t.duration for t ∈ t_inv) *
                t_inv.duration
        )
        for t ∈ t_inv
            if (TS.isfirst(t))
                @constraint(m,
                    m[:elect_previous_usage][n, t] ==
                        (sum(m[:elect_usage_in_sp][n, t_inv_prev] for t_inv_prev ∈ 𝒯ᴵⁿᵛ if is_prior(t_inv_prev, t_inv)))*
                        (1 - m[:elect_stack_replacement_sp_b][n, t_inv])
                )
            else
                @constraint(m,
                    m[:elect_previous_usage][n, t] ==
                        m[:elect_previous_usage][n, previous(t, 𝒯)] + 
                        previous(t, 𝒯).duration * m[:elect_on_b][n, previous(t, 𝒯)]
                )
            end
        end
    end

    # Constraint total usage of the electrolyzer including at the current time step.
    # This ensures that the last time step is appropriately constrained. 
    @constraint(m, [t ∈ 𝒯],
        m[:elect_previous_usage][n,t] + t.duration*m[:elect_on_b][n, t] <= n.Equipment_lifetime
        )

    # Determine the efficiency penalty at current timestep due to degradation 
    @constraint(m, [t ∈ 𝒯],
        m[:elect_efficiency_penalty][n,t] == (1 - (n.Degradation_rate/100)*m[:elect_previous_usage][n,t])
        )

    # Outlet flow constraint including the efficiency penalty
    for p ∈ 𝒫ᵒᵘᵗ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_out][n, t, p] == m[:cap_use][n, t]*n.Output[p]*m[:elect_efficiency_penalty][n,t]
            )

    end

    # Definition of the helper variable for the linear reformulation of the product of
    # `:cap_inst` and `:elect_on_b`. This reformulation requires the defintion of a new
    # variable `product = :cap_inst * :elect_on_b` and the introduction of both an
    # upper_bound and a lower_bound of the variable `:cap_inst`. These bounds are 
    # depending on whether Investments are allowed or not. In the case of no investments,
    # this removes the bilinear term.
    product = @variable(m, [𝒯], lower_bound = 0)
    if haskey(n.Data,"Investments") 
        upper_bound = n.Data["Investments"].Cap_max_inst
        lower_bound = FixedProfile(0)
    else
        upper_bound = n.Cap
        lower_bound = n.Cap
    end

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable
    @constraints(m, begin 
        [t ∈ 𝒯], product[t] >= lower_bound[t] * m[:elect_on_b][n,t]
        [t ∈ 𝒯], product[t] >= upper_bound[t]*(m[:elect_on_b][n,t]-1) + m[:cap_inst][n, t]
        [t ∈ 𝒯], product[t] <= upper_bound[t] * m[:elect_on_b][n,t]
        [t ∈ 𝒯], product[t] <= lower_bound[t]*(m[:elect_on_b][n,t]-1) + m[:cap_inst][n, t]
    end)

    # Constraint for the maximum and minimum production volume
    @constraint(m, [t ∈ 𝒯],
        n.Minimum_load * product[t] <= m[:cap_use][n, t]
    )
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] <= n.Maximum_load * product[t]
    )
    
    # Constraints on nodal process emissions
    for p_em ∈ 𝒫ᵉᵐ
        @constraint(m, [t ∈ 𝒯],
            m[:emissions_node][n, t, p_em] == m[:cap_use][n, t]*n.Emissions[p_em])
    end
            
    # Constraint for the Opex contributions
    # Note: Degradation included into opex_var although it is not! Simpler implementation
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == 
            sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv)
            + n.Stack_replacement_cost[t_inv] * m[:elect_stack_replacement_sp_b][n, t_inv] / t_inv.duration)
end