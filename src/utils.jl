"""
    linear_reformulation(
        m,
        𝒯,
        var_binary,
        var_continuous,
        lb::TimeProfile,
        ub::TimeProfile,
    )

Linear reformulation of the multiplication of the binary variable `var_binary` and the
continuous variable `var_continuous`, indexed over `𝒯`. It returns the product `var_aux` as:
    ``\texttt{var_aux}[t] = \texttt{var_binary}[t] * \texttt{var_continuous}[t]``

The bounds `lb` and `ub` must have the ability to access their fields using the iterator of
`𝒯`, that is if `𝒯` corresponds to the strategic periods, it is not possible to provide an
`OperationalProfile`

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

    # Decleration of the auxiliary variable
    var_aux = @variable(m, [𝒯], lower_bound = 0)

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable.
    @constraints(m, begin
        [t ∈ 𝒯], var_aux[t] ≥ lb[t] * var_binary[t]
        [t ∈ 𝒯], var_aux[t] ≥ ub[t] * (var_binary[t]-1) + var_continuous[t]
        [t ∈ 𝒯], var_aux[t] ≤ ub[t] * var_binary[t]
        [t ∈ 𝒯], var_aux[t] ≤ lb[t] * (var_binary[t]-1) + var_continuous[t]
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

Linear reformulation of the multiplication of the binary variable `var_binary` and the
continuous variable `var_continuous`, indexed over `𝒯`. It returns the product `var_aux` as:
    ``\texttt{var_aux}[t_a, t_b] = \texttt{var_binary}[t_a, t_b] * \texttt{var_continuous}[t_b]``

𝒯ᵃ and 𝒯ᵇ must be of the same type, that is either, *e.g.* a `TwoLevel` or the strategic
periods.
The bounds `lb` and `ub` must have the ability to access their fields using the iterator of
`𝒯`, that is if `𝒯` corresponds to the strategic periods, it is not possible to provide an
`OperationalProfile`

# Arguments:
- **`m`**: JuMP model.
- **`𝒯ᵃ`**: Time used for the indices of the variables.
- **`𝒯ᵇ`**: Time used for the indices of the variables.
- **`var_binary`**: Binary variable for the multiplication, indexed only over `𝒯`.
- **`var_continuous`**: Continuous variable for the multiplication, indexed only over `𝒯`.
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
            var_aux[t_a, t_b] ≥ lb[t_a] * var_binary[t_a, t_b]
        [t_a ∈ 𝒯ᵃ, t_b ∈ 𝒯ᵇ],
            var_aux[t_a, t_b] ≥ ub[t_a] * (var_binary[t_a, t_b]-1) + var_continuous[t_b]
        [t_a ∈ 𝒯ᵃ, t_b ∈ 𝒯ᵇ],
            var_aux[t_a, t_b] ≤ ub[t_a] * var_binary[t_a, t_b]
        [t_a ∈ 𝒯ᵃ, t_b ∈ 𝒯ᵇ],
            var_aux[t_a, t_b] ≤ lb[t_a] * (var_binary[t_a, t_b]-1) + var_continuous[t_b]
    end)

    return var_aux
end

"""
    multiplication_variables(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

Default option for calculating the multiplication variables of the installed capacity
(expressed through `capacity(n, t)`) and the binary variables for an operating electrolyser
in an operational period `t` (`elect_on_b[n, t]`) and a stack replacement in a strategic
period `t_inv` (`elect_stack_replacement_sp_b[n, t_inv]`).

# Returns
- **`product_on[t]`**: Multiplication of `capacity(n, t)` and `elect_on_b[n, t]`.
- **`stack_replace[t_inv]`**: Multiplication of `capacity(n, t_inv)` and
    `elect_stack_replacement_sp_b[n, t_inv]`.
"""
function multiplication_variables(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Calculation of the multiplication with the installed capacity of the node
    product_on = @expression(m, [t ∈ 𝒯], capacity(n, t) * m[:elect_on_b][n, t])
    stack_replace = @expression(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        capacity(n, t_inv) * m[:elect_stack_replacement_sp_b][n, t_inv]
    )

    return  product_on, stack_replace
end
