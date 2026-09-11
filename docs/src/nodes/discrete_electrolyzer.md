# Electrolyzer Node with Piecewise-Linear Production and Discrete Degradation States

## Overview

Electrolysis plants exhibit two important non-linear phenomena:

1. The hydrogen production efficiency varies with load.
2. The efficiency decreases as the electrolysis stack degrades during operation.

The standard `Electrolyzer` models degradation through a continuously varying efficiency penalty. This results in bilinear constraints because hydrogen production depends on both utilized capacity and a continuous efficiency factor.

The `DiscreteDegradationPWLElectrolyzer` instead utilizes:

- a piecewise-linear production curve,
- load-dependent degradation rates,
- discrete degradation states,
- stack replacement,

resulting in a pure MILP formulation.

The production curve is approximated through neighbouring-breakpoint interpolation. The degradation of the stack is accumulated continuously but translated into a finite number of degradation states. Each degradation state corresponds to a fixed efficiency multiplier.

Consequently, efficiency degradation directly impacts hydrogen production without introducing bilinear terms.

> MILP compatibility: The formulation avoids the bilinear term
>
> `cap_use[n,t] * elect_efficiency_penalty[n,t]`
>
> by replacing the continuous efficiency penalty with degradation states and state-specific production curves.

---

# Additional Fields

## `load_breakpoints::Vector{Float64}`

Normalized load breakpoints expressed as fractions of installed capacity.

Example:

```julia
load_breakpoints = [0.0, 0.10, 0.15, 0.20, 1.0]
```

## `output_breakpoints::Dict{Resource, Vector{Float64}}`

Undegraded production values associated with the load breakpoints.

## `load_degradation_rates::Vector{Float64}`

Degradation rate associated with each load interval.

Exactly one degradation rate must exist for each load segment.

## `degradation_breakpoints::Vector{Float64}`

Breakpoints describing accumulated degradation.

Example:

```julia
degradation_breakpoints = [0.00, 0.01, 0.02, 0.03, 0.04, 0.05]
```

## `cycle_degradation_rate::Float64`

Degradation rate due to cycling given as fractional efficiency loss per 1000 equivalent full-power cycles.

---

# Mathematical Description

## Additional Variables

### Segment selection

```math
elect_pwl_seg_b[n_{el}, t, j, s]
```

Binary variable indicating that:

- degradation state `j` is active,
- load segment `s` is active.

### Local interpolation variable

```math
elect_pwl_theta[n_{el}, t, j, s]
```

Continuous interpolation variable inside the selected load segment.

### Degradation variables

```math
elect_prev_degradation[n_{el}, t]
```

Accumulated degradation prior to operational period `t`.

```math
elect_prev_degradation_sp[n_{el}, t_{inv}]
```

Accumulated degradation prior to strategic period `t_inv`.

### Cycling variables

```math
elect_ramp_pos[n,t]
```

```math
elect_ramp_neg[n,t]
```

```math
elect_abs_ramp[n,t]
```

---

# Load Representation

Let `ρ_s` denote the load breakpoints.

Exactly one degradation-state/load-segment combination is selected:

```math
\sum_j \sum_s elect\_pwl\_seg\_b[n,t,j,s] = elect\_on\_b[n,t]
```

The utilized capacity is:

```math
cap\_use[n,t] = C
\sum_j \sum_s
\left(
ρ_s elect\_pwl\_seg\_b[n,t,j,s]
+
(ρ_{s+1}-ρ_s) elect\_pwl\_theta[n,t,j,s]
\right)
```

where `C` is the installed capacity.

Interpolation is therefore only possible between neighbouring breakpoints.

---

# Degradation States

Let

```math
δ_1,\ldots,δ_{n_δ}
```

be degradation breakpoints.

Each interval

```math
[δ_j,δ_{j+1}]
```

defines a degradation state.

Representative degradation:

```math
\hat{δ}_j = (δ_j + δ_{j+1})/2
```

Efficiency multiplier:

```math
e_j = 1 - \hat{δ}_j
```

---

# Hydrogen Production

Let `y_s^p` denote the undegraded output breakpoint values.

Production is calculated as:

```math
flow\_out[n,t,p] = C
\sum_j \sum_s
 e_j
\left(
 y_s^p elect\_pwl\_seg\_b[n,t,j,s]
 +
 (y_{s+1}^p-y_s^p) elect\_pwl\_theta[n,t,j,s]
\right)
```

Because `e_j` is a parameter, the formulation remains linear.

---

# Load-Dependent Degradation

Let `d_s` denote the degradation rate associated with load segment `s`.

The degradation contribution is:

```math
deg_t =
\frac{duration(t)}{1000}
\sum_j \sum_s
 d_s elect\_pwl\_seg\_b[n,t,j,s]
```

Only the active load segment contributes degradation.

---

# Cycling Degradation

```math
cap\_use[n,t] - cap\_use[n,t-1]
=
elect\_ramp\_pos[n,t]
-
elect\_ramp\_neg[n,t]
```

```math
elect\_abs\_ramp[n,t]
=
elect\_ramp\_pos[n,t]
+
elect\_ramp\_neg[n,t]
```

Cycling contribution:

```math
deg_t^{cycle}
=
\frac{cycle\_degradation\_rate}{1000}
\frac{elect\_abs\_ramp[n,t]}{C}
```

---

# Total Degradation Evolution

```math
ΔD_t = deg_t + deg_t^{cycle}
```

```math
D_t = D_{t-1} + ΔD_{t-1}
```

Accumulated degradation determines the active degradation state.

---

# Stack Replacement

Stack replacement follows the same formulation as the existing `Electrolyzer` implementation.

If

```math
elect\_stack\_replace\_b[n,t_{inv}] = 1
```

then accumulated degradation is reset to zero.

Consequently:

- accumulated degradation becomes zero,
- the electrolyzer returns to the highest efficiency state,
- stack replacement costs are included through `opex_fixed`.

---

# Advantages

Compared to `Electrolyzer`, this formulation:

- remains a pure MILP,
- allows arbitrary load-dependent degradation rates,
- allows arbitrary degradation-efficiency relationships,
- directly reduces hydrogen production through degradation,
- preserves endogenous stack replacement decisions,
- uses neighbouring-breakpoint interpolation,
- avoids continuous-continuous bilinear terms.
