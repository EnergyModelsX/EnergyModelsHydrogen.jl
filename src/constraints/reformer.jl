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
        constraints_state_time_iter(m, n, t_scp, t_last, ts, modeltype)
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
