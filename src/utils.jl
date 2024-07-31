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
and the continuous variable `var_continuous[𝒯] ∈ [ub, lb]`.

It returns the product `var_aux[𝒯]` with

``var\\_aux[t] = var\\_binary[t] \\times var\\_continuous[t]``.

!!! note
    The bounds `lb` and `ub` must have the ability to access their fields using the iterator
    of `𝒯`, that is if `𝒯` corresponds to the strategic periods, it is not possible to
    provide an `OperationalProfile` or `RepresentativeProfile`.
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
continuous variable `var_continuous[𝒯ᵇ] ∈ [ub, lb]`.

It returns the product `var_aux[𝒯ᵃ, 𝒯ᵇ]` with

``var\\_aux[t_a, t_b] = var\\_binary[t_a, t_b] \\times var\\_continuous[t_b]``.


!!! note
    𝒯ᵃ and 𝒯ᵇ must be of the same type, that is either, *e.g.* a `TwoLevel`, `StratPeriods`,
    `StratReprPeriods`, or comparable.
    This is enforced through the parametric type `T`.

    The bounds `lb` and `ub` must have the ability to access their fields using the iterator
    of `𝒯ᵃ`, that is if `𝒯ᵃ` corresponds to the strategic periods, it is not possible to
    provide an `OperationalProfile` or `RepresentativeProfile`.
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
    multiplication_variables(
        m,
        n::AbstractHydrogenNetworkNode,
        𝒯,
        var_b,
        modeltype::EnergyModel
    )

Function for calculating the muliplication of the capacity of an `AbstractHydrogenNetworkNode`
and a binary variable.

    modeltype::EnergyModel

Multiplication of the installed capacity (expressed through `capacity(n, t)`) and a binary
variable `var_b` in a period `t` (_e.g._, `elect_on_b[n, t]`).

!!! note
    The time structure `𝒯` can be either a `TwoLevel` or `StrategicPeriods`. It is however
    necessary, that the variable `var_b` is indexed over the iterators of `𝒯`.

## Returns
- **`prod[t]`**: Multiplication of `capacity(n, t)` and `var_b[n, t]`.


    modeltype::AbstractInvestmentModel

When the modeltype is an `AbstractInvestmentModel`, then the function applies a linear
reformulation of the binary-continuous multiplication based on the McCormick relaxation and
the function [`linear_reformulation`](@ref).

!!! note
    If the `AbstractHydrogenNetworkNode` node does not have investments, it reuses the
    default function to avoid increasing the number of variables in the model.

## Returns
- **`prod[t]`**: Multiplication of `cap_inst[n, t]` and `var_b[t]` or alternatively
  `cap_current[n, t]` and `var_b[t]`, if the TimeStructure is a `StrategicPeriods` and
  the node `n` has investments.
"""
function multiplication_variables(
    m,
    n::AbstractHydrogenNetworkNode,
    𝒯,
    var_b,
    modeltype::EnergyModel
)

    # Calculation of the multiplication with the installed capacity of the node
    prod = @expression(m, [t ∈ 𝒯], capacity(n, t) * var_b[t])
    return  prod
end

"""
    fix_elect_on_b(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

Fixes the variable `:elect_on_b`  in operational periods without capacity and the variable
`:elect_stack_replacement_sp_b` in strategic periods without capacity to 0 to simplify the
optimziation problem.

Provides start values to the variables in all other periods as well as start values for
the variable `:elect_usage_mult_sp_b`

    modeltype::EnergyModel

Base the approach on the capacity extracted through the function
[`EMB.capacity`](@extref EnergyModelsBase.capacity).

    modeltype::AbstractInvestmentModel

Base the approach on the maximum added capacity extracted through the function
`EMI.max_add`.
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
