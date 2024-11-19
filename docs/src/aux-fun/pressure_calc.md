# [Calculation of compression energy](@id aux-p_calc)

## [Single compressor](@id aux-p_calc-single)

The pressure increase through compression can be either isothermal, polytropic, or isentropic.
The required energy for compression increases from isothermal to isentropic.
`EnergyModelsHydrogen` incorporates isentropic compression.
Depending on the input parameters, this can however be translated to polytropic compression.
In the following, ideal gas behaviour is assumed.

Given the ideal gas constant ``R`` (8.314 J/mol/K), the inlet temperature ``T_1`` (in K), the specific heat ratio ``\kappa`` (no unit), the efficiency ``\eta`` (no unit), the inlet pressure ``p_1``, and the outlet pressure ``p_2`` (both pressures require the same unit), the compression energy ``W_p`` in J/mol can be calculated as

```math
W_p(p_1, p_2) =
    \frac{\kappa R T_1}{\kappa-1}
    \left(\left(\frac{p_2}{p_1}\right)^{\frac{\kappa-1}{\kappa}}-1\right)
    \frac{1}{\eta}
```

The compression energy requirement is implemented through the function [`compression_energy`](@ref EnergyModelsHydrogen.compression_energy).
This function requires as default only the pressures ``p_1`` and ``p_2`` while all other parameters can be included as keyword arguments.
The included standard values are ``T_1=298.15~\text{K}``, ``\kappa = 1.41``, and ``\eta = 0.75``. This values are representative for hydrogen.

## [Compression train](@id aux-p_calc-train)

It is in general not advisable to have a large compression ratio as the temperature increase results in an increased compression energy requirment.
It is instead beneficial to utilize multiple compressors with interstage cooling.

If the delivery pressure ``p`` is larger than the inlet pressure ``p_{in}``, we first calculate the different pressure levels for a compressor traing of ``n_{comp}`` compressors and a maximum pressure ratio of ``PR`` in each compressor as

```math
\begin{aligned}
p_{i+1,1} & = p_{in} PR^{i} \quad \text{for} ~ i \in 0, \ldots, n_{comp}-1 \quad & \text{if} ~ p > p_{in}PR^i \\
p_{i,2} & = p_{in} PR^{i} \quad \text{for} ~ i \in 1, \ldots, n_{comp} \quad & \text{if} ~ p > p_{in}PR^i \\
\end{aligned}
```

As can be seen from above equations, we have one more pressure ``p_{i,1}`` than ``p_{i,2}``.
Hence, the pressure ``p`` is added to ``p_{i,2}``.

The total compression energy requirement (without unit, as fraction of the stored energy) is then given by

```math
W = \frac{\sum_{i} W_p(p_{i,1}, p_{i,2})}{1000 M \times \text{LHV}}
```

using the molar mass ``M`` (in g/mol) and the lower heating value LHV (in MJ/kg)

The energy demand in a compressor train is implemented through the function [`energy_curve`](@ref EnergyModelsHydrogen.energy_curve).
