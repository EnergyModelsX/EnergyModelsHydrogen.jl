# The optimization model expects these default keys
params_dict = Dict(
    :supply => FixedProfile(10),
    :demand => FixedProfile(50),
    :num_op => 30,
    :dur_op => 1,
    :rep => false,
    :simple => true,
    :p_min => 30.0,
    :p_charge => 30.0,
    :p_max => 150.0,
)

# Test set for the type `SimpleHydrogenStorage`
@testset "SimpleHydrogenStorage" begin

    # Modify the parameter set
    params_used = deepcopy(params_dict)
    params_used[:num_op] = 5
    params_used[:supply] = OperationalProfile([10, 15, 10, 20, 0])
    params_used[:demand] = OperationalProfile([5, 15, 5, 15, 15])
    (m, case) = build_run_h2_storage_model(params_used)

    # Extract the sets and variables
    power = case[:products][1]
    h2 = case[:products][2]
    h2_stor = case[:nodes][3]
    h2_demand = case[:nodes][4]
    flow_in = value.(m[:flow_in][h2_stor, :, :])
    𝒯 = case[:T]

    # Test that the electricity demand is correctly included
    # (showing that we do not need a new function)
    @test all(flow_in[t, power] ≈ 0.01 * flow_in[t, h2] for t ∈ 𝒯)

    # Test that the maximum discharge is limited by the charge capacity and the multiplier
    #   EMB.constraints_capacity(m, n::AbstractH2Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
    @test all(
        value.(m[:stor_discharge_use][h2_stor, t]) ≤
            2 * value.(m[:stor_charge_inst][h2_stor, t]) + TEST_ATOL
    for t ∈ 𝒯)
    # Test that the maximum discharge is only occuring a single time and that there is a
    # total deficit of 5 in the system, although the supplier and the demand equal
    @test sum(value.(m[:stor_discharge_use][h2_stor, t]) ≈ 10 for t ∈ 𝒯) == 1
    @test sum(params_used[:supply][t] for t ∈ 𝒯) == sum(params_used[:demand][t] for t ∈ 𝒯)
    @test sum(value.(m[:sink_deficit][h2_demand, t]) ≈ 5 for t ∈ 𝒯) == 1

    # Release the environment
    finalize(backend(m).optimizer.model)
end

# Test set for the type `HydrogenStorage`
@testset "HydrogenStorage" begin

    # Create a function that calculated the energy demand
    function energy_demand(m, n, t)
        # Physical input parameters
        pᵢₙ = EMH.p_charge(n)
        pₘᵢₙ = EMH.p_min(n)
        pₘₐₓ = EMH.p_max(n)
        PRₘₐₓ = 2.5

        # Component specific input data
        M = 2.02
        LHV = 120.0

        # Calculation of the required pressure ratios for compression
        PRₜₒₜ = pₘₐₓ/pᵢₙ
        n_comp = Int(ceil(log(PRₜₒₜ)/log(PRₘₐₓ)))
        PR = PRₜₒₜ^(1/n_comp)

        # Calculation of the energy demand
        p = value.(m[:stor_level][n, t]) * (pₘₐₓ - pₘᵢₙ) / capacity(level(n), t) + pₘᵢₙ
        W = EMH.energy_curve(p, pᵢₙ, PR, n_comp, M, LHV)
        return W
    end

    # Initiate a dictionary for storing the compression energy requirement
    flow_el = Dict{Symbol,Array}()

    # Modify the parameter set
    supply = vcat(ones(10)*15, ones(10)*5)
    params_used = deepcopy(params_dict)
    params_used[:num_op] = 20
    params_used[:dur_op] = 2
    params_used[:supply] = OperationalProfile(supply)
    params_used[:demand] = FixedProfile(10)
    params_used[:simple] = false

    @testset "Equal charge to min pressure" begin
        # Modify the parameter set
        params_used[:p_charge] = 30.0
        # Build and run the model
        (m, case) = build_run_h2_storage_model(params_used)

        # Extract the sets and variables
        power = case[:products][1]
        h2 = case[:products][2]
        h2_stor = case[:nodes][3]
        h2_demand = case[:nodes][4]
        flow_in = value.(m[:flow_in][h2_stor, :, :])
        𝒯 = case[:T]

        # Save the results
        flow_el[:equal] = [flow_in[t, power] for t ∈ 𝒯]

        # Test that the electricity demand is correctly included and approximately correct
        @test all(
            ≈(flow_in[t, power], energy_demand(m, h2_stor, t) * flow_in[t, h2], rtol=5e-2)
        for t ∈ 𝒯)

        # Test that the electricity demand is increasing in the first 10 periods
        ops = collect(withprev(𝒯))[2:10]
        @test all(
            flow_in[t, power] > flow_in[t_prev, power] for (t_prev, t) ∈ ops
        )

        # Test that the storage node is charging in the first 10 operational period
        @test sum(value.(m[:stor_charge_use][h2_stor, t]) > 0 for t ∈ 𝒯) == 10

        # Release the environment
        finalize(backend(m).optimizer.model)
    end

    @testset "Lower charge to min pressure" begin
        # Modify the parameter set
        params_used[:p_charge] = 20.0

        # Build and run the model
        (m, case) = build_run_h2_storage_model(params_used)

        # Extract the sets and variables
        power = case[:products][1]
        h2 = case[:products][2]
        h2_stor = case[:nodes][3]
        h2_demand = case[:nodes][4]
        flow_in = value.(m[:flow_in][h2_stor, :, :])
        𝒯 = case[:T]

        # Save the results
        flow_el[:lower] = [flow_in[t, power] for t ∈ 𝒯]

        # Test that the electricity demand is correctly included and approximately correct
        @test all(
            ≈(flow_in[t, power], energy_demand(m, h2_stor, t) * flow_in[t, h2], rtol=5e-2)
        for t ∈ 𝒯)

        # Test that the electricity demand is increasing in the first 10 periods
        ops = collect(withprev(𝒯))[2:10]
        @test all(
            flow_in[t, power] > flow_in[t_prev, power] for (t_prev, t) ∈ ops
        )

        # Test that the storage node is charging in the first 10 operational period
        @test sum(value.(m[:stor_charge_use][h2_stor, t]) > 0 for t ∈ 𝒯) == 10

        # Test that the electricity demand is larger than it would be the case of equal
        # charging pressure to minimum pressure
        @test all(flow_el[:lower][1:10] > flow_el[:equal][1:10])

        # Release the environment
        finalize(backend(m).optimizer.model)
    end

    @testset "Higher charge to min pressure" begin
        # Modify the parameter set
        params_used[:p_charge] = 70.0

        # Build and run the model
        (m, case) = build_run_h2_storage_model(params_used)

        # Extract the sets and variables
        power = case[:products][1]
        h2 = case[:products][2]
        h2_stor = case[:nodes][3]
        h2_demand = case[:nodes][4]
        flow_in = value.(m[:flow_in][h2_stor, :, :])
        𝒯 = case[:T]

        # Save the results
        flow_el[:higher] = [flow_in[t, power] for t ∈ 𝒯]

        # Test that the electricity demand is correctly included and approximately correct
        @test all(
            ≈(
                flow_in[t, power],
                energy_demand(m, h2_stor, t) * flow_in[t, h2],
            rtol=5e-2, atol=0.001)
        for t ∈ 𝒯)

        # Test that the electricity demand is zero in the first 3 periods (as the charge
        # pressure is larger than the storage pressure) and increasing in the subsequent
        # 7 periods
        ops_1 = collect(𝒯)[1:3]
        @test all(
            flow_in[t, power] ≈ 0 for t ∈ ops_1
        )
        ops_2 = collect(withprev(𝒯))[4:10]
        @test all(
            flow_in[t, power] > flow_in[t_prev, power] for (t_prev, t) ∈ ops_2
        )

        # Test that the storage node is charging in the first 10 operational period
        @test sum(value.(m[:stor_charge_use][h2_stor, t]) > 0 for t ∈ 𝒯) == 10

        # Test that the electricity demand is larger than it would be the case of equal
        # charging pressure to minimum pressure
        @test all(flow_el[:higher][1:10] < flow_el[:equal][1:10])

        # Release the environment
        finalize(backend(m).optimizer.model)
    end
end
