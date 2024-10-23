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

"""
    constraints_rate_of_change_iterate(
        m,
        n::Reformer,
        per,
        t_last,
        ts,
        modeltype::EnergyModel,
    )

Function for iterating through the time structure for calculating the correct rate of change
constraints of the Reformer `n`.

When the time structure includes `RepresentativePeriods`, period `t_last` is updated with
last operational period within each representative period.
"""
function constraints_rate_of_change_iterate(
    m,
    n::Reformer,
    per,
    _,
    _::RepresentativePeriods,
    modeltype::EnergyModel,
)
    for t_rp ∈ repr_periods(per)
        t_last = last(t_rp)
        ts = t_rp.operational.operational
        constraints_rate_of_change_iterate(m, n, t_rp, t_last, ts, modeltype)
    end
end
"""
When the time structure includes `OperationalScenarios`, period `t_last` is updated with
last operational period within each operational scenario.
"""
function constraints_rate_of_change_iterate(
    m,
    n::Reformer,
    per,
    _,
    _::OperationalScenarios,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ˢᶜ = opscenarios(per)
    for t_scp ∈ 𝒯ˢᶜ
        t_last = last(t_scp)
        ts = t_scp.operational.operational
        constraints_rate_of_change_iterate(m, n, t_scp, t_last, ts, modeltype)
    end
end
function constraints_rate_of_change_iterate(
    m,
    n::Reformer,
    per,
    t_last,
    _::SimpleTimes,
    modeltype::EnergyModel
)
    for (t_prev, t) ∈ withprev(per)
        ref_pers = RefPeriods(t_prev, t, t_last)
        constraints_rate_of_change(m, n, ref_pers, modeltype)
    end
end

"""
    constraints_rate_of_change(
        m,
        n::Reformer,
        ramp_lim::UnionRampUp,
        ref_pers::RefPeriods,
        prod_on,
        modeltype::EnergyModel,
    )

Function for creating the constraints on the maximum postivite rate of change. This
constraint is only active if the `Reformer` is online in both the current and the previous
operational periods, that is:

    m[:ref_on_b][n, t_prev] = m[:ref_on_b][n, t] = 1

The function [`prev_op`](@ref) is used to incorporate the cyclic constraints while the
function [`ramp_disjunct`](@ref) is used to extract the disjuntion contribution to the
constraint depending on the modeltype.
"""
function constraints_rate_of_change(
    m,
    n::Reformer,
    ref_pers::RefPeriods,
    modeltype::EnergyModel,
)
    # Extract the values from the types
    t_prev = prev_op(ref_pers)
    t = current_op(ref_pers)
    bound_disjunct = ramp_disjunct(m, n, ref_pers, modeltype)

    if isa(ramp_limit(n), UnionRampUp) # If we have bounds on positive changes
        @constraint(m,
            m[:cap_use][n, t] - m[:cap_use][n, t_prev] ≤
                m[:cap_inst][n, t] * ramp_up(n, t) * duration(t) + bound_disjunct
        )
    end
    if isa(ramp_limit(n), UnionRampDown) # If we have bounds on negative changes
        @constraint(m,
            m[:cap_use][n, t_prev] - m[:cap_use][n, t] ≤
                m[:cap_inst][n, t] * ramp_down(n, t) * duration(t) + bound_disjunct
        )
    end
end

"""
    constraints_state_seq_iter(
        m,
        n::Reformer,
        per,
        t_last,
        ts,
        modeltype::EnergyModel
    )

Function for iterating through the time structure for calculating the correct cyclic
constraints for the sequencing of the states of the Reformer `n`.

The function automatically deduces the provided time structure and calls the calls the
corresponding functions iteratively.
It eventually calls the function [`constraints_state_seq`](@ref) for imposing the sequencing
constraints on the different states.

When the time structure includes `RepresentativePeriods`, period `t_last` is updated with
last operational period within each representative period.
"""
function constraints_state_seq_iter(
    m,
    n::Reformer,
    per,
    _,
    _::RepresentativePeriods,
    modeltype::EnergyModel,
)
    for t_rp ∈ repr_periods(per)
        t_last = last(t_rp)
        ts = t_rp.operational.operational
        constraints_state_seq_iter(m, n, t_rp, t_last, ts, modeltype)
    end
end
"""
When the time structure includes `OperationalScenarios`, period `t_last` is updated with
last operational period within each operational scenario.
"""
function constraints_state_seq_iter(
    m,
    n::Reformer,
    per,
    _,
    _::OperationalScenarios,
    modeltype::EnergyModel,
)
    # Declaration of the required subsets
    𝒯ˢᶜ = opscenarios(per)
    for t_scp ∈ 𝒯ˢᶜ
        t_last = last(t_scp)
        ts = t_scp.operational.operational
        constraints_state_seq_iter(m, n, t_scp, t_last, ts, modeltype)
    end
end
function constraints_state_seq_iter(
    m,
    n::Reformer,
    per,
    t_last,
    _::SimpleTimes,
    modeltype::EnergyModel
)
    for (t_prev, t) ∈ withprev(per)
        ref_pers = RefPeriods(t_prev, t, t_last)
        constraints_state_seq(m, n, ref_pers, :ref_off_b, :ref_start_b, modeltype)
        constraints_state_seq(m, n, ref_pers, :ref_start_b, :ref_on_b, modeltype)
        constraints_state_seq(m, n, ref_pers, :ref_on_b, :ref_shut_b, modeltype)
        constraints_state_seq(m, n, ref_pers, :ref_shut_b, :ref_off_b, modeltype)
    end
end

"""
    constraints_state_seq(
        m,
        n::Reformer,
        ref_pers::RefPeriods,
        state_a::Symbol,
        state_b::Symbol,
        modeltype::EnergyModel,
    )

Function for creating the constraints on the sequencing of the individual states when
`state_b` has to occur after `state_a`. Both `state_a` and `state_b` refer in this case to
binary variables included in the JuMP model.

The function [`prev_op`](@ref) is used to incorporate the cyclic constraints.
"""
function constraints_state_seq(
    m,
    n::Reformer,
    ref_pers::RefPeriods,
    state_a::Symbol,
    state_b::Symbol,
    modeltype::EnergyModel,
)
    t_prev = prev_op(ref_pers)
    t = current_op(ref_pers)
    @constraint(m, m[state_a][n, t_prev] ≥ m[state_b][n, t] - m[state_b][n, t_prev])
end

"""
    constraints_state_time_iter(
        m,
        n::Reformer,
        per,
        t_last,
        ts,
        modeltype::EnergyModel
    )

Function for iterating through the time structure for calculating the correct requirement
for the length of the individual states.

When the time structure includes `RepresentativePeriods`, period `t_last` is updated with
last operational period within each representative period.
"""
function constraints_state_time_iter(
    m,
    n::Reformer,
    per,
    _,
    _::RepresentativePeriods,
    modeltype::EnergyModel,
)
    for t_rp ∈ repr_periods(per)
        t_last = last(t_rp)
        ts = t_rp.operational.operational
        constraints_state_time_iter(m, n, t_rp, t_last, ts, modeltype)
    end
end
"""
When the time structure includes `OperationalScenarios`, period `t_last` is updated with
last operational period within each operational scenario.
"""
function constraints_state_time_iter(
    m,
    n::Reformer,
    per,
    _,
    _::OperationalScenarios,
    modeltype::EnergyModel,
)
    for t_scp ∈ opscenarios(per)
        t_last = last(t_scp)
        ts = t_scp.operational.operational
        constraiteants_state_time_iter(m, n, t_scp, t_last, ts, modeltype)
    end
end
function constraints_state_time_iter(
    m,
    n::Reformer,
    per,
    t_last,
    _::SimpleTimes,
    modeltype::EnergyModel
)
    it_tech = zip(
        withprev(per),
        chunk_duration(per, time_startup(n, per); cyclic=true),
        chunk_duration(per, time_shutdown(n, per); cyclic=true),
        chunk_duration(per, time_off(n, per); cyclic=true),
    )

    for ((t_prev, t), chunck_start, chunck_shut, chunck_off) ∈ it_tech
        if isnothing(t_prev)
            t_prev = t_last
        end
        @constraint(m,
            sum(m[:ref_start_b][n, θ] * duration(θ) for θ ∈ chunck_start) ≥
            time_startup(n, t) * (m[:ref_start_b][n, t] - m[:ref_start_b][n, t_prev])
        )
        @constraint(m,
            sum(m[:ref_shut_b][n, θ] * duration(θ) for θ ∈ chunck_shut) ≥
            time_shutdown(n, t) * (m[:ref_shut_b][n, t] - m[:ref_shut_b][n, t_prev])
        )
        @constraint(m,
            sum(m[:ref_off_b][n, θ] * duration(θ) for θ ∈ chunck_off) ≥
            time_off(n, t) * (m[:ref_off_b][n, t] - m[:ref_off_b][n, t_prev])
        )
    end
end
