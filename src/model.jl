"""
    variables_node(m, 𝒩ˢᵗᵒʳ::Vector{<:AbstractElectrolyzer}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** electrolyzer nodes:
- `elect_on_b[n, t]` is binary variable which is 1 if electrolyzer `n` is operating in
  operational period `t`.
- `elect_prev_use[n, t]` is the total use of the electrolyzer `n` in all previous operational
  periods up to operational period `t` since the last stack replacement. The value is
  provided in 1000 operational periods duration to avoid a too large matrix range.
- `elect_prev_use_sp[n, t_inv]` is the total use of the electrolyzer `n` in all previous
  investment periods up to investment period `t_inv` since the last stack replacement. The
  value is provided in 1000 operational periods duration to avoid a too large matrix range.
- `elect_use_sp[n, t_inv]` is the total time of usage of electrolyzer `n` in investment
  period `t_inv`. The value is provided in 1000 operational periods duration to avoid a too
  large matrix range.
- `elect_use_rp[n, t_rp]` is the total time of usage of electrolyzer `n` in representative
  period `t_rp`, declared if the `TimeStructure` includes `RepresentativePeriods`. The value
  is provided in 1000 operational periods duration to avoid a too large matrix range.
- `elect_stack_replace_b`[n, t_inv] is a binary variable to indicate if electrolyzer `n`
  has stack replacement (value of 1) in investment period `t_inv`. In this case, the
  efficiency penalty is reset to 0.
- `elect_efficiency_penalty[n, t]` is a coefficient that accounts for drop in efficiency of
  electrolyzer `n` in  operational period due to degradation in the electrolyzer.
  It starts at 1 and is reset to 1 at the beginning of the investment period with stack
  replacement
"""
function EMB.variables_node(m, 𝒩ᴱᴸ::Vector{<:AbstractElectrolyzer}, 𝒯, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Variables for degredation
    @variable(m, elect_on_b[𝒩ᴱᴸ, 𝒯], Bin)
    @variable(m, elect_prev_use[𝒩ᴱᴸ, 𝒯] ≥ 0)
    @variable(m, elect_prev_use_sp[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ] ≥ 0)
    @variable(m, elect_use_sp[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ] ≥ 0)
    if 𝒯 isa TwoLevel{S,T,U} where {S,T,U<:RepresentativePeriods}
        𝒯ʳᵖ = repr_periods(𝒯)
        @variable(m, elect_use_rp[𝒩ᴱᴸ, 𝒯ʳᵖ])
    end
    @variable(m, elect_stack_replace_b[𝒩ᴱᴸ, 𝒯ᴵⁿᵛ], Bin)
    @variable(m, 0.0 ≤ elect_efficiency_penalty[𝒩ᴱᴸ, 𝒯] ≤ 1.0)
end

"""
    EMB.create_node(m, n::AbstractElectrolyzer, 𝒯, 𝒫,  modeltype::EnergyModel)

Set all constraints for an `AbstractElectrolyzer`. Can serve as fallback option for all
unspecified subtypes of `AbstractElectrolyzer`.

It differs from the function for a standard `Storage` node through both calling additional
functions as well as for calculations within the function.

# Called constraint functions
- [`constraints_usage`](@ref),
- [`constraints_flow_in`](@extref EnergyModelsBase.constraints_flow_in),
- [`constraints_flow_out`](@extref EnergyModelsBase.constraints_flow_out),
- [`constraints_data`](@extref EnergyModelsBase.constraints_data) for all `node_data(n)`,
- [`constraints_capacity`](@extref EnergyModelsBase.constraints_capacity), and
- [`constraints_opex_var`](@extref EnergyModelsBase.constraints_opex_var).
"""
function EMB.create_node(m, n::AbstractElectrolyzer, 𝒯, 𝒫, modeltype::EnergyModel)

    # Declaration of the required subsets
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # Constraints for the calculation of the usage of the electrolyzer in the previous
    # time periods
    constraints_usage(m, n, 𝒯ᴵⁿᵛ, modeltype)

    # Iterate through all data and set up the constraints corresponding to the data
    for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Call of the function for the inlet flow to the `Electrolyzer` node
    constraints_flow_in(m, n, 𝒯, modeltype)

    # Outlet flow constraint including the efficiency penalty, if an `Electrolyzer` node is
    # used.
    constraints_flow_out(m, n, 𝒯, modeltype)

    # Fix the variable `elect_on_b` for operational periods without capacity
    fix_elect_on_b(m, n, 𝒯, 𝒫, modeltype)

    # Determine the efficiency penalty at current timestep due to degradation:
    # Linearly decreasing to zero with increasing `degradation_rate(n)` and `elect_prev_use`.
    # With `degradation_rate(n)` = 0, the degradation is disabled,
    # Note that `degradation_rate(n)` is a percentage and is normalized to the
    # interval [0, 1] in the constraint.
    @constraint(m, [t ∈ 𝒯],
        m[:elect_efficiency_penalty][n, t] ==
            1 - (degradation_rate(n)/100) * m[:elect_prev_use][n, t]
    )

    # Calculation of auxiliary variables used in the calculation of the usage bound and
    # stack replacement
    prod_on = multiplication_variables(m, n, 𝒯, m[:elect_on_b][n, :], modeltype)
    stack_replace = multiplication_variables(m, n, 𝒯ᴵⁿᵛ, m[:elect_stack_replace_b][n, :], modeltype)

    # Constraint for the maximum and minimum production volume
    constraints_capacity(m, n, 𝒯, prod_on, modeltype)

    # Constraint for the fixed OPEX contributions. The division by duration_strat(t_inv) for the
    # stack replacement is requried due to multiplication with the duration in the objective
    # calculation
    @constraint(m, [t_inv ∈ 𝒯ᴵⁿᵛ],
        m[:opex_fixed][n, t_inv] ==
            opex_fixed(n, t_inv) * m[:cap_inst][n, first(t_inv)]
            + stack_replace[t_inv] * stack_replacement_cost(n, t_inv) / duration_strat(t_inv)
    )


    # Call of the functions for the variable OPEX constraint introduction
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end

"""
    EMB.variables_node(m, 𝒩ʳᵉᶠ::Vector{Reformer}, 𝒯, modeltype::EnergyModel)

Creates the following additional variables for **ALL** reformer nodes:
- `ref_off_b[n, t]` is a binary variable which is 1 if reformer `n` is in state `off` in
  operational period `t`.
- `ref_start_b[n, t]` is a binary variable which is 1 if reformer `n` is in state `start-up`
  in operational period `t`.
- `ref_on_b[n, t]` is a binary variable which is 1 if reformer `n` is in state `on` in
  operational period `t`.
- `ref_shut_b[n, t]` is a binary variable which is 1 if reformer `n` is in state `shutdown`
  in operational period `t`.
"""
function EMB.variables_node(m, 𝒩ʳᵉᶠ::Vector{Reformer}, 𝒯, modeltype::EnergyModel)
    # Define the states and binary variables
    @variable(m, ref_off_b[𝒩ʳᵉᶠ, 𝒯], Bin)
    @variable(m, ref_start_b[𝒩ʳᵉᶠ, 𝒯], Bin)
    @variable(m, ref_on_b[𝒩ʳᵉᶠ, 𝒯], Bin)
    @variable(m, ref_shut_b[𝒩ʳᵉᶠ, 𝒯], Bin)
end

"""
    EMB.create_node(m, n::Reformer, 𝒯, 𝒫, modeltype::EnergyModel)

Set all constraints for an `Reformer`.
It differs from the function for a standard `Storage` node through both calling additional
functions as well as for calculations within the function.

# Called constraint functions
- [`constraints_flow_in`](@extref EnergyModelsBase.constraints_flow_in),
- [`constraints_flow_out`](@extref EnergyModelsBase.constraints_flow_out),
- [`constraints_data`](@extref EnergyModelsBase.constraints_data) for all `node_data(n)`,
- [`constraints_capacity`](@extref EnergyModelsBase.constraints_capacity),
- [`constraints_state_seq_iter`](@ref),
- [`constraints_state_time_iter`](@ref),
- [`constraints_rate_of_change_iterate`](@ref),
- [`constraints_opex_fixed`](@extref EnergyModelsBase.constraints_opex_fixed), and
- [`constraints_opex_var`](@extref EnergyModelsBase.constraints_opex_var).
"""
function EMB.create_node(m, n::Reformer, 𝒯, 𝒫, modeltype::EnergyModel)
    # Declaration of the required subsets.
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    # General flow in and out constraints
    constraints_flow_in(m, n, 𝒯, modeltype)
    constraints_flow_out(m, n, 𝒯, modeltype)

        # Iterate through all data and set up the constraints corresponding to the data
        for data ∈ node_data(n)
        constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
    end

    # Calculation of auxiliary variables used in the calculation of the usage bounds
    prod_on = multiplication_variables(m, n, 𝒯, m[:ref_on_b][n, :], modeltype)

    # Constraint for the maximum and minimum production volume
    constraints_capacity(m, n, 𝒯, prod_on, modeltype)

    # Only one state active in each time-step
    @constraint(m, [t ∈ 𝒯],
        m[:ref_off_b][n, t] + m[:ref_start_b][n, t] +
        m[:ref_on_b][n, t] + m[:ref_shut_b][n, t]
            == 1
    )

    for t_inv ∈ 𝒯ᴵⁿᵛ
        # Calaculation of the last operational period
        t_last  = last(t_inv)

        # Constraints for the order of the states of the reformer node
        constraints_state_seq_iter(m, n, t_inv, t_last, t_inv.operational, modeltype)

        # Constraints for the minimum time of the individual states
        constraints_state_time_iter(m, n, t_inv, t_last, t_inv.operational, modeltype)

        # Constraints for the limit on the rate of change
        constraints_rate_of_change_iterate(m, n, t_inv, t_last, t_inv.operational, modeltype)
    end

    # Call of the functions for both fixed and variable OPEX constraints introduction
    constraints_opex_fixed(m, n, 𝒯ᴵⁿᵛ, modeltype)
    constraints_opex_var(m, n, 𝒯ᴵⁿᵛ, modeltype)
end
