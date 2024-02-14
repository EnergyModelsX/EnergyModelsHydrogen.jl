"""
    constraints_usage(
        m,
        n::Electrolyzer,
        𝒯ᴵⁿᵛ,
        t_inv::TS.StrategicPeriod{S, T},
        ) where {S, T<:SimpleTimes}

Function for creating the previous usage constraints, when the TimeStructure is given as
SimpleTimes.

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
    n::Electrolyzer,
    𝒯ᴵⁿᵛ,
    t_inv::TS.StrategicPeriod{S, T},
    ) where {S, T<:SimpleTimes}

    # Iteration through the individual operational periods for calculating the new usage
    for (t_prev, t) ∈ withprev(t_inv)
        if isnothing(t_prev)
            # Constraint for the previous usage of the first operational period in an
            # investment period. The previous usage is given through the sum of the usage in
            # all previous strategic periods after the stack replacement
            @constraint(m,
                m[:elect_previous_usage][n, t] ==
                    sum(
                        m[:elect_usage_sp][n, t_inv_pre] * duration(t_inv) *
                        m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre]
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

    # # Constraint total usage of the electrolyzer including the current time step.
    # # This ensures that the last time step is appropriately constrained.
    # @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
    #     stack_lifetime(n) >=
    #         (m[:elect_previous_usage][n, last(t_inv)] + m[:elect_usage_sp][n, t_inv]) *
    #         1000 * (duration(t_inv) - 1) +
    #         m[:elect_on_b][n, last(t_inv)] * EMB.multiple(t_inv, t)
    # )


    # Constraint for the total usage of the electrolyzer including the current time step.
    # This ensures that the last time step is appropriately constrained.
    t = last(t_inv)
    @constraint(m,
        stack_lifetime(n) >=
            (m[:elect_previous_usage][n, t] + m[:elect_usage_sp][n, t_inv]) *
            1000 * (duration(t_inv) - 1) +
            m[:elect_on_b][n, t] * EMB.multiple(t_inv, t)
    )
end
"""
    constraints_usage(
        m,
        n::Electrolyzer,
        𝒯ᴵⁿᵛ,
        t_inv::TS.StrategicPeriod{S, RepresentativePeriods{T, S, SimpleTimes{S}}},
        ) where {S, T}

Function for creating the previous usage constraints, when the TimeStructure is given as
RepresentativePeriods.

The general concept remains unchanged. However, we can consider now sequential
representative periods.
"""
function constraints_usage(
    m,
    n::Electrolyzer,
    𝒯ᴵⁿᵛ,
    t_inv::TS.StrategicPeriod{S, RepresentativePeriods{T, S, SimpleTimes{S}}},
    ) where {S, T}

    # Declaration of the required subsets
    𝒯ʳᵖ = repr_periods(t_inv)

    # Constraint for the total usage in a given representative period
    @constraint(m, [t_rp ∈ 𝒯ʳᵖ],
        m[:elect_usage_rp][n, t_rp] * 1000 ==
            sum(m[:elect_on_b][n, t] * multiple_strat(t_inv, t) * duration(t) for t ∈ t_rp)
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
                        m[:elect_usage_sp][n, t_inv_pre] * duration(t_inv) *
                        m[:elect_usage_mult_sp_b][n, t_inv, t_inv_pre]
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
                m[:elect_usage_rp][n, t_rp]
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
    # This ensures that the last time step is appropriately constrained.
    # The last(last()) is required as it is important for the last operational period in
    # the last representative period.
    t = last(last(𝒯ʳᵖ))
    @constraint(m,
        stack_lifetime(n) >=
            (m[:elect_previous_usage][n, t] + m[:elect_usage_sp][n, t_inv]) *
            1000 * (duration(t_inv) - 1) +
            m[:elect_on_b][n, t] * EMB.multiple(t_inv, t)
    )
end
