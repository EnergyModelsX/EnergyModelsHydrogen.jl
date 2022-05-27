# This file provides the additional functionality (variables and constraints) added for newly defined structures.
"""
    variables_node(m, 𝒩, 𝒯, node::Electrolyzer, modeltype)
Creates the following additional variables for all electrolyzer nodes:
1) elect_on[n,t] - Binary variable which is 1 if electrolyzer n is running in time step t. 
2) previous_usage[n,t] - Integer variable denoting number of previous operation periods until time t in which the electrolyzer n has been switched on.
"""
function EMB.variables_node(m, 𝒩, 𝒯, node::Electrolyzer, modeltype)
    𝒩ᴴ = EMB.node_sub(𝒩, Electrolyzer)
    @variable(m, elect_on[𝒩ᴴ, 𝒯], Bin)
    @variable(m, previous_usage[𝒩ᴴ,𝒯] >= 0, Int)
end

"""
    is_prior(t_prev::TS.OperationalPeriod, t::TS.OperationalPeriod, 𝒯::UniformTwoLevel)
Returns true if the t_prev timestep occurs chronologically before or at the same time as the t timestep.
Needs to be extended for the other kinds of time structures! Potentially redundant function if TimeStructures.jl provides ordering/previous - next implementation is correct.
"""
function is_prior(t_prev::TS.OperationalPeriod, t::TS.OperationalPeriod, 𝒯::UniformTwoLevel)
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

function EMB.create_node(m, n::Electrolyzer, 𝒯, 𝒫)

    # Declaration of the required subsets
    𝒫ⁱⁿ  = keys(n.Input)
    𝒫ᵒᵘᵗ = keys(n.Output)
    𝒫ᵉᵐ  = EMB.res_sub(𝒫, EMB.ResourceEmit)
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)



    # Unchanged from EMB.Network: Constraint for the individual stream connections
    for p ∈ 𝒫ⁱⁿ
        @constraint(m, [t ∈ 𝒯], 
            m[:flow_in][n, t, p] == m[:cap_use][n, t]*n.Input[p])
    end

    # Define the total previous usage of the electrolyzer prior to the current timestep
    @constraint(m, [t ∈ 𝒯],
        m[:previous_usage][n,t] == sum(m[:elect_on][n, t_prev] for t_prev ∈ 𝒯 if is_prior(t_prev,t,𝒯)))

    # Constrain total previous usage of the electrolyzer (including usage at current time step). 
    @constraint(m, [t ∈ 𝒯],
        m[:previous_usage][n,t] <= n.Equipment_lifetime)

    # Modified the else case to include a big-M constraint with binary variable
    # [IS THE BILINEAR TERM UNAVOIDABLE FOR DEGRADATION?]
    for p ∈ 𝒫ᵒᵘᵗ
        if p.id == "CO2"
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p]  == n.CO2_capture*sum(p_in.CO2Int*m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ))
        else
            #@constraint(m, [t ∈ 𝒯], m[:flow_out][n, t, p] == m[:cap_use][n, t]*n.Output[p])
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p] == m[:cap_use][n, t]*n.Output[p]*(1 - (n.Degradation_rate/100)*m[:previous_usage][n,t]))
            @constraint(m, [t ∈ 𝒯], 
                m[:flow_out][n, t, p] <= n.Cap[t]*m[:elect_on][n,t]) # Note that big M = n.Cap not cap_inst to avoid another bilinear term
        end
        
    end

    # Changed from EMB.Network to new Minimum_load and Maximum_load: Constraint for the maximum throughput
    @constraint(m, [t ∈ 𝒯],
        n.Minimum_load*n.Cap[t] <= m[:cap_use][n, t] <= n.Maximum_load*n.Cap[t])
    
    # Unchanged from EMB.Network: Constraints on nodal emissions.
    for p_em ∈ 𝒫ᵉᵐ
        if p_em.id == "CO2"
            @constraint(m, [t ∈ 𝒯],
                m[:emissions_node][n, t, p_em] == 
                    (1-n.CO2_capture)*sum(p_in.CO2Int*m[:flow_in][n, t, p_in] for p_in ∈ 𝒫ⁱⁿ) + 
                    m[:cap_use][n, t]*n.Emissions[p_em])
        else
            @constraint(m, [t ∈ 𝒯],
                m[:emissions_node][n, t, p_em] == 
                    m[:cap_use][n, t]*n.Emissions[p_em])
        end
    end
            
    # Unchanged from EMB.Network: Constraint for the Opex contributions
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_var][n, t_inv] == sum(m[:cap_use][n, t] * n.Opex_var[t] * t.duration for t ∈ t_inv))
end



