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
    var_aux = @variable(m, [t ∈ 𝒯], lower_bound = minimum([0, lb[t]]), upper_bound = ub[t])

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

Linear reformulation of the multiplication of the binary variable `var_binary[𝒯ᵃ, 𝒯ᵇ]` and the
continuous variable `var_continuous[𝒯ᵇ] ∈ [ub, lb]`.

It returns the product `var_aux[𝒯ᵃ, 𝒯ᵇ]` with

``var\\_aux[t_a, t_b] = var\\_binary[t_a, t_b] \\times var\\_continuous[t_b]``.


!!! note
    𝒯ᵃ and 𝒯ᵇ must be of the same type, that is either, *e.g.* a `TwoLevel`, `AbstractStratPers`,
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
    var_aux = @variable(m, [𝒯ᵃ, t_b ∈ 𝒯ᵇ],
        lower_bound = minimum([0, lb[t_b]]),
        upper_bound = ub[t_b]
    )

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
            var_aux[t_a, t_b] ≤ lb[t_b] * (var_binary[t_a, t_b]-1) + var_continuous[t_b]
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
`:elect_stack_replace_sp_b` in strategic periods without capacity to 0 to simplify the
optimziation problem.

Provides start values to the variables in all other periods as well as start values for
the variable `:elect_usage_mult_sp_b`

    modeltype::EnergyModel


The function utilizes the the value of the field `cap` of the node.

    modeltype::AbstractInvestmentModel


When the node has investment data, the function utilizes the the value of the field
`EMI.max_add` of the `AbstractInvData`. Otherwise, it uses as well the field `cap` of the node.
"""
function fix_elect_on_b(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Fixing the value to 0 if no capacity is installed
    cap_bool = true
    for t_inv ∈ 𝒯ᴵⁿᵛ
        if capacity(n, t_inv) == 0 && cap_bool
            JuMP.fix(m[:elect_stack_replace_sp_b][n, t_inv], 0)
            set_start_value(m[:elect_stack_replace_sp_b][n, t_inv], 0)
            for t ∈ t_inv
                JuMP.fix(m[:elect_on_b][n, t], 0)
                set_start_value(m[:elect_on_b][n, t], 0)
            end
        else
            cap_bool = false
            if isfirst(t_inv)
                set_start_value(m[:elect_stack_replace_sp_b][n, t_inv], 0)
            else
                set_start_value(m[:elect_stack_replace_sp_b][n, t_inv], 1)
            end
            for t ∈ t_inv
                set_start_value(m[:elect_on_b][n, t], 1)
            end
        end
    end
end


"""
    capacity_max(n::AbstractElectrolyzer, t_inv, modeltype::EnergyModel)

Function for calculating the maximum capacity.

    modeltype::EnergyModel

When the modeltype is an `EnergyModel`, it returns the capacity of the
`AbstractElectrolyzer`.

    modeltype::AbstractInvestmentModel

When the modeltype is an `AbstractInvestmentModel`, it returns the maximum installed capacity.

!!! note
    If the [`AbstractElectrolyzer`](@ref) node does not have investments, it reuses the
    default function.
"""
capacity_max(n::AbstractElectrolyzer, t_inv, modeltype::EnergyModel) =
    capacity(n, t_inv)


"""
    ramp_disjunct(m, n::Reformer, ref_pers::RefPeriods, modeltype::EnergyModel)

Function for calculating the disjunction contribution for the ramping constraints of a reformer.


    modeltype::EnergyModel

The function utilizes the the value of the field `cap` of the node for achieving tight
bounds for the disjunction.

    modeltype::AbstractInvestmentModel

When the node has investment data, the function utilizes the the value of the field
`EMI.max_installed` of the `AbstractInvData` for achieving tight bounds for the disjunction.
Otherwise, it uses as well the field `cap` of the node.
"""
function ramp_disjunct(m, n::Reformer, ref_pers::RefPeriods, modeltype::EnergyModel)
    # Extract the values from the types
    t_prev = prev_op(ref_pers)
    t = current_op(ref_pers)
    return @expression(m, capacity(n, t) * (2 - m[:ref_on_b][n, t] - m[:ref_on_b][n, t_prev]))
end

"""
    compression_energy(p₁, p₂; T₁=298.15, κ=1.41, η=0.75)

Returns the required compression energy for a compression from pressure `p₁` to `p₂`.
The compression energy is in principle based on isentropic compression.
The unit of the compression energy is J/mol.

# Arguments
- `p₁` is the inlet pressure to the compressor. The unit for pressure is not relevant.
- `p₂` is the outlet pressure from the compressor. The unit for pressure is not relevant,
  but it **must** be the same unit as `p₁`.

# Keyword arguments
- `T₁` is the inlet temperature to the compressor.
- `κ` is the ratio of specific heats. Using a value of [1, κ] would correspond hence to
  polytropic compression.
- `η` is the efficiency of the compressor.
"""
function compression_energy(p₁, p₂; T₁=298.15, κ=1.41, η = 0.75)
    # Physical input parameters
    R = 8.31446261815324

    # Calculation of the energy requirement for compression
    return (κ * R * T₁) / (κ-1) * ((p₂/p₁)^((κ-1)/κ)-1) / η
end

"""
    energy_curve(
        p::Float64,
        pᵢₙ::Float64,
        PR::Float64,
        n_comp::Int,
        M::Float64,
        LHV::Float64
    )

Returns the relative compression energy requirement for a multi-stage compression train.

# Arguments
- `p::Float64` is the delivery pressure.
- `pᵢₙ::Float64` is the inlet pressure.
- `PR::Float64` is the compression rate of each compressor in the train.
- `n_comp::Int` is the number of compressors in the train.
- `M::Float64` is molecular mass of the compressed gas.
- `LHV::Float64` is the mass lower heating value of the compressed gas.

# Keyword arguments
- `T₁` is the inlet temperature to the compressor.
- `κ` is the ratio of specific heats. Using a value of [1, κ] would correspond hence to
  polytropic compression.
- `η` is the efficiency of the compressor.

!!! warning "Units"
    The units have to be consistent. This implies that both `p` and `pᵢₙ` require to have
    the same unit. The molecular mass should be provided in g/mol while the lower heating
    value should be given in MJ/kg.
"""
function energy_curve(
    p::Float64,
    pᵢₙ::Float64,
    PR::Float64,
    n_comp::Int,
    M::Float64,
    LHV::Float64;
    T₁::Float64 = 298.15,
    κ::Float64 = 1.41,
    η::Float64 = 0.7,
)
    if p > pᵢₙ
        p₁ = [pᵢₙ*PR^i for i ∈ 0:n_comp-1 if p > pᵢₙ*PR^i]
        p₂ = [pᵢₙ*PR^i for i ∈ 1:n_comp if p > pᵢₙ*PR^i]
        push!(p₂, p)
        W = (
            sum(compression_energy(p_1, p_2; T₁, κ, η) for (p_1, p_2) ∈ zip(p₁, p₂)) /
            (M * LHV * 1000)
        )
    else
        W = 0
    end
    return W
end
