"""
    constraints_usage(m, n::AbstractElectrolyzer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the usage constraints for an AbstractElectrolyzer. These constraints
calculate the usage of the electrolyzer up to each time step for both the lifetime and the
degradation calculations.
"""
function constraints_usage(m, n::AbstractElectrolyzer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    # Call the auxiliary function for calculating the linear reformulation of the
    # multiplication of a binary and continuous variable
    prev_usage = constraints_usage_aux(m, n, 𝒯ᴵⁿᵛ, modeltype)

    # Mass/energy balance constraints for stored energy carrier.
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        # Calculation of hte usage within a strategic period
        @constraint(m,
            m[:elect_usage_sp][n, t_inv] * 1000 ==
                sum(m[:elect_on_b][n, t] * scale_op_sp(t_inv, t) for t ∈ t_inv)
        )

        # Creation of the iterator and call of the iterator function -
        # The representative period is initiated with the current investment period to allow
        # dispatching on it.
        prev_pers = PreviousPeriods(t_inv_prev, nothing, nothing);
        elec_pers = ElecPeriods(𝒯ᴵⁿᵛ, t_inv, nothing, true)
        ts = t_inv.operational
        constraints_usage_iterate(m, n, prev_pers, elec_pers, prev_usage, t_inv, ts, modeltype)
    end
end

"""
    constraints_usage_aux(m, n::AbstractElectrolyzer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Create the auxiliary variable for calculating the previous usage of an electrolyzer node.
"""
function constraints_usage_aux(m, n::AbstractElectrolyzer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    # Definition of the auxiliary variable for the linear reformulation of the element-wise
    # product of `:elect_usage_sp[n, t_inv_pre]` and `:elect_usage_mult_sp_b[n, t_inv, t_inv_pre]`.
    # This reformulation requires the introduction of both a `lower_bound` and a
    # `upper_bound` of the variable `:elect_usage_sp` given through a value of `0` and
    # `stack_lifetime(n)`.
    return linear_reformulation(m,
        𝒯ᴵⁿᵛ,
        𝒯ᴵⁿᵛ,
        m[:elect_usage_mult_sp_b][n, :, :],
        m[:elect_usage_sp][n, :],
        FixedProfile(0),
        FixedProfile(stack_lifetime(n)),
    )
end

"""
    constraints_usage_iterate(
        m,
        n::AbstractElectrolyzer,
        prev_pers::PreviousPeriods,
        elec_pers::ElecPeriods,
        prev_usage,
        per,
        ts::RepresentativePeriods,
        modeltype::EnergyModel,
    )

Iterate through the individual time structures of a `AbstractElectrolyzer` node.

In the case of `RepresentativePeriods`, additional constraints are calculated for the usage
of the electrolyzer in representative periods through introducing the variable
`elect_usage_rp[𝒩ᴱᴸ, 𝒯ʳᵖ]`.
 """
function constraints_usage_iterate(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods,
    elec_pers::ElecPeriods,
    prev_usage,
    per,
    _::RepresentativePeriods,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(per)
    last_rp = last(𝒯ʳᵖ)

    # Constraint for the total usage in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:elect_usage_rp][n, t_rp] * 1000 ==
            sum(m[:elect_on_b][n, t] * scale_op_sp(per, t) for t ∈ t_rp)
    )

    # Iterate through the operational structure
    for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ)
        prev_pers = PreviousPeriods(EMB.strat_per(prev_pers), t_rp_prev, EMB.op_per(prev_pers));
        elec_pers.last = t_rp == last_rp
        ts = t_rp.operational.operational
        constraints_usage_iterate(m, n, prev_pers, elec_pers, prev_usage, t_rp, ts, modeltype)
    end
end
"""
In the case of `OperationalScenarios`, we purely iterate through the individual time
structures.
"""
function constraints_usage_iterate(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods,
    elec_pers::ElecPeriods,
    prev_usage,
    per,
    _::OperationalScenarios,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ˢᶜ = opscenarios(per)

    # Iterate through the operational structure
    for t_scp ∈ 𝒯ˢᶜ
        ts = t_scp.operational.operational
        constraints_usage_iterate(m, n, prev_pers, elec_pers, prev_usage, t_scp, ts, modeltype)
    end
end

"""
In the case of `SimpleTimes`, the iterator function is at its lowest level. In this
situation,the previous level is calculated using the function
[`constraints_previous_usage`](@ref). The approach for calculating the
constraints is depending on the types in the parameteric type
[`EMB.PreviousPeriods`](@extref EnergyModelsBase.PreviousPeriods).
"""
function constraints_usage_iterate(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods,
    elec_pers::ElecPeriods,
    prev_usage,
    per,
    _::SimpleTimes,
    modeltype::EnergyModel,
)
    # Constraint for the total usage of the electrolyzer including the current time step.
    # This ensures that the last repetition of the strategic period is appropriately
    # constrained.
    # The conditional statement activates this constraint only for the last representative
    # period, if representative periods are present as stack replacement is only feasible
    # once per strategic period
    if is_last(elec_pers)
        t_inv = strat_per(elec_pers)
        t = last(per)
        @constraint(m,
            stack_lifetime(n) ≥
                (
                    m[:elect_previous_usage][n, t] +
                    m[:elect_usage_sp][n, t_inv]*(duration_strat(t_inv) - 1)
                )
                * 1000 + m[:elect_on_b][n, t] * scale_op_sp(t_inv, t)
        )
    end

    # Iterate through the operational structure
    for (t_prev, t) ∈ withprev(per)
        prev_pers = PreviousPeriods(EMB.strat_per(prev_pers), EMB.rep_per(prev_pers), t_prev);
        elec_pers.op = t

        # Add the constraints for the previous usage
        constraints_previous_usage(m, n, prev_pers, elec_pers, prev_usage, modeltype)
    end
end

"""
    constraints_previous_usage(
        m,
        n::AbstractElectrolyzer,
        prev_pers::PreviousPeriods,
        elec_pers::ElecPeriods,
        t::OperationalPeriod,
        prev_usage,
        modeltype::EnergyModel,
    )

Returns the previous usage of an `AbstractElectrolyzer` node depending on the type of
[`PreviousPeriods`](@ref).

The basic functionality is used in the case when the previous operational period is a
`TimePeriod`, in which case it just returns the previous operational period.
"""
function constraints_previous_usage(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods,
    elec_pers::ElecPeriods,
    prev_usage,
    modeltype::EnergyModel,
)
    t = op_per(elec_pers)
    t_prev = EMB.op_per(prev_pers)
    @constraint(m,
        m[:elect_previous_usage][n, t] ==
            m[:elect_previous_usage][n, t_prev] +
            duration(t_prev) * m[:elect_on_b][n, t_prev] / 1000
    )
end
"""
When the previous operational, representative, and strategic periods are `Nothing`, the
# variable `elect_previous_usage` is fixed to a value of 0.
"""
function constraints_previous_usage(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods{Nothing, Nothing, Nothing},
    elec_pers::ElecPeriods,
    prev_usage,
    modeltype::EnergyModel,
)
    t = op_per(elec_pers)
    fix(m[:elect_previous_usage][n, t], 0; force=true)
end
"""
When the previous operational and representative periods are `Nothing` while the previous
strategic period is given, then previous usage is given through the sum of the usage in
all previous strategic periods after the stack replacement through the variable
`prev_usage`.
"""
function constraints_previous_usage(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods{<:TS.AbstractStrategicPeriod, Nothing, Nothing},
    elec_pers::ElecPeriods,
    prev_usage,
    modeltype::EnergyModel,
)
    𝒯ᴵⁿᵛ = strat_periods(elec_pers)
    t_inv = strat_per(elec_pers)
    t = op_per(elec_pers)

    @constraint(m,
        m[:elect_previous_usage][n, t] ==
            sum(
                prev_usage[t_inv, t_inv_pre] * duration_strat(t_inv_pre)
                for t_inv_pre ∈ 𝒯ᴵⁿᵛ if isless(t_inv_pre, t_inv)
            )
    )
end
"""
When the previous operational period is `Nothing` and the previous representative period an
`AbstractRepresentativePeriod` then the time structure *does* include `RepresentativePeriods`.

The constraint then sums up the values from the previous representative period.
"""
function constraints_previous_usage(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods{<:EMB.NothingPeriod, <:TS.AbstractRepresentativePeriod, Nothing},
    elec_pers::ElecPeriods,
    prev_usage,
    modeltype::EnergyModel,
)
    t_rp_prev = rep_per(prev_pers)
    t = op_per(elec_pers)
    @constraint(m,
        m[:elect_previous_usage][n, t] ==
            m[:elect_previous_usage][n, first(t_rp_prev)] +
            m[:elect_usage_rp][n, t_rp_prev]
    )
end
