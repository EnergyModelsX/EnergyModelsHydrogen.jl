"""
    EMB.check_node(n::AbstractElectrolyzer, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that an *[`AbstractElectrolyzer`](@ref)* node is valid.

It reuses the standard checks of a `NetworkNode` node through calling the function
[`EMB.check_node_default`](@extref EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The field `cap` is required to be non-negative.
- The value of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex()`](@extref EnergyModelsBase.check_fixed_opex).
- The values of the dictionary `input` are required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.

- The lower limit on capacity utilization is required to be non-negative while the upper
  limit is required to be larger or equal than the lower limit as described in the
  [`check_load_lim()`](@ref)
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

    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)
    check_load_lim(n, 𝒯)
    @assert_or_log(
        0 ≤ degradation_rate(n) < 100,
        "The stack degradation rate must be in the range [0, 100)."
    )

    # Check for potential indexing problems
    message = "are not allowed for the field `stack_replacement_cost`."
    bool_sp = EMB.check_strategic_profile(stack_replacement_cost(n), message)
    # Check that the value is positive in all cases
    if bool_sp
        @assert_or_log(
            all(stack_replacement_cost(n, t_inv) ≥ 0 for t_inv ∈ 𝒯ᴵⁿᵛ),
            "The stack replacement costs must be non-negative."
        )
    end

    @assert_or_log(
        stack_lifetime(n) ≥ 0,
        "The stack lifetime must be non-negative."
    )
end
"""
    EMB.check_node(n::AbstractReformer, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that an *[`AbstractReformer`](@ref)* node is valid.

It reuses the standard checks of a `NetworkNode` node through calling the function
[`EMB.check_node_default`](@extref EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The field `cap` is required to be non-negative.
- The value of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`EMB.check_fixed_opex()`](@extref EnergyModelsBase.check_fixed_opex).
- The values of the dictionary `input` are required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.

- The lower limit on capacity utilization is required ot be non-negative while the upper
  limit is required to be larger or equal than the lower limit as described in the
  [`check_load_lim()`](@ref)
- The field `opex` of the `CommitParameters` of the fields `startup`, `shutdown`, and `off`
  is required to be non-negative.
- The field `time` of the `CommitParameters` of the fields `startup`, `shutdown`, and `off`
  is required to be non-negative and accessible through a `StrategicPeriod`, or
  `Representativeperiod` as outlined in the function
  [`check_commitment_profile`](@ref).

- The field `rate_limit` is required to be in the range [0,1].
"""
function EMB.check_node(
    n::AbstractReformer,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)
    check_load_lim(n, 𝒯)
    @assert_or_log(
        all(opex_startup(n, t) ≥ 0 for t ∈ 𝒯),
        "The start-up OPEX must be non-negative."
    )
    @assert_or_log(
        all(opex_shutdown(n, t) ≥ 0 for t ∈ 𝒯),
        "The shutdown OPEX must be non-negative."
    )
    @assert_or_log(
        all(opex_off(n, t) ≥ 0 for t ∈ 𝒯),
        "The offline OPEX must be non-negative."
    )
    check_commitment_profile(time_startup(n), 𝒯, "time_startup", check_timeprofiles)
    check_commitment_profile(time_shutdown(n), 𝒯, "time_shutdown", check_timeprofiles)
    check_commitment_profile(time_off(n), 𝒯, "time_off", check_timeprofiles)
    if isa(ramp_limit(n), UnionRampUp) # If we have bounds on positive changes
        @assert_or_log(
            all(0 ≤ ramp_up(n, t) ≤ 1 for t ∈ 𝒯),
            "The positive rate of change limit must be in the range [0, 1]"
        )
    end
    if isa(ramp_limit(n), UnionRampDown) # If we have bounds on negative changes
        @assert_or_log(
            all(0 ≤ ramp_down(n, t) ≤ 1 for t ∈ 𝒯),
            "The negative rate of change limit must be in the range [0, 1]"
        )
    end
end
"""
    EMB.check_node(n::SimpleHydrogenStorage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that a *[`SimpleHydrogenStorage`](@ref)* node is valid.

It reuses the standard checks of a `Storage` node through calling the function
[`EMB.check_node_default`](@extref EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required
  to be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required
  to be non-negative`.
- The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex) for the chosen composite
  type.
- The values of the dictionary `input` are required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.
- The value of the field `discharge_charge` is required to be positive.
- The value of the field `level_charge` is required to be positive. The provided capacities
  in the [`AbstractStorageParameters`](@extref EnergyModelsBase.AbstractStorageParameters)
  `charge` and `level cannot violate the value.
"""
function EMB.check_node(
    n::SimpleHydrogenStorage,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool
)
    par_charge = charge(n)
    par_level = level(n)
    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)

    @assert_or_log(
        all(capacity(par_charge, t) * level_charge(n) ≤ capacity(par_level, t) for t ∈ 𝒯),
        "The charge capacity cannot be larger than the the level capacity devided by the " *
        "value of the field `level_charge`."
    )
    @assert_or_log(
        discharge_charge(n) > 0,
        "The value of the field `discharge_charge` is required to be positive",
    )
    @assert_or_log(
        level_charge(n) > 0,
        "The value of the field `level_charge` is required to be positive",
    )
end
"""
    EMB.check_node(n::HydrogenStorage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)

This method checks that a *[`HydrogenStorage`](@ref)* node is valid.

It reuses the standard checks of a `Storage` node through calling the function
[`EMB.check_node_default`](@extref EnergyModelsBase.check_node_default), but adds an
additional check on the data.

## Checks
- The `TimeProfile` of the field `capacity` in the type in the field `charge` is required
  to be non-negative.
- The `TimeProfile` of the field `capacity` in the type in the field `level` is required
  to be non-negative`.
- The `TimeProfile` of the field `fixed_opex` is required to be non-negative and
  accessible through a `StrategicPeriod` as outlined in the function
  [`check_fixed_opex`](@extref EnergyModelsBase.check_fixed_opex) for the chosen composite
  type.
- The values of the dictionary `input` are required to be non-negative.
- The values of the dictionary `output` are required to be non-negative.
- The value of the field `discharge_charge` is required to be positive.
- The value of the field `level_charge` is required to be positive. The provided capacities
  in the [`AbstractStorageParameters`](@extref EnergyModelsBase.AbstractStorageParameters)
  `charge` and `level cannot violate the value.
- The values of the fields `p_min`, `p_charge`, and `p_max` are required to be positive.
- The values of the fields `p_min` and `p_charge` must be smaller than `p_max`.
- The value of the field `p_charge` must be smaller than `p_min`.
"""
function EMB.check_node(
    n::HydrogenStorage,
    𝒯,
    modeltype::EnergyModel,
    check_timeprofiles::Bool,
)
    par_charge = charge(n)
    par_level = level(n)
    EMB.check_node_default(n, 𝒯, modeltype, check_timeprofiles)

    @assert_or_log(
        all(capacity(par_charge, t) * level_charge(n) ≤ capacity(par_level, t) for t ∈ 𝒯),
        "The charge capacity cannot be larger than the the level capacity devided by the " *
        "value of the field `level_charge`."
    )
    @assert_or_log(
        discharge_charge(n) > 0,
        "The value of the field `discharge_charge` is required to be positive",
    )
    @assert_or_log(
        level_charge(n) > 0,
        "The value of the field `level_charge` is required to be positive",
    )
    @assert_or_log(
        p_min(n) > 0,
        "The value of the field `p_min` is required to be positive",
    )
    @assert_or_log(
        p_charge(n) > 0,
        "The value of the field `p_charge` is required to be positive",
    )
    @assert_or_log(
        p_max(n) > 0,
        "The value of the field `p_max` is required to be positive",
    )
    @assert_or_log(
        p_max(n) > p_min(n),
        "The value of the field `p_max` is required to be larger than the value of the " *
        "field `p_min`",
    )
    @assert_or_log(
        p_max(n) > p_charge(n),
        "The value of the field `p_max` is required to be larger than the value of the " *
        "field `p_charge`",
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
  calling the function [`EnergyModelsBase.check_representative_profile`](@extref EnergyModelsBase).
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
            all(time_profile[t_rp] ≥ 0 for t_rp ∈ 𝒯ʳᵖ),
            "The time profile of the field `" * field_name * "` must be non-negative."
        )
    end

    if check_timeprofiles && bool_sp
        EMB.check_profile(field_name, time_profile, 𝒯)
    end
end
"""
    check_load_lim(n, 𝒯)

Checks the limits for the capacity load.

## Checks
- The field `min_load` is required to be non-negative.
- The field `max_load` is required to be larger than the field `min_load`.
"""
function check_load_lim(n, 𝒯)
    @assert_or_log(
        all(min_load(n, t) ≥ 0 for t ∈ 𝒯),
        "The minimum load must be non-negative."
    )
    @assert_or_log(
        all(max_load(n, t) ≥ min_load(n, t) for t ∈ 𝒯),
        "The maximum load must be larger than or equal to the minimum load."
    )
end
