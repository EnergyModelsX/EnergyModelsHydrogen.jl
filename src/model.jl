# This file provides the additional functionality (variables and constraints) added for newly defined structures.
"""
    variables_node(m, 𝒩, 𝒯, node::Electrolyzer, modeltype)
Creates the following additional variables for **ALL** electrolyzer nodes:
1) `elect_on[n,t]` - Binary variable which is 1 if electrolyzer n is running in time step t. 
2) `previous_usage[n,t]` - Integer variable denoting number of previous operation periods until time t in which the electrolyzer n has been switched on.
TODO: `previous_usage[n,t]` can potentially be left as a continuous variable. Test if the computational performance with SCIP/Gurobi is better or worse.
3) `efficiency_penalty[n,t]` - Coefficient that accounts for drop in efficiency at time t due to degradation in electrolyzer n. Drops from 1 at start. 
"""
function EnergyModelsBase.variables_node(m, 𝒩, 𝒯, node::Electrolyzer, modeltype::EnergyModel)
    𝒩ᴴ = EnergyModelsBase.node_sub(𝒩, typeof(node))
    @variable(m, elect_on[𝒩ᴴ, 𝒯], Bin)
    @variable(m, previous_usage[𝒩ᴴ,𝒯] >= 0, Int)
    @variable(m, 0.0 <= efficiency_penalty[𝒩ᴴ,𝒯] <= 1.0)
end

#= DEPRECATED CODE, replaced with logic involving previous()
"""
    is_prior(t_prev::TimeStructures.OperationalPeriod, t::TimeStructures.OperationalPeriod, 𝒯::UniformTwoLevel)
Returns true if the t_prev timestep occurs chronologically before or at the same time as the t timestep.
Needs to be extended for the other kinds of time structures! Potentially redundant function if TimeStructures.jl provides ordering/previous - next implementation is correct.
"""
function is_prior(t_prev::TimeStructures.OperationalPeriod, t::TimeStructures.OperationalPeriod, 𝒯::UniformTwoLevel)
    if (t_prev.sp < t.sp)
        return true
    elseif (t_prev.sp == t.sp)
        if (t_prev.op <= t.op)
            return true
        else
            return false
        end
    else
        return false
    end
end
=#


"""
    create_node(m, n::Electrolyzer, 𝒯, 𝒫)
Method to set specialized constraints for electrolyzers. The following features are added:
- 1. Degradation. This takes in the user-specified `Degradation_rate` parameter.  
First, the `previous_usage[n,t]` is used to keep track of the total previous usage. 
    
    
"""
function EnergyModelsBase.create_node(m, n::Electrolyzer, 𝒯, 𝒫)


    # Declaration of the required subsets
    𝒫ⁱⁿ  = keys(n.Input)
    𝒫ᵒᵘᵗ = keys(n.Output)
    𝒫ᵉᵐ  = EnergyModelsBase.res_sub(𝒫, EnergyModelsBase.ResourceEmit)
    𝒯ᴵⁿᵛ = EnergyModelsBase.strategic_periods(𝒯)


    # Unchanged: Get products flows as functions of node characteristic flow.
    for p ∈ 𝒫ⁱⁿ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_in][n, t, p] == m[:cap_use][n, t]*n.Input[p])
    end

    # Previous usage, logic:
    # Within all the years (in `sp.duration`) we assume the degradation is the same as it is in the 1st year of that strategic period (optimistic assumption). 
    # However, when we move to the next strategic period, we multiply the final usage after its `last_operational` period by the `sp.duration` (number of years).
    # This ensures that the next strategic period starts after accounting for all prior usage. 

    for t ∈ 𝒯 # Returns all `OperationalPeriod` items in any type of 𝒯.
        if (TimeStructures.isfirst(t))
            if t.sp == 1 # This deals with the case where `nothing` is returned from `previous(sp::StrategicPeriod, .)`
                @constraint(m,
                m[:previous_usage][n,t] == 0.0 # First time-step of overall time structure. New electrolyzer.  
                )
            else 
                @constraint(m,
                m[:previous_usage][n,t] == (m[:previous_usage][n, last_operational(previous(t.sp, 𝒯))] + last_operational(previous(t.sp, 𝒯)).duration*m[:elect_on][n, last_operational(previous(t.sp, 𝒯))])*previous(t.sp, 𝒯).duration
                )
            end
        else
            @constraint(m,
                m[:previous_usage][n,t] == m[:previous_usage][n, previous(t, 𝒯)] + previous(t, 𝒯).duration*m[:elect_on][n, previous(t, 𝒯)]
                )
        end
    end

    # Constrain total usage of the electrolyzer including at the current time step. This ensures that the last time step is appropriately constrained. 
    @constraint(m, [t ∈ 𝒯],
        m[:previous_usage][n,t] + t.duration*m[:elect_on][n, t] <= n.Equipment_lifetime
        )

    # Determine the efficiency penalty at current timestep due to degradation 
    @constraint(m, [t ∈ 𝒯],
        m[:efficiency_penalty][n,t] == (1 - (n.Degradation_rate/100)*m[:previous_usage][n,t])
        )

    # Additional big-M constraint with binary variable: `flow_out[n, t, p]` is > 0 only if `elect_on[n,t]` is 1. 
    for p ∈ 𝒫ᵒᵘᵗ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_out][n, t, p] == m[:cap_use][n, t]*n.Output[p]*m[:efficiency_penalty][n,t] # Accounts for degradation
            )

        @constraint(m, [t ∈ 𝒯], 
            m[:flow_out][n, t, p] <= 1000*n.Cap[t]*m[:elect_on][n,t] # Take Big-M to be 1000 times the n.Cap[t]
            )
    end

    # Changed from EnergyModelsBase.Network to new Minimum_load and Maximum_load: Constraint for the maximum throughput
    @constraint(m, [t ∈ 𝒯],
        n.Minimum_load*m[:cap_inst][n, t] <= m[:cap_use][n, t]
    )
        
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t]<= n.Maximum_load*m[:cap_inst][n, t]
    )
    
    # Unchanged from EnergyModelsBase.Network: Constraints on nodal emissions.
    for p_em ∈ 𝒫ᵉᵐ
        @constraint(m, [t ∈ 𝒯],
            m[:emissions_node][n, t, p_em] == m[:cap_use][n, t]*n.Emissions[p_em])
    end
            
    # Unchanged from EnergyModelsBase.Network: Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv))
end



