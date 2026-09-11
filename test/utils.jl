# Declare all resources of the case
power = ResourceCarrier("Power", 0.0)
h2 = ResourceCarrier("H₂", 0.0)
co2 = ResourceEmit("CO₂", 1.0)

"""
    function constructor_helper(
        elec_type;
        cap = FixedProfile(-25),        # Installed capacity [MW]
        opex_var = FixedProfile(5),     # Variable Opex
        opex_fixed = FixedProfile(100), # Fixed Opex
        input = Dict(power => 1),       # Input: Ratio of Input flows to characteristic throughput
        output = Dict(h2 => 0.62),      # Ouput: Ratio of Output flow to characteristic throughput
        data = ExtensionData[],         # Additional data (e.g. for investments)
        load_limits = LoadLimits(0, 1), # Minimum and maximum load
        degradation_rate = 0.1,         # Degradation rate
        degradation_usage_breakpoints = collect(0.0:5.0:60.0), # Degradation usage breakpoints
        stack_cost = FixedProfile(3e5), # Stack replacement costs
        stack_lifetime = 60000,         # Stack lifetime in h
    )

Node-constructor helper function for creating an electrolyzer node of the specified type with the given parameters.
"""
function constructor_helper(
    elec_type;
    cap = FixedProfile(-25),
    opex_var = FixedProfile(5),
    opex_fixed = FixedProfile(100),
    input = Dict(power => 1),
    output = Dict(h2 => 0.62),
    data = ExtensionData[],
    load_limits = LoadLimits(0, 1),
    degradation_rate = 0.1,
    degradation_usage_breakpoints = collect(0.0:5.0:60.0),
    stack_cost = FixedProfile(3e5),
    stack_lifetime = 60000,
)
    if elec_type == StrategicDegradationElectrolyzer
        return StrategicDegradationElectrolyzer(
            "Electrolyzer",
            cap,
            opex_var,
            opex_fixed,
            input,
            output,
            data,
            load_limits,
            degradation_rate,
            degradation_usage_breakpoints,
            stack_cost,
            stack_lifetime,
        )
    else
        return elec_type(
            "Electrolyzer",
            cap,
            opex_var,
            opex_fixed,
            input,
            output,
            data,
            load_limits,
            degradation_rate,
            stack_cost,
            stack_lifetime,
        )
    end
end
