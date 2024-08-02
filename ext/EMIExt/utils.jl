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
    mult_sp_aux_b = m[:elect_mult_sp_aux_b][n,:,:,:]

    # Fixing the value to 0 if it is not possible to add capacity beforehand
    cap_bool = true
    tmp_max_add = EMI.max_add(EMI.investment_data(n, :cap))
    for t_inv ∈ 𝒯ᴵⁿᵛ
        if cap_bool &&
            (
                (EMI.has_investment(n) && tmp_max_add[t_inv] == 0) ||
                (!EMI.has_investment(n) && capacity(n, t_inv) == 0)
            )
            JuMP.fix(m[:elect_stack_replacement_sp_b][n, t_inv], 0)
            set_start_value(m[:elect_stack_replacement_sp_b][n, t_inv], 0)
            for t ∈ t_inv
                JuMP.fix(m[:elect_on_b][n, t], 0)
                set_start_value(m[:elect_on_b][n, t], 0)
            end
        else
            if isfirst(t_inv)
                set_start_value(m[:elect_stack_replacement_sp_b][n, t_inv], 0)
            else
                set_start_value(m[:elect_stack_replacement_sp_b][n, t_inv], 1)
            end
            for t ∈ t_inv
                set_start_value(m[:elect_on_b][n, t], 1)
            end
            cap_bool = false
        end
    end

    # Set starting values with stack replacement multipliers in each strategic period
    cap_bool = true
    for t_inv ∈ 𝒯ᴵⁿᵛ, t_inv_pre ∈ 𝒯ᴵⁿᵛ
        if cap_bool &&
            (
                (EMI.has_investment(n) && tmp_max_add[t_inv] == 0) ||
                (!EMI.has_investment(n) && capacity(n, t_inv) == 0)
            )
            set_start_value(m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre], 1)
        elseif isless(t_inv_pre, t_inv)
            cap_bool = false
            set_start_value(m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre], 0)
        else
            cap_bool = false
            set_start_value(m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre], 1)
        end
    end
    cap_bool = true
    for t_inv ∈ 𝒯ᴵⁿᵛ, t_inv_pre ∈ 𝒯ᴵⁿᵛ, t_inv_post ∈ 𝒯ᴵⁿᵛ
        if cap_bool &&
            (
                (EMI.has_investment(n) && tmp_max_add[t_inv] == 0) ||
                (!EMI.has_investment(n) && capacity(n, t_inv) == 0)
            )
            set_start_value(mult_sp_aux_b[t_inv, t_inv_post, t_inv_pre], 1)
        elseif isless(t_inv_pre, t_inv) && t_inv_post.sp ≥ t_inv.sp
            set_start_value(mult_sp_aux_b[t_inv, t_inv_post, t_inv_pre], 0)
            cap_bool = false
        else
            set_start_value(mult_sp_aux_b[t_inv, t_inv_post, t_inv_pre], 1)
            cap_bool = false
        end
    end
end

function ramp_disjunct(m, n::Reformer, ref_pers::EMH.RefPeriods, modeltype::AbstractInvestmentModel)
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
