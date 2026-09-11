"""
    constraints_usage(m, n::AbstractElectrolyzer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)

Function for creating the usage constraints for an [`AbstractElectrolyzer`](@ref).

These constraints calculate the usage of the electrolyzer up to each time step for both the
lifetime and the degradation calculations.
"""
function constraints_usage(m, n::AbstractElectrolyzer, 𝒯ᴵⁿᵛ, modeltype::EnergyModel)
    # Mass/energy balance constraints for stored energy carrier.
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ)
        # Calculation of the usage within a strategic period
        @constraint(m,
            m[:elect_use_sp][n, t_inv] * 1000 ==
                sum(m[:elect_on_b][n, t] * scale_op_sp(t_inv, t) for t ∈ t_inv)
        )

        # Upper constraint for the total usage of the electrolyzer
        @constraint(m,
            stack_lifetime(n)/1000 ≥
                m[:elect_prev_use_sp][n, t_inv] +
                m[:elect_use_sp][n, t_inv] * duration_strat(t_inv)
        )

        # Initialization of the periods
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
    ub = stack_lifetime(n)/1000

    # Constraints for the linear reformulation. The constraints are based on the
    # McCormick envelopes which result in an exact reformulation for the multiplication
    # of a binary and a continuous variable.
    @constraints(m, begin
        m[:elect_prev_use_sp][n, t_inv] ≥ 0
        m[:elect_prev_use_sp][n, t_inv] ≥ ub * ((1 - m[:elect_stack_replace_b][n, t_inv]) - 1) + aux_var
        m[:elect_prev_use_sp][n, t_inv] ≤ ub * (1 - m[:elect_stack_replace_b][n, t_inv])
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

Function for creating the previous usage of an [`AbstractElectrolyzer`](@ref) node depending
on the type of [`PreviousPeriods`](@extref EnergyModelsBase.PreviousPeriods).

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
            scale_op_sp(strat_per(elec_pers), t_prev) * m[:elect_on_b][n, t_prev] / 1000
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


"""
    constraints_degradation(
        m,
        n::StrategicDegradationElectrolyzer,
        𝒯,
        𝒯ᴵⁿᵛ,
    )

Selects one degradation state in each strategic period based on accumulated
usage before the beginning of that strategic period.
"""
function constraints_degradation(
    m,
    n::StrategicDegradationElectrolyzer,
    𝒯,
    𝒯ᴵⁿᵛ,
)
    breakpoints = degradation_usage_breakpoints(n)
    𝒮 = degradation_states(n)
    # M must be at least as large as the last breakpoint (in 1000 h units) so that
    # inactive-state lower-bound constraints do not impose a positive floor on
    # elect_prev_use_sp (which is fixed to 0 in the first strategic period).
    M = stack_lifetime(n) / 1000

    @constraint(m, [t_inv in 𝒯ᴵⁿᵛ],
        sum(m[:elect_deg_state_b][n, t_inv, j] for j in 𝒮) == 1
    )

    @constraint(m, [t_inv in 𝒯ᴵⁿᵛ, j in 𝒮],
        m[:elect_prev_use_sp][n, t_inv] >=
            breakpoints[j] - M * (1 - m[:elect_deg_state_b][n, t_inv, j])
    )

    @constraint(m, [t_inv in 𝒯ᴵⁿᵛ, j in 𝒮],
        m[:elect_prev_use_sp][n, t_inv] <=
            breakpoints[j + 1] + M * (1 - m[:elect_deg_state_b][n, t_inv, j])
    )
end
function constraints_degradation(
    m,
    n::AbstractElectrolyzer,
    𝒯,
    𝒯ᴵⁿᵛ,
)
    # Determine the efficiency penalty at current timestep due to degradation:
    # Linearly decreasing to zero with increasing `degradation_rate(n)` and `elect_prev_use`.
    # With `degradation_rate(n)` = 0, the degradation is disabled,
    # Note that `degradation_rate(n)` is a percentage and is normalized to the
    # interval [0, 1] in the constraint.
    @constraint(m, [t ∈ 𝒯],
        m[:elect_efficiency_penalty][n, t] ==
            1 - (degradation_rate(n)/100) * m[:elect_prev_use][n, t]
    )
end

"""
    EMB.constraints_flow_out(
        m,
        n::StrategicDegradationElectrolyzer,
        𝒯::TimeStructure,
        modeltype::EnergyModel,
    )

Calculates output flows using an efficiency determined by accumulated usage at
the beginning of the strategic period.

The operational capacity use is disaggregated by degradation state to avoid a
product between two continuous variables.
"""
function EMB.constraints_flow_out(
    m,
    n::StrategicDegradationElectrolyzer,
    𝒯::TimeStructure,
    modeltype::EnergyModel,
)
    𝒫ᵒᵘᵗ = outputs(n)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Compute cap_inst[t_inv] * elect_deg_state_b[n, t_inv, j] for all (t_inv, j).
    # Returns a DenseAxisArray indexed over 𝒯ᴵⁿᵛ per state j.
    # For EnergyModel this is a scalar product; for AbstractInvestmentModel the EMIExt
    # override applies a McCormick linearization.
    cap_state = Dict(
        j => cap_deg_state_product(m, n, 𝒯ᴵⁿᵛ, j, modeltype)
        for j in degradation_states(n)
    )

    for t_inv in 𝒯ᴵⁿᵛ
        for t in t_inv
            @constraint(m,
                m[:cap_use][n, t] ==
                    sum(
                        m[:elect_cap_use_deg][n, t, j]
                        for j in degradation_states(n)
                    )
            )

            @constraint(m, [
                j in degradation_states(n),
            ],
                m[:elect_cap_use_deg][n, t, j] <=
                    max_load(n, t) * cap_state[j][t_inv]
            )

            @constraint(m, [p in 𝒫ᵒᵘᵗ],
                m[:flow_out][n, t, p] ==
                    outputs(n, p) *
                    sum(
                        degradation_state_efficiency(n, j) *
                        m[:elect_cap_use_deg][n, t, j]
                        for j in degradation_states(n)
                    )
            )

            @constraint(m,
                m[:elect_efficiency_penalty][n, t] ==
                    sum(
                        degradation_state_efficiency(n, j) *
                        m[:elect_deg_state_b][n, t_inv, j]
                        for j in degradation_states(n)
                    )
            )
        end
    end
end

"""
    cap_deg_state_product(m, n::StrategicDegradationElectrolyzer, 𝒯ᴵⁿᵛ, j, modeltype::EnergyModel)

Returns an expression indexed over `𝒯ᴵⁿᵛ` for `capacity(n, t_inv) * elect_deg_state_b[n, t_inv, j]`.

For an `EnergyModel` this is a scalar-binary product (no auxiliary variables needed).
For an `AbstractInvestmentModel` with investment data the extension in `EMIExt` overrides
this to apply a McCormick linearization of `cap_inst[n, t_inv] * elect_deg_state_b[n, t_inv, j]`.
"""
function cap_deg_state_product(
    m,
    n::StrategicDegradationElectrolyzer,
    𝒯ᴵⁿᵛ,
    j,
    ::EnergyModel,
)
    return @expression(
        m,
        [t_inv ∈ 𝒯ᴵⁿᵛ],
        capacity(n, t_inv) * m[:elect_deg_state_b][n, t_inv, j],
    )
end
