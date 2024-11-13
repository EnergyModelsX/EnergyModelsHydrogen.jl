"""
    EMB.constraints_capacity(
        m,
        n::AbstractHydrogenNetworkNode,
        𝒯::TimeStructure,
        var,
        modeltype::EnergyModel
    )

Function for creating operational limits of an `AbstractHydrogenNetworkNode`.

The operational limits limit the capacity usage of the electrolyzer node between a minimimum
and maximum load based on the installed capacity.

## TODO:
- Consider the application of the upper bound only for systems in which the efficiency is
  given by a piecewise linear function to account for the increased energy demand at loads
  above the nominal capacity.
"""
function EMB.constraints_capacity(
    m,
    n::AbstractHydrogenNetworkNode,
    𝒯::TimeStructure,
    var,
    modeltype::EnergyModel
)

    @constraint(m, [t ∈ 𝒯],
        min_load(n, t) * var[t] ≤ m[:cap_use][n, t]
    )
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] ≤ max_load(n, t) * var[t]
    )

    constraints_capacity_installed(m, n, 𝒯, modeltype)
end

"""
    EMB.constraints_flow_out(m, n::Electrolyzer, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the outlet flow from an `Electrolyzer` node.
It differs from the reference description by taking into account stack degradation through
the variable `:elect_efficiency_penalty`.
"""
function EMB.constraints_flow_out(m, n::Electrolyzer, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    𝒫ᵒᵘᵗ = outputs(n)

    # Constraint for the individual output stream connections
    @constraint(m, [t ∈ 𝒯, p ∈ 𝒫ᵒᵘᵗ],
        m[:flow_out][n, t, p] ==
            m[:cap_use][n, t] * outputs(n, p) * m[:elect_efficiency_penalty][n, t]
    )
end

"""
    EMB.constraints_opex_var(m, n::Reformer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the constraint on the variable OPEX of a `Reformer` node.
It differs from the reference description through the incorporation of additional costs
in each state of the node.
"""
function EMB.constraints_opex_var(m, n::Reformer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    # Calculation of the cost contributors for start-up, shutdown, and offline state
    prod_start = multiplication_variables(m, n, 𝒯ᴵⁿᵛ.ts, m[:ref_start_b][n, :], modeltype)
    prod_shut = multiplication_variables(m, n, 𝒯ᴵⁿᵛ.ts, m[:ref_shut_b][n, :], modeltype)
    prod_off = multiplication_variables(m, n, 𝒯ᴵⁿᵛ.ts, m[:ref_off_b][n, :], modeltype)

    # Calculation of the OPEX contribution
    for t_inv ∈ 𝒯ᴵⁿᵛ
        @constraint(
            m,
            m[:opex_var][n, t_inv] == sum(
                (
                    EMB.opex_var(n, t) * m[:cap_use][n, t] +
                    opex_startup(n, t) * prod_start[t] +
                    opex_shutdown(n, t) * prod_shut[t] +
                    opex_off(n, t) * prod_off[t]
                )
                * scale_op_sp(t_inv, t)
                for t ∈ t_inv)
        )
    end
end
