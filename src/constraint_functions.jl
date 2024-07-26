"""
    constraints_usage(
        m,
        n::AbstractElectrolyzer,
        𝒯ᴵⁿᵛ,
        t_inv::TS.StrategicPeriod{S, T, OP},
        modeltype::EnergyModel,
        ) where {S, T, OP<:TimeStructure{T}}

Function for creating the previous usage constraints, when the `TimeStructure` is given as
`SimpleTimes`.

Within all the years (in `sp.duration`) we assume the degradation is the same as it
is in the 1st year of that strategic period (optimistic assumption). However, when
we move to the next strategic period, we sum up the total usage in the previous
strategic periods
This ensures that the next strategic period starts after accounting for all prior usage.
Stack replacement resets the previous usage via the multiplier variable
`:elect_usage_mult_sp_b`
"""
function constraints_usage(
    m,
    n::AbstractElectrolyzer,
    𝒯ᴵⁿᵛ,
    t_inv::TS.StrategicPeriod{S, T, OP},
    modeltype::EnergyModel,
    ) where {S, T, OP<:TimeStructure{T}}

    # Definition of the auxiliary variable for the linear reformulation of the element-wise
    # product of `:elect_usage_sp[n, t_inv_pre]` and `:elect_usage_mult_sp_b[n, t_inv, t_inv_pre]`.
    # This reformulation requires the introduction of both a `lower_bound` and a
    # `upper_bound` of the variable `:elect_usage_sp` given through a value of `0` and
    # `stack_lifetime(n)`.
    use_lower_bound = FixedProfile(0)
    use_upper_bound = FixedProfile(stack_lifetime(n))
    prev_usage = linear_reformulation(m,
        𝒯ᴵⁿᵛ,
        𝒯ᴵⁿᵛ,
        m[:elect_usage_mult_sp_b][n, :, :],
        m[:elect_usage_sp][n, :],
        use_lower_bound,
        use_upper_bound,
    )

    # Iteration through the individual operational periods for calculating the new usage
    for (t_prev, t) ∈ withprev(t_inv)
        if isnothing(t_prev)
            # Constraint for the previous usage of the first operational period in an
            # investment period. The previous usage is given through the sum of the usage in
            # all previous strategic periods after the stack replacement
            @constraint(m,
                m[:elect_previous_usage][n, t] ==
                    sum(
                        prev_usage[t_inv, t_inv_pre] * duration_strat(t_inv_pre)
                        for t_inv_pre ∈ 𝒯ᴵⁿᵛ if isless(t_inv_pre, t_inv)
                    )
            )

        else
            # Constraint for the previous usage of a standard operational period
            # In this situation, it only has to consider whether the electrolyzer is on
            # or off
            @constraint(m,
                m[:elect_previous_usage][n, t] ==
                    m[:elect_previous_usage][n, t_prev] +
                    duration(t_prev) * m[:elect_on_b][n, t_prev] / 1000
            )
        end
    end

    # Constraint for the total usage of the electrolyzer including the current time step.
    # This ensures that the last repetition of the strategic period is appropriately
    # constrained.
    t = last(t_inv)
    @constraint(m,
        stack_lifetime(n) ≥
            (
                m[:elect_previous_usage][n, t] +
                m[:elect_usage_sp][n, t_inv] * (duration_strat(t_inv) - 1)
            )
            * 1000 + m[:elect_on_b][n, t] * EMB.multiple(t_inv, t)
    )
end
"""
    constraints_usage(
        m,
        n::AbstractElectrolyzer,
        𝒯ᴵⁿᵛ,
        t_inv::TS.StrategicPeriod{S, T, RepresentativePeriods{T, U, SimpleTimes{U}}},
        modeltype::EnergyModel,
        ) where {S, T, U}

Function for creating the previous usage constraints, when the `TimeStructure` is given as
`RepresentativePeriods`.

The general concept remains unchanged. However, we can consider now sequential
representative periods.
"""
function constraints_usage(
    m,
    n::AbstractElectrolyzer,
    𝒯ᴵⁿᵛ,
    t_inv::TS.StrategicPeriod{S, T, RepresentativePeriods{T, U, SimpleTimes{U}}},
    modeltype::EnergyModel,
    ) where {S, T, U}

    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(t_inv)

    # Constraint for the total usage in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:elect_usage_rp][n, t_rp] * 1000 ==
            sum(m[:elect_on_b][n, t] * multiple_strat(t_inv, t) * duration(t) for t ∈ t_rp)
    )


    # Definition of the auxiliary variable for the linear reformulation of the element-wise
    # product of `:elect_usage_sp[n, t_inv_pre]` and `:elect_usage_mult_sp_b[n, t_inv, t_inv_pre]`.
    # This reformulation requires the introduction of both a `lower_bound` and a
    # `upper_bound` of the variable `:elect_usage_sp` given through a value of `0` and
    # `stack_lifetime(n)`.
    use_lower_bound = FixedProfile(0)
    use_upper_bound = FixedProfile(stack_lifetime(n))
    prev_usage = linear_reformulation(m,
        𝒯ᴵⁿᵛ,
        𝒯ᴵⁿᵛ,
        m[:elect_usage_mult_sp_b][n, :, :],
        m[:elect_usage_sp][n, :],
        use_lower_bound,
        use_upper_bound,
    )

    # Iteration through the individual operational periods for calculating the new usage
    for (t_rp_prev, t_rp) ∈ withprev(𝒯ʳᵖ), (t_prev, t) ∈ withprev(t_rp)
        if isnothing(t_rp_prev) && isnothing(t_prev)
            # Constraint for the previous usage of the first operational period in an
            # investment period. The previous usage is given through the sum of the usage in
            # all previous strategic periods after the stack replacement
            @constraint(m,
                m[:elect_previous_usage][n, t] ==
                    sum(
                        prev_usage[t_inv, t_inv_pre] * duration_strat(t_inv_pre)
                        for t_inv_pre ∈ 𝒯ᴵⁿᵛ if isless(t_inv_pre, t_inv)
                    )
            )
        elseif isnothing(t_prev)
            # Constraint for the previous usage of the first operational period in a
            # representative period. The previous usage is given through the sum of the usage
            # in the previous representative period.
            @constraint(m,
            m[:elect_previous_usage][n, t] ==
                m[:elect_previous_usage][n, first(t_rp_prev)] +
                m[:elect_usage_rp][n, t_rp_prev]
        )
        else
            # Constraint for the previous usage of a standard operational period
            # In this situation, it only has to consider whether the electrolyzer is on
            # or off
            @constraint(m,
                m[:elect_previous_usage][n, t] ==
                    m[:elect_previous_usage][n, t_prev] +
                    duration(t_prev) * m[:elect_on_b][n, t_prev] / 1000
            )
        end
    end

    # Constraint for the total usage of the electrolyzer including the current time step.
    # This ensures that the last repetition of the strategic period is appropriately
    # constrained.
    # The last(last()) is required as it is important for the last operational period in
    # the last representative period.
    t = last(last(𝒯ʳᵖ))
    @constraint(m,
        stack_lifetime(n) ≥
            (
                m[:elect_previous_usage][n, t] +
                m[:elect_usage_sp][n, t_inv]*(duration_strat(t_inv) - 1)
            )
            * 1000 + m[:elect_on_b][n, t] * EMB.multiple(t_inv, t)
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

Function for creating operational limits off an `AbstractHydrogenNetworkNode`.

The operational limits limit the capacity usage of the electrolyser node between a minimimum
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
        min_load(n) * var[t] ≤ m[:cap_use][n, t]
    )
    @constraint(m, [t ∈ 𝒯],
        m[:cap_use][n, t] ≤ max_load(n) * var[t]
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
                    m[:cap_use][n, t] * EMB.opex_var(n, t)
                    + prod_start[t] * opex_startup(n, t)
                    + prod_shut[t] * opex_shutdown(n, t)
                    + prod_off[t] * opex_off(n, t)
                )
                * EMB.multiple(t_inv, t)
                for t ∈ t_inv)
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

The function automatically deduces the time structure provided to the system and calls the
calls the corresponding function.
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
        constraints_state_seq_iter(m, n, t_rp, t_last, t_rp.operational.operational, modeltype)
    end
end
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
        constraints_state_seq_iter(m, n, t_scp, t_last, t_scp.operational.operational, modeltype)
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
        constraints_state_seq(m, n, t, t_prev, t_last, :ref_off_b, :ref_start_b, modeltype)
        constraints_state_seq(m, n, t, t_prev, t_last, :ref_start_b, :ref_on_b, modeltype)
        constraints_state_seq(m, n, t, t_prev, t_last, :ref_on_b, :ref_shut_b, modeltype)
        constraints_state_seq(m, n, t, t_prev, t_last, :ref_shut_b, :ref_off_b, modeltype)
    end
end

"""
    constraints_state_seq(m, n::Reformer,
        t, t_prev, t_last,
        state_a::Symbol, state_b::Symbol,
        modeltype::EnergyModel
    )

Function for creating the constraints on the sequencing of the individual states when
`state_b` has to occur after `state_a`. Both `state_a` and `state_b` refer in this case to
binary variables included in the JuMP model.
"""
function constraints_state_seq(m, n::Reformer,
    t, t_prev, t_last,
    state_a::Symbol, state_b::Symbol,
    modeltype::EnergyModel,
)
    @constraint(m, m[state_a][n, t_prev] ≥ m[state_b][n, t] - m[state_b][n, t_prev])
end
"""
When the previous period `t_prev` is nothing, _i.e._, the first operational period in
another in a `SimpleTimes` time structure, it applies the cyclic constraint using `t_last`.
"""
function constraints_state_seq(m, n::Reformer,
    t, t_prev::Nothing, t_last,
    state_a::Symbol, state_b::Symbol,
    modeltype::EnergyModel,
)
    @constraint(m, m[state_a][n, t_last] ≥ m[state_b][n, t] - m[state_b][n, t_last])
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
        constraints_state_time_iter(m, n, t_rp, t_last, t_rp.operational.operational, modeltype)
    end
end
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
        constraiteants_state_time_iter(m, n, t_scp, t_last, t_scp.operational.operational, modeltype)
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
        chunk_duration(per, t_startup(n, per); cyclic=true),
        chunk_duration(per, t_shutdown(n, per); cyclic=true),
        chunk_duration(per, t_off(n, per); cyclic=true),
    )

    for ((t_prev, t), chunck_start, chunck_shut, chunck_off) ∈ it_tech
        if isnothing(t_prev)
            t_prev = t_last
        end
        @constraint(m,
            sum(m[:ref_start_b][n, θ] * duration(θ) for θ ∈ chunck_start) ≥
            t_startup(n, t) * (m[:ref_start_b][n, t] - m[:ref_start_b][n, t_prev])
        )
        @constraint(m,
            sum(m[:ref_shut_b][n, θ] * duration(θ) for θ ∈ chunck_shut) ≥
            t_shutdown(n, t) * (m[:ref_shut_b][n, t] - m[:ref_shut_b][n, t_prev])
        )
        @constraint(m,
            sum(m[:ref_off_b][n, θ] * duration(θ) for θ ∈ chunck_off) ≥
            t_off(n, t) * (m[:ref_off_b][n, t] - m[:ref_off_b][n, t_prev])
        )
    end
end
