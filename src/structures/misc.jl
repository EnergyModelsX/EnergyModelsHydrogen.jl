"""
    ElecPeriods{S<:NothingPeriod}

Contains information for calculating the constraints for `AbstractElectrolyzer` node types.

# Fields
- **`sps::TS.StratPeriods`** are the strategic periods of the `TimeStructure`.
- **`sp::TS.AbstractStrategicPeriod`** is the current strategic period.
- **`op::TS.AbstractStrategicPeriod`** is the current operational period.
- **`last::Bool`** is a boolean indicator of the last period. It is used for calculating the
  bounds for the last operational periods within a strategic period.
"""
mutable struct ElecPeriods
    sps::TS.StratPeriods
    sp::TS.AbstractStrategicPeriod
    op::EMB.NothingPeriod
    last::Bool
end

"""
    TS.strat_periods(pers::ElecPeriods)

Returns the strategic periods.
"""
TS.strat_periods(pers::ElecPeriods) = pers.sps

"""
    strat_per(pers::ElecPeriods)

Returns the current strategic period.
"""
strat_per(pers::ElecPeriods) = pers.sp

"""
    op_per(pers::ElecPeriods)

Returns the current operational period.
"""
op_per(pers::ElecPeriods) = pers.op

"""
    is_last(pers::ElecPeriods)

Boolean indicator whether the representative period or operational scenario is the last
within a strategic period.
"""
is_last(pers::ElecPeriods) = pers.last
