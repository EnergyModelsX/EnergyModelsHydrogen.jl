
# [Methods - Accessing fields](@id lib-int-met_field)

## [Index](@id lib-int-met_field-idx)

```@index
Pages = ["methods-fields.md"]
```

## [`AbstractElectrolyzer` types](@id lib-int-met_field-elec)

```@docs
EnergyModelsHydrogen.degradation_rate
EnergyModelsHydrogen.stack_replacement_cost
EnergyModelsHydrogen.stack_lifetime
```

## [`AbstractReformer` types](@id lib-int-met_field-ref)

```@docs
EnergyModelsHydrogen.opex_startup
EnergyModelsHydrogen.opex_shutdown
EnergyModelsHydrogen.opex_off
EnergyModelsHydrogen.time_startup
EnergyModelsHydrogen.time_shutdown
EnergyModelsHydrogen.time_off
EnergyModelsHydrogen.ramp_limit
```

## [`AbstractH2Storage` types](@id lib-int-met_field-abst_h2_stor)

```@docs
EnergyModelsHydrogen.discharge_charge
EnergyModelsHydrogen.level_charge
```

## [`HydrogenStorage` types](@id lib-int-met_field-h2_stor)

```@docs
EnergyModelsHydrogen.p_charge
EnergyModelsHydrogen.p_min
EnergyModelsHydrogen.p_max
EnergyModelsHydrogen.electricity_resource
```

## [`LoadLimit` and `Node` types](@id lib-int-met_field-loadlim)

```@docs
EnergyModelsHydrogen.min_load
EnergyModelsHydrogen.max_load
```

## [`AbstractRampParameters` and `AbstractReformer` types](@id lib-int-met_field-ramp)

```@docs
EnergyModelsHydrogen.ramp_up
EnergyModelsHydrogen.ramp_down
```

## [`CommitParameters` types](@id lib-int-met_field-commit)

```@docs
EnergyModelsHydrogen.opex_state
EnergyModelsHydrogen.time_state
```

## [`ElecPeriods` types](@id lib-int-met_field-elec_per)

```@docs
TimeStruct.strat_periods
EnergyModelsHydrogen.strat_per
EnergyModelsHydrogen.op_per
EnergyModelsHydrogen.is_last
```

## [`RefPeriods` types](@id lib-int-met_field-ref_per)

```@docs
EnergyModelsHydrogen.prev_op
EnergyModelsHydrogen.current_op
EnergyModelsHydrogen.last_op
```
