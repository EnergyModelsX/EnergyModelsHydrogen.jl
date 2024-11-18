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
    EMB.constraints_capacity(
        m,
        n::AbstractH2Storage,
        𝒯::TimeStructure,
        modeltype::EnergyModel
    )

Function for creating the constraints on the `:stor_level`, `:stor_charge_use`, and
`:stor_discharge_use` variables for a [`AbstractH2Storage`](@ref) node.

The discharge `:stor_discharge_use` is limited by the installed charging capacity
`stor_charge_inst` and the multiplier `discharge_charge` due to the limitations given by the
physical integrity of the storage vessel and/or the injection connection.

The installed charge capacity `:stor_charge_inst` times its field `level_charge` has an
upper bound given by the installed storage capacity `stor_level_inst`. In the case of
operational models, this is checked while in the case of investment models, it is constrained.
"""
function EMB.constraints_capacity(
    m,
    n::AbstractH2Storage,
    𝒯::TimeStructure,
    modeltype::EnergyModel
)
    @constraint(m, [t ∈ 𝒯], m[:stor_level][n, t] ≤ m[:stor_level_inst][n, t])
    @constraint(m, [t ∈ 𝒯], m[:stor_charge_use][n, t] ≤ m[:stor_charge_inst][n, t])

    # The discharge is limited by the charge capacity and a multiplier
    @constraint(m, [t ∈ 𝒯],
        m[:stor_discharge_use][n, t] ≤
            m[:stor_charge_inst][n, t] * discharge_charge(n)
    )
    # The charge capacity times a multiplier is limited by the level capacity
    @constraint(m, [t ∈ 𝒯],
        m[:stor_charge_inst][n, t]  * level_charge(n) ≤
            m[:stor_level_inst][n, t]
    )

    constraints_capacity_installed(m, n, 𝒯, modeltype)
end

"""
    EMB.constraints_flow_in(m, n::HydrogenStorage, 𝒯::TimeStructure, modeltype::EnergyModel)

Function for creating the constraint on the inlet flow to a [`HydrogenStorage`](@ref) node.

It differs from the reference description by considering the dependency of the compression
power on the storage level.

This is achieved through calling the subfunction [`energy_curve`]
"""
function EMB.constraints_flow_in(m, n::HydrogenStorage, 𝒯::TimeStructure, modeltype::EnergyModel)
    # Declaration of the required subsets
    p_el = electricity_resource(n)
    p_stor = storage_resource(n)

    # Physical input parameters
    pᵢₙ = p_charge(n)
    pₘᵢₙ = p_min(n)
    pₘₐₓ = p_max(n)
    PRₘₐₓ = 2.5

    # Component specific input data
    M = 2.02
    HHV = 141.9
    LHV = 120.0

    # Calculation of the required pressure ratios for compression
    PRₜₒₜ = pₘₐₓ/pᵢₙ
    n_comp = Int(ceil(log(PRₜₒₜ)/log(PRₘₐₓ)))
    PR = PRₜₒₜ^(1/n_comp)

    # Calculation of the breakpoints based on the specified maximum pressure ratio
    # The breakpoints are pure;y based on the differences.
    # It can be that the individual breakpoints are limited based on the charge and minimum
    # pressure
    tmp = [[pₘᵢₙ]]
    append!(tmp, [[pᵢₙ*PR^i, (1/3*PR+2/3)*pᵢₙ*PR^i] for i ∈ 0:n_comp-1])
    p̂ = unique(reduce(vcat, push!(tmp, [pₘₐₓ])))
    filter!(p -> p ≥ pₘᵢₙ, p̂)
    sort!(p̂)
    n_p = length(p̂)

    # Calculation the relative energy demand at the different pressure break points
    Ŵ = [energy_curve(p, pᵢₙ, PR, n_comp, M, LHV) for p ∈ p̂]

    # Add the auxiliary variables for the piecewise linear reformulation
    Wₚ = @variable(m, [𝒯])
    λ = @variable(m, [𝒯, 1:n_p], lower_bound = 0, upper_bound = 1)
    # Constraints for the equality at given points
    @constraint(m, [t ∈ 𝒯],
        m[:stor_level][n, t] ==
            sum(λ[t, i_p] * (p̂[i_p] - pₘᵢₙ) / (pₘₐₓ - pₘᵢₙ) for i_p ∈ 1:n_p) *
            capacity(level(n), t)
    )
    @constraint(m, [t ∈ 𝒯], Wₚ[t] == sum(λ[t, i_p] * Ŵ[i_p] for i_p ∈ 1:n_p))
    # Constraints for λ variables to enforce SOS2 constraints
    @constraints(m, begin
        [t ∈ 𝒯], sum(λ[t, :]) == 1
        [t ∈ 𝒯], λ[t, :] in SOS2()
    end)

    # Constraint for the electricity requirement for the compression
    @constraint(m, [t ∈ 𝒯],
        m[:flow_in][n, t, p_el] ==
            m[:flow_in][n, t, p_stor] * Wₚ[t]
    )

    # Constraint for the hydrogen flow into the storage node
    @constraint(m, [t ∈ 𝒯],
        m[:flow_in][n, t, p_stor] == m[:stor_charge_use][n, t]
    )
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
