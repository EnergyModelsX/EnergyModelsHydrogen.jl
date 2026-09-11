function EMH.multiplication_variables(
    m,
    n::EMH.AbstractHydrogenNetworkNode,
    𝒯,
    var_b,
    modeltype::AbstractInvestmentModel
)
    if EMI.has_investment(n)
        if isa(𝒯, TwoLevel)
            var_cont = @expression(m, [t ∈ 𝒯], m[:cap_inst][n, t])
        else
            var_cont = @expression(m, [t ∈ 𝒯], m[:cap_current][n, t])
        end

        # Calculate linear reformulation of the multiplication of `cap_inst * var_b`.
        # This is achieved through the introduction of an auxiliary variable
        #   `prod` = `cap_inst * var_b`
        cap_upper_bound = EMI.max_installed(EMI.investment_data(n, :cap))
        cap_lower_bound = FixedProfile(0)
        prod = EMH.linear_reformulation(
            m,
            𝒯,
            var_b,
            var_cont,
            cap_lower_bound,
            cap_upper_bound,
        )

    else
        # Calculation of the multiplication with the installed capacity of the node
        prod = @expression(m, [t ∈ 𝒯], capacity(n, t) * var_b[t])
    end

    return prod
end

function EMH.fix_elect_on_b(m, n::EMH.AbstractElectrolyzer, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)
    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Fixing the value to 0 if it is not possible to add capacity beforehand
    cap_bool = true
    if EMI.has_investment(n)
        tmp_max_add = EMI.max_add(EMI.investment_data(n, :cap))
        for t_inv ∈ 𝒯ᴵⁿᵛ
            if cap_bool &&
                (
                    (EMI.has_investment(n) && tmp_max_add[t_inv] == 0) ||
                    (!EMI.has_investment(n) && capacity(n, t_inv) == 0)
                )
                JuMP.fix(m[:elect_stack_replace_b][n, t_inv], 0)
                set_start_value(m[:elect_stack_replace_b][n, t_inv], 0)
                for t ∈ t_inv
                    JuMP.fix(m[:elect_on_b][n, t], 0)
                    set_start_value(m[:elect_on_b][n, t], 0)
                end
            else
                if isfirst(t_inv)
                    set_start_value(m[:elect_stack_replace_b][n, t_inv], 0)
                else
                    set_start_value(m[:elect_stack_replace_b][n, t_inv], 1)
                end
                for t ∈ t_inv
                    set_start_value(m[:elect_on_b][n, t], 1)
                end
                cap_bool = false
            end
        end
    else
        for t_inv ∈ 𝒯ᴵⁿᵛ
            if capacity(n, t_inv) == 0 && cap_bool
                JuMP.fix(m[:elect_stack_replace_b][n, t_inv], 0)
                set_start_value(m[:elect_stack_replace_b][n, t_inv], 0)
                for t ∈ t_inv
                    JuMP.fix(m[:elect_on_b][n, t], 0)
                    set_start_value(m[:elect_on_b][n, t], 0)
                end
            else
                cap_bool = false
                if isfirst(t_inv)
                    set_start_value(m[:elect_stack_replace_b][n, t_inv], 0)
                else
                    set_start_value(m[:elect_stack_replace_b][n, t_inv], 1)
                end
                for t ∈ t_inv
                    set_start_value(m[:elect_on_b][n, t], 1)
                end
            end
        end
    end
end

function EMH.capacity_max(n::EMH.AbstractElectrolyzer, t_inv, modeltype::AbstractInvestmentModel)
    cap = capacity(n, t_inv)
    if EMI.has_investment(n)
        cap = EMI.max_installed(EMI.investment_data(n, :cap), t_inv)
    end
    return cap
end

function EMH.ramp_disjunct(m, n::Reformer, ref_pers::EMH.RefPeriods, modeltype::AbstractInvestmentModel)
    # Extract the values from the types
    t_prev = EMH.prev_op(ref_pers)
    t = EMH.current_op(ref_pers)
    if EMI.has_investment(n)
        cap_val = EMI.max_installed(EMI.investment_data(n, :cap), t)
    else
        cap_val = capacity(n, t)
    end
    return @expression(m, cap_val * (2 - m[:ref_on_b][n, t] - m[:ref_on_b][n, t_prev]))
end

"""
    EMH.cap_deg_state_product(m, n, 𝒯ᴵⁿᵛ, j, modeltype)

Investment-model override. When the node has investment data, linearizes
`cap_inst[n, t_inv] * elect_deg_state_b[n, t_inv, j]` via McCormick envelopes.
Falls back to the scalar product when no investment data is present.
"""
function EMH.cap_deg_state_product(
    m,
    n::EMH.StrategicDegradationElectrolyzer,
    𝒯ᴵⁿᵛ,
    j,
    ::AbstractInvestmentModel,
)
    if EMI.has_investment(n)
        cap_upper_bound = EMI.max_installed(EMI.investment_data(n, :cap))
        cap_lower_bound = FixedProfile(0)
        return EMH.linear_reformulation(
            m,
            𝒯ᴵⁿᵛ,
            (@expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:elect_deg_state_b][n, t_inv, j])),
            (@expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ], m[:cap_inst][n, first(t_inv)])),
            cap_lower_bound,
            cap_upper_bound,
        )
    else
        return @expression(
            m,
            [t_inv ∈ 𝒯ᴵⁿᵛ],
            capacity(n, t_inv) * m[:elect_deg_state_b][n, t_inv, j],
        )
    end
end
