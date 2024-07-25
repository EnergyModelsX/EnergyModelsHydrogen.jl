"""
    linear_reformulation(
        m,
        𝒯,
        var_binary,
        var_continuous,
        lb::TimeProfile,
        ub::TimeProfile,
    )

Linear reformulation of the element-wise multiplication of the binary variable `var_binary[𝒯]`
and the continuous variable `var_continuous[𝒯]`.

It returns the product `var_aux[𝒯]`.

!!! note
    The bounds `lb` and `ub` must have the ability to access their fields using the iterator
    of `𝒯`, that is if `𝒯` corresponds to the strategic periods, it is not possible to
    provide an `OperationalProfile` or `RepresentativeProfile`.

# Arguments:
- **`m`**: JuMP model.
- **`𝒯`**: Time index used for the variables.
- **`var_binary`**: Binary variable for the multiplication, indexed only over `𝒯`.
- **`var_continuous`**: Continuous variable for the multiplication, indexed only over `𝒯`.
- **`lb`::TimeProfile**: Lower bound of the continuous variable.
- **`ub`::TimeProfile**: Upper bound of the continuous variable..
"""
function linear_reformulation(
    m,
    𝒯,
    var_binary,
    var_continuous,
    lb::TimeProfile,
    ub::TimeProfile,
    )

    # Declaration of the auxiliary variable
    var_aux = @variable(m, [𝒯], lower_bound = 0)

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable.
    @constraints(m, begin
        [t ∈ 𝒯], var_aux[t] ≥ lb[t] * var_binary[t]
        [t ∈ 𝒯], var_aux[t] ≥ ub[t] * (var_binary[t]-1) + var_continuous[t]
        [t ∈ 𝒯], var_aux[t] ≤ ub[t] * var_binary[t]
        [t ∈ 𝒯], var_aux[t] ≤ lb[t] * (1-var_binary[t]) + var_continuous[t]
    end)

    return var_aux
end

"""
    linear_reformulation(
        m,
        𝒯ᵃ::T,
        𝒯ᵇ::T,
        var_binary,
        var_continuous,
        lb::TimeProfile,
        ub::TimeProfile,
    ) where {T}

Linear reformulation of the multiplication of the binary variable `var_binary[𝒯ᵃ, 𝒯ᵇ]` and the
continuous variable `var_continuous[𝒯ᵇ]`.

It returns the product `var_aux[𝒯ᵃ, 𝒯ᵇ]`.

!!! note
    𝒯ᵃ and 𝒯ᵇ must be of the same type, that is either, *e.g.* a `TwoLevel` or the strategic
    periods.
    The bounds `lb` and `ub` must have the ability to access their fields using the iterator
    of `𝒯ᵃ`, that is if `𝒯ᵃ` corresponds to the strategic periods, it is not possible to
    provide an `OperationalProfile` or `RepresentativeProfile`.

# Arguments:
- **`m`**: JuMP model.
- **`𝒯ᵃ`**: Time used for the indices of the variables.
- **`𝒯ᵇ`**: Time used for the indices of the variables.
- **`var_binary`**: Binary variable for the multiplication, indexed over `𝒯ᵃ` and `𝒯ᵇ`.
- **`var_continuous`**: Continuous variable for the multiplication, indexed only over `𝒯ᵃ`.
- **`lb`::TimeProfile**: Lower bound of the continuous variable.
- **`ub`::TimeProfile**: Upper bound of the continuous variable..
"""
function linear_reformulation(
    m,
    𝒯ᵃ::T,
    𝒯ᵇ::T,
    var_binary,
    var_continuous,
    lb::TimeProfile,
    ub::TimeProfile,
    ) where {T}

    # Decleration of the auxiliary variable
    var_aux = @variable(m, [𝒯ᵃ, 𝒯ᵇ], lower_bound = 0)

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable.
    @constraints(m, begin
        [t_a ∈ 𝒯ᵃ, t_b ∈ 𝒯ᵇ],
            var_aux[t_a, t_b] ≥ lb[t_b] * var_binary[t_a, t_b]
        [t_a ∈ 𝒯ᵃ, t_b ∈ 𝒯ᵇ],
            var_aux[t_a, t_b] ≥ ub[t_b] * (var_binary[t_a, t_b]-1) + var_continuous[t_b]
        [t_a ∈ 𝒯ᵃ, t_b ∈ 𝒯ᵇ],
            var_aux[t_a, t_b] ≤ ub[t_b] * var_binary[t_a, t_b]
        [t_a ∈ 𝒯ᵃ, t_b ∈ 𝒯ᵇ],
            var_aux[t_a, t_b] ≤ lb[t_b] * (1-var_binary[t_a, t_b]) + var_continuous[t_b]
    end)

    return var_aux
end

"""
    multiplication_variables(m, n::AbstractHydrogenNetworkNode, 𝒯, var_b, modeltype::EnergyModel)

Default option for calculating the multiplication variables of the installed capacity
(expressed through `capacity(n, t)`) and a binary variable `var_b` in an operational period
`t` (_e.g._, `elect_on_b[n, t]`).

!!! note
    The time structure `𝒯` can be either a `TwoLevel` or `StrategicPeriods`. It is however
    necessary, that the variable `var_b` is indexed over the iterators of `𝒯`.

# Returns
- **`prod[t]`**: Multiplication of `capacity(n, t)` and `var_b[n, t]`.
"""
function multiplication_variables(m, n::AbstractHydrogenNetworkNode, 𝒯, var_b, modeltype::EnergyModel)

    # Calculation of the multiplication with the installed capacity of the node
    prod = @expression(m, [t ∈ 𝒯], capacity(n, t) * var_b[t])
    return  prod
end

"""
    fix_elect_on_b(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

Default option for fixing elect_on_b to 0 in the case of no available capacity in a given
strategic periods.
"""
function fix_elect_on_b(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    mult_sp_aux_b = m[:elect_mult_sp_aux_b][n,:,:,:]

    # Fixing the value to 0 if no capacity is installed
    cap_bool = true
    for t_inv ∈ 𝒯ᴵⁿᵛ
        if capacity(n, t_inv) == 0 && cap_bool
            JuMP.fix(m[:elect_stack_replacement_sp_b][n, t_inv], 0)
            set_start_value(m[:elect_stack_replacement_sp_b][n, t_inv], 0)
            for t ∈ t_inv
                JuMP.fix(m[:elect_on_b][n, t], 0)
                set_start_value(m[:elect_on_b][n, t], 0)
            end
        else
            cap_bool = false
            if isfirst(t_inv)
                set_start_value(m[:elect_stack_replacement_sp_b][n, t_inv], 0)
            else
                set_start_value(m[:elect_stack_replacement_sp_b][n, t_inv], 1)
            end
            for t ∈ t_inv
                set_start_value(m[:elect_on_b][n, t], 1)
            end
        end
    end

    # Set starting values with stack replacement multipliers in each strategic period
    cap_bool = true
    for t_inv ∈ 𝒯ᴵⁿᵛ, t_inv_pre ∈ 𝒯ᴵⁿᵛ
        if capacity(n, t_inv) == 0 && cap_bool
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
        if capacity(n, t_inv) == 0 && cap_bool
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
