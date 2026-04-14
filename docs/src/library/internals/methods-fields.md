
# [Methods - Accessing fields](@id lib-int-met_field)

## [Index](@id lib-int-met_field-idx)

```@index
Pages = ["methods-fields.md"]
```

## [`AbstractElectrolyzer` types](@id lib-int-met_field-elec)

```@docs
EMH.degradation_rate
EMH.stack_replacement_cost
EMH.stack_lifetime
```

## [`AbstractReformer` types](@id lib-int-met_field-ref)

```@docs
EMH.opex_startup
EMH.opex_shutdown
EMH.opex_off
EMH.time_startup
EMH.time_shutdown
EMH.time_off
EMH.ramp_limit
```

## [`AbstractH2Storage` types](@id lib-int-met_field-abst_h2_stor)

```@docs
EMH.discharge_charge
EMH.level_charge
```

## [`HydrogenStorage` types](@id lib-int-met_field-h2_stor)

```@docs
EMH.p_charge
EMH.p_min
EMH.p_max
EMH.electricity_resource
```

## [`LoadLimit` and `Node` types](@id lib-int-met_field-loadlim)

```@docs
EMH.min_load
EMH.max_load
```

## [`AbstractRampParameters` and `AbstractReformer` types](@id lib-int-met_field-ramp)

```@docs
EMH.ramp_up
EMH.ramp_down
```

## [`CommitParameters` types](@id lib-int-met_field-commit)

```@docs
EMH.opex_state
EMH.time_state
```

## [`ElecPeriods` types](@id lib-int-met_field-elec_per)

```@docs
TimeStruct.strat_periods
EMH.strat_per
EMH.op_per
EMH.is_last
```

## [`RefPeriods` types](@id lib-int-met_field-ref_per)

```@docs
EMH.prev_op
EMH.current_op
EMH.last_op
```
