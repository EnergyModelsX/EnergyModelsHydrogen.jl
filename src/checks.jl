"""
    EMB.check_node(n::AbstractElectrolyzer, 𝒯, modeltype::EnergyModel)

This method checks that an `AbstractElectrolyzer` node is valid.

## Checks
- The field `cap` is required to be non-negative.
- The values of the dictionary `input` are required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.
- The value of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex()`](@extref EnergyModelsBase.check_fixed_opex).

- The field `min_load` is required to be non-negative.
- The field `max_load` is required to be larger than the field `min_load`.
- The field `degradation_rate` is required to be in the range [0,1).
- The `TimeProfile` of the field `stack_replacement` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex()`](@extref EnergyModelsBase.check_fixed_opex).
- The field `stack_lifetime` is required to be non-negative.
"""
function EMB.check_node(
    n::AbstractElectrolyzer,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        sum(capacity(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        sum(inputs(n, p) ≥ 0 for p ∈ inputs(n)) == length(inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        sum(outputs(n, p) ≥ 0 for p ∈ outputs(n)) == length(outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
    @assert_or_log(min_load(n) ≥ 0, "The minimum load must be non-negative.")
    @assert_or_log(
        max_load(n) ≥ min_load(n),
        "The maximum load must be larger than or equal to the minimum load."
    )
    @assert_or_log(
        0 ≤ degradation_rate(n) < 1,
        "The stack degradation rate must be in the range [0, 1)."
    )

    if isa(stack_replacement_cost(n), StrategicProfile) && check_timeprofiles
        @assert_or_log(
            length(stack_replacement_cost(n).vals) == length(𝒯ᴵⁿᵛ),
            "The timeprofile provided for the field `stack_replacement_cost` does not " *
            "match the strategic structure."
        )
    end
    # Check for potential indexing problems
    message = "are not allowed for the field `stack_replacement_cost`."
    bool_sp = EMB.check_strategic_profile(stack_replacement_cost(n), message)
    # Check that the value is positive in all cases
    if bool_sp
        @assert_or_log(
            sum(stack_replacement_cost(n, t_inv) ≥ 0 for t_inv ∈ 𝒯ᴵⁿᵛ) == length(𝒯ᴵⁿᵛ),
            "The stack replacement costs must be non-negative."
        )
    end

    @assert_or_log(
        stack_lifetime(n) ≥ 0,
        "The stack lifetime must be non-negative."
    )
end
"""
    EMB.check_node(n::AbstractReformer, 𝒯, modeltype::EnergyModel)

This method checks that a `AbstractReformer` node is valid.

## Checks
- The field `cap` is required to be non-negative.
- The values of the dictionary `input` are required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.
- The value of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex()`](@extref EnergyModelsBase.check_fixed_opex).

- The field `opex_startup` is required to be non-negative.
- The field `opex_shutdown` is required to be non-negative.
- The field `opex_off` is required to be non-negative.

- The field `min_load` is required to be non-negative.
- The field `max_load` is required to be larger than the field `min_load`.
"""
function EMB.check_node(
    n::AbstractReformer,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)

    @assert_or_log(
        sum(capacity(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The capacity must be non-negative."
    )
    @assert_or_log(
        sum(inputs(n, p) ≥ 0 for p ∈ inputs(n)) == length(inputs(n)),
        "The values for the Dictionary `input` must be non-negative."
    )
    @assert_or_log(
        sum(outputs(n, p) ≥ 0 for p ∈ outputs(n)) == length(outputs(n)),
        "The values for the Dictionary `output` must be non-negative."
    )
    EMB.check_fixed_opex(n, 𝒯ᴵⁿᵛ, check_timeprofiles)
    @assert_or_log(
        sum(opex_startup(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The start-up OPEX must be non-negative."
    )
    @assert_or_log(
        sum(opex_shutdown(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The shutdown OPEX must be non-negative."
    )
    @assert_or_log(
        sum(opex_off(n, t) ≥ 0 for t ∈ 𝒯) == length(𝒯),
        "The offline OPEX must be non-negative."
    )
    check_commitment_profile(t_startup(n), 𝒯, "t_startup", check_timeprofiles)
    check_commitment_profile(t_shutdown(n), 𝒯, "t_shutdown", check_timeprofiles)
    check_commitment_profile(t_off(n), 𝒯, "t_off", check_timeprofiles)
    @assert_or_log(min_load(n) ≥ 0, "The minimum load must be non-negative.")
    @assert_or_log(
        max_load(n) ≥ min_load(n),
        "The maximum load must be larger than or equal to the minimum load."
    )
end

"""
    check_commitment_profile(
        time_profile::TimeProfile,
        𝒯::TwoLevel,
        field_name::String,
        check_timeprofiles::Bool
    )

Checks that the unit commitment `time_profile` for the field `field_name` follows
the given `TimeStructure` `𝒯`.

## Checks
- The `time_profile` cannot have a finer granulation than `RepresentativeProfile` through
  calling the function [`EMB.check_representative_profile()`](@extref).
- The `time_profile` must be non-negative.

## Conditional checks (if `check_timeprofiles=true`)
- The `time_profile`s have to have the same length as the number of strategic or
  representative periods.
"""

function check_commitment_profile(
    time_profile,
    𝒯,
    field_name::String,
    check_timeprofiles::Bool,
)

    # Check for potential indexing problems
    message = "are not allowed for the field `" * field_name * "`."
    bool_sp = EMB.check_representative_profile(time_profile, message)

    # Check that the value is positive in all cases
    if isa(time_profile, FixedProfile)
        @assert_or_log(
            time_profile.val ≥ 0,
            "The time profile of the field `" * field_name * "` must be non-negative."
        )
    elseif bool_sp
        𝒯ʳᵖ = repr_periods(𝒯)
        @assert_or_log(
            sum(time_profile[t_rp] ≥ 0 for t_rp ∈ 𝒯ʳᵖ) == length(𝒯ʳᵖ),
            "The time profile of the field `" * field_name * "` must be non-negative."
        )
    end

    if check_timeprofiles && bool_sp
        EMB.check_profile(field_name, time_profile, 𝒯)
    end
end
