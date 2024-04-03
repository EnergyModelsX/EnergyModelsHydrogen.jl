"""
    multiplication_variables(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

Calculating the multiplication variables of the installed capacity (expressed through
`cap_inst[n, t]` and `cap_current[n, t_inv]`) and the binary variables for an operating
electrolyser in an operational period `t` (`elect_on_b[n, t]`) and a stack replacement in a
strategic period `t_inv` (`elect_stack_replacement_sp_b[n, t_inv]`).

!!! note
    If the electrolysis node does not have investments, it reuses the default function
    to avoid increasing the number of variables in the model.

# Returns
- **`product_on[t]`**: Multiplication of `cap_inst[n, t]` and `elect_on_b[n, t]`.
- **`stack_replace[t_inv]`**: Multiplication of `operational[n, t_inv]` and
    `elect_stack_replacement_sp_b[n, t_inv]`.
"""
function EMH.multiplication_variables(m, n::EMH.AbstractElectrolyzer, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    if EMI.has_investment(n)

        # Calculate linear reformulation of the multiplication of `cap_inst * elect_on_b`.
        # This is achieved through the introduction of an auxiliary variable
        #   `product_on` = `cap_inst * elect_on_b`
        cap_upper_bound = EMI.max_installed(n)
        cap_lower_bound = FixedProfile(0)
        product_on = EMH.linear_reformulation(
            m,
            𝒯,
            m[:elect_on_b][n, :],
            m[:cap_inst][n, :],
            cap_lower_bound,
            cap_upper_bound,
        )

        # Calculate linear reformulation of the multiplication of
        # `:elect_stack_replacement_sp_b * :cap_current`.
        # This is achieved through the introduction of an auxiliary variable
        #   `stack_replace` = `elect_stack_replacement_sp_b * cap_current`
        stack_replace = EMH.linear_reformulation(
            m,
            𝒯ᴵⁿᵛ,
            m[:elect_stack_replacement_sp_b][n, :],
            m[:cap_current][n, :],
            cap_lower_bound,
            cap_upper_bound,
        )

    else
        # Calculation of the multiplication with the installed capacity of the node
        product_on = @expression(m, [t ∈ 𝒯], capacity(n, t) * m[:elect_on_b][n, t])
        stack_replace = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
            capacity(n, t_inv) * m[:elect_stack_replacement_sp_b][n, t_inv]
        )
    end

    return  product_on, stack_replace
end

"""
    fix_elect_on_b(m, n::EMH.AbstractElectrolyzer, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

Fixing `elect_on_b` to 0 i if it is not possible to add any capacity in the strategic
periods up to the current.
"""
function fix_elect_on_b(m, n::EMH.AbstractElectrolyzer, 𝒯, 𝒫, modeltype::AbstractInvestmentModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    mult_sp_aux_b = m[:elect_mult_sp_aux_b][n,:,:,:]

    # Fixing the value to 0 if it is not possible to add capacity beforehand
    cap_bool = true
    for t_inv ∈ 𝒯ᴵⁿᵛ
        if EMI.max_add(n, t_inv) == 0 && cap_bool
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
        if EMI.max_add(n, t_inv) == 0 && cap_bool
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
        if EMI.max_add(n, t_inv) == 0 && cap_bool
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
