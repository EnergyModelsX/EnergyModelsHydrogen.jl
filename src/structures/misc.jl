"""
    ElecPeriods

Contains information for calculating the constraints for `AbstractElectrolyzer` node types.

# Fields
- **`sps::TS.AbstractStratPers`** are the strategic periods of the `TimeStructure`.
- **`sp::TS.AbstractStrategicPeriod`** is the current strategic period.
- **`op::TS.AbstractStrategicPeriod`** is the current operational period.
- **`last::Bool`** is a boolean indicator of the last period. It is used for calculating the
  bounds for the last operational periods within a strategic period.
"""
mutable struct ElecPeriods
    sps::TS.AbstractStratPers
    sp::TS.AbstractStrategicPeriod
    op::EMB.NothingPeriod
    last::Bool
end

"""
    TS.strat_periods(pers::ElecPeriods)

Returns the strategic periods of an [`ElecPeriods`](@ref) `pers`.
"""
TS.strat_periods(pers::ElecPeriods) = pers.sps

"""
    strat_per(pers::ElecPeriods)

Returns the current strategic period of an [`ElecPeriods`](@ref) `pers`.
"""
strat_per(pers::ElecPeriods) = pers.sp

"""
    op_per(pers::ElecPeriods)

Returns the current operational period of an [`ElecPeriods`](@ref) `pers`.
"""
op_per(pers::ElecPeriods) = pers.op

"""
    is_last(pers::ElecPeriods)

Boolean indicator whether the representative period or operational scenario is the last
within a strategic period of an [`ElecPeriods`](@ref) `pers`.
"""
is_last(pers::ElecPeriods) = pers.last

"""
    RefPeriods{S<:Union{TS.OperationalPeriod, Nothing}}

Contains information for calculating the constraints for `Reformer` node types.

# Fields
- **`previous::S`** is the previous operational period received from the
  [`withprev`](@extref TimeStruct.withprev) iterator
- **`current::TS.OperationalPeriod`** is the current operational period.
- **`last::TS.OperationalPeriod`** is the last operational period in the current
  `SimpleTimes` structure within a strategic period (or representative period, if present,
  or operational scenario, if present).
"""
mutable struct RefPeriods{S<:Union{TS.OperationalPeriod, Nothing}}
    previous::S
    current::TS.OperationalPeriod
    last::TS.OperationalPeriod
end

"""
    prev_op(pers::RefPeriods)

Returns the previous operational period of a [`RefPeriods`](@ref) `pers`.
"""
prev_op(pers::RefPeriods) = pers.previous
"""
When the previous operational period is nothing, it returns the last operational period within
the given time structure.
"""
prev_op(pers::RefPeriods{Nothing}) = pers.last

"""
    current_op(pers::RefPeriods)

Returns the current operational period of a [`RefPeriods`](@ref) `pers`.
"""
current_op(pers::RefPeriods) = pers.current

"""
    last_op(pers::RefPeriods)

Returns the last operational period of a [`RefPeriods`](@ref) `pers`.
"""
last_op(pers::RefPeriods) = pers.last
