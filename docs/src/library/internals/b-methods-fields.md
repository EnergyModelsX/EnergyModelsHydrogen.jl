
# Methods - Accessing fields

## Index

```@index
Pages = ["b-methods-fields.md"]
```

## `AbstractElectrolyzer`

```@docs
EnergyModelsHydrogen.degradation_rate
EnergyModelsHydrogen.stack_replacement_cost
EnergyModelsHydrogen.stack_lifetime
```

## `AbstractReformer`

```@docs
EnergyModelsHydrogen.opex_startup
EnergyModelsHydrogen.opex_shutdown
EnergyModelsHydrogen.opex_off
EnergyModelsHydrogen.time_startup
EnergyModelsHydrogen.time_shutdown
EnergyModelsHydrogen.time_off
EnergyModelsHydrogen.ramp_limit
```

## `LoadLimit` and `Node`

```@docs
EnergyModelsHydrogen.min_load
EnergyModelsHydrogen.max_load
```

## `AbstractRampParameters` and `AbstractReformer`

```@docs
EnergyModelsHydrogen.ramp_up
EnergyModelsHydrogen.ramp_down
```

## `CommitParameters`

```@docs
EnergyModelsHydrogen.opex_state
EnergyModelsHydrogen.time_state
```

## `ElecPeriods`

```@docs
TimeStruct.strat_periods
EnergyModelsHydrogen.strat_per
EnergyModelsHydrogen.op_per
EnergyModelsHydrogen.is_last
```

## `RefPeriods`

```@docs
EnergyModelsHydrogen.prev_op
EnergyModelsHydrogen.current_op
EnergyModelsHydrogen.last_op
```
