"""
    constraints_usage(m, n::AbstractElectrolyzer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the usage constraints for an AbstractElectrolyzer. These constraints
calculate the usage of the electrolyzer up to each time step for both the lifetime and the
degradation calculations.
"""
function constraints_usage(m, n::AbstractElectrolyzer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    # Mass/energy balance constraints for stored energy carrier.
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        # Calculation of hte usage within a strategic period
        @constraint(m,
            m[:elect_use_sp][n, t_inv] * 1000 ==
                sum(m[:elect_on_b][n, t] * scale_op_sp(t_inv, t) for t ∈ t_inv)
        )

        prev_pers = PreviousPeriods(t_inv_prev, nothing, nothing);
        elec_pers = ElecPeriods(𝒯ᴵⁿᵛ, t_inv, nothing, true)

        # Calculate the constraints for the usage up to the current strategic period
        constraints_usage_sp(m, n, prev_pers, t_inv, modeltype)

        # Creation of the iterator and call of the iterator function -
        # The representative period is initiated with the current investment period to allow
        # dispatching on it.
        ts = t_inv.operational
        constraints_usage_iterate(m, n, prev_pers, elec_pers, t_inv, ts, modeltype)
    end
end
"""
    constraints_usage_sp(
        m,
        n::AbstractElectrolyzer,
        prev_pers::PreviousPeriods,
        t_inv::TS.AbstractStrategicPeriod,
        modeltype::EnergyModel,
    )

Function for creating the constraints on the previous usage of an [`AbstractElectrolyzer`](@ref)
before the beginning of a strategic period.

In the case of the first strategic period, it fixes the variable `elect_prev_use_sp` to 0.
In all subsequent strategic periods, the previous usage is calculated.
"""
function constraints_usage_sp(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods{Nothing, Nothing, Nothing},
    t_inv::TS.AbstractStrategicPeriod,
    modeltype::EnergyModel,
)

    JuMP.fix(m[:elect_prev_use_sp][n, t_inv], 0; force=true)
end
function constraints_usage_sp(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods{<:TS.AbstractStrategicPeriod, Nothing, Nothing},
    t_inv::TS.AbstractStrategicPeriod,
    modeltype::EnergyModel,
)
    t_inv_prev = EMB.strat_per(prev_pers)

    # Calculate the expression if no stack replacement is taking place
    aux_var =  @expression(m,
        # Initial usage in previous sp
        m[:elect_prev_use_sp][n, t_inv_prev] +
        # Increase in previous representative period
        m[:elect_use_sp][n, t_inv_prev] * duration_strat(t_inv_prev)
    )
    # Define the upper bound
    ub = capacity_max(n, t_inv, modeltype)

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable.
    @constraints(m, begin
        m[:elect_prev_use_sp][n, t_inv] ≥ 0
        m[:elect_prev_use_sp][n, t_inv] ≥ ub * ((1 - m[:elect_stack_replace_sp_b][n, t_inv]) - 1) + aux_var
        m[:elect_prev_use_sp][n, t_inv] ≤ ub * (1 - m[:elect_stack_replace_sp_b][n, t_inv])
        m[:elect_prev_use_sp][n, t_inv] ≤ aux_var
    end)
end

"""
    constraints_usage_iterate(
        m,
        n::AbstractElectrolyzer,
        prev_pers::PreviousPeriods,
        elec_pers::ElecPeriods,
        per,
        ts::RepresentativePeriods,
        modeltype::EnergyModel,
    )

Iterate through the individual time structures of a `AbstractElectrolyzer` node.

In the case of `RepresentativePeriods`, additional constraints are calculated for the usage
of the electrolyzer in representative periods through introducing the variable
`elect_use_rp[𝒩ᴱᴸ, 𝒯ʳᵖ]`.
 """
function constraints_usage_iterate(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods,
    elec_pers::ElecPeriods,
    per,
    _::RepresentativePeriods,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(per)
    last_rp = last(𝒯ʳᵖ)

    # Constraint for the total usage in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:elect_use_rp][n, t_rp] * 1000 ==
            sum(m[:elect_on_b][n, t] * scale_op_sp(per, t) for t ∈ t_rp)
    )

    # Iterate through the operational structure
    for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ)
        prev_pers = PreviousPeriods(EMB.strat_per(prev_pers), t_rp_prev, EMB.op_per(prev_pers));
        elec_pers.last = t_rp == last_rp
        ts = t_rp.operational.operational
        constraints_usage_iterate(m, n, prev_pers, elec_pers, t_rp, ts, modeltype)
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
    per,
    _::OperationalScenarios,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ˢᶜ = opscenarios(per)

    # Iterate through the operational structure
    for t_scp ∈ 𝒯ˢᶜ
        ts = t_scp.operational.operational
        constraints_usage_iterate(m, n, prev_pers, elec_pers, t_scp, ts, modeltype)
    end
end

"""
In the case of `SimpleTimes`, the iterator function is at its lowest level. In this
situation,the previous level is calculated using the function
[`constraints_previous_usage`](@ref). The approach for calculating the
constraints is depending on the types in the parameteric type
[`PreviousPeriods`](@extref EnergyModelsBase.PreviousPeriods).
"""
function constraints_usage_iterate(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods,
    elec_pers::ElecPeriods,
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
                    m[:elect_prev_use][n, t] +
                    m[:elect_use_sp][n, t_inv]*(duration_strat(t_inv) - 1)
                )
                * 1000 + m[:elect_on_b][n, t] * scale_op_sp(t_inv, t)
        )
    end

    # Iterate through the operational structure
    for (t_prev, t) ∈ withprev(per)
        prev_pers = PreviousPeriods(EMB.strat_per(prev_pers), EMB.rep_per(prev_pers), t_prev);
        elec_pers.op = t

        # Add the constraints for the previous usage
        constraints_previous_usage(m, n, prev_pers, elec_pers, modeltype)
    end
end

"""
    constraints_previous_usage(
        m,
        n::AbstractElectrolyzer,
        prev_pers::PreviousPeriods,
        elec_pers::ElecPeriods,
        t::OperationalPeriod,
        modeltype::EnergyModel,
    )

Returns the previous usage of an `AbstractElectrolyzer` node depending on the type of
[`PreviousPeriods`](@extref EnergyModelsBase.PreviousPeriods).

The basic functionality is used in the case when the previous operational period is a
`TimePeriod`, in which case it just returns the previous operational period.
"""
function constraints_previous_usage(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods,
    elec_pers::ElecPeriods,
    modeltype::EnergyModel,
)
    t = op_per(elec_pers)
    t_prev = EMB.op_per(prev_pers)
    @constraint(m,
        m[:elect_prev_use][n, t] ==
            m[:elect_prev_use][n, t_prev] +
            duration(t_prev) * m[:elect_on_b][n, t_prev] / 1000
    )
end
"""
When the previous operational, representative, and strategic periods are `Nothing`, the
# variable `elect_prev_use` is fixed to a value of 0.
"""
function constraints_previous_usage(
    m,
    n::AbstractElectrolyzer,
    prev_pers::PreviousPeriods{Nothing, Nothing, Nothing},
    elec_pers::ElecPeriods,
    modeltype::EnergyModel,
)
    t = op_per(elec_pers)
    fix(m[:elect_prev_use][n, t], 0; force=true)
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
    modeltype::EnergyModel,
)
    t_inv = strat_per(elec_pers)
    t = op_per(elec_pers)

    @constraint(m, m[:elect_prev_use][n, t] == m[:elect_prev_use_sp][n, t_inv])
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
    modeltype::EnergyModel,
)
    t_rp_prev = rep_per(prev_pers)
    t = op_per(elec_pers)
    @constraint(m,
        m[:elect_prev_use][n, t] ==
            m[:elect_prev_use][n, first(t_rp_prev)] +
            m[:elect_use_rp][n, t_rp_prev]
    )
end
