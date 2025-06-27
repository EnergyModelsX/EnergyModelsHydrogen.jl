# Declare all resources of the case
power = ResourceCarrier("Power", 0.0)
h2 = ResourceCarrier("H₂", 0.0)
co2 = ResourceEmit("CO₂", 1.0)

"""
    stor_test_case(𝒯; kwargs)

Simple test case for testing the h2 storage types. it can utilize differing input to test
the functionality of an h2 storage nodes.
"""
function stor_test_case(
    𝒯;
    stor_type=SimpleHydrogenStorage,
    p_min=30.0,
    p_charge=30.0,
    p_max=150.0,
    supply=FixedProfile(10),
    demand=FixedProfile(50),
)
    # Declaration of the resources
    𝒫 = [power, h2, co2]

    # Declaration of the nodes
    h2_source = RefSource(
        "H₂ source",
        supply,
        FixedProfile(9),
        FixedProfile(0),
        Dict(h2 => 1),
    )

    el_source = RefSource(
        "El source",
        FixedProfile(5),
        FixedProfile(30),
        FixedProfile(0),
        Dict(power => 1),
    )
    if stor_type == SimpleHydrogenStorage
        h2_storage = SimpleHydrogenStorage{CyclicStrategic}(
            "H₂ storage",
            StorCapOpexVar(FixedProfile(5), FixedProfile(1)),
            StorCap(FixedProfile(100)),
            h2,
            Dict(h2 => 1, power => 0.01),
            Dict(h2 => 1),
            2.0,
            20.0,
        )
    else
        h2_storage = HydrogenStorage{CyclicStrategic}(
            "Storage",
            StorCapOpexVar(FixedProfile(5), FixedProfile(1)),
            StorCap(FixedProfile(100)),
            h2,
            power,
            2.0,
            20.0,
            p_min,
            p_charge,
            p_max,
        )
    end
    h2_sink = RefSink(
        "h2_demand",
        demand,
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(200)),
        Dict(h2 => 1),
    )
    𝒩 = [h2_source, el_source, h2_storage, h2_sink]

    # Declaration of the links
    ℒ = [
        Direct("h2_source-h2_stor", h2_source, h2_storage)
        Direct("el_source-h2_stor", el_source, h2_storage)
        Direct("h2_stor-h2_sink", h2_storage, h2_sink)
        Direct("h2_source-h2_sink", h2_source, h2_sink)
    ]

    # Create the case and modeltype
    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]])
    modeltype = OperationalModel(
        Dict(co2 => FixedProfile(10)),
        Dict(co2 => FixedProfile(0)),
        co2,
    )

    # Create and run the model
    m = create_model(case, modeltype)
    set_optimizer(m, OPTIMIZER)
    optimize!(m)

    return m, case, modeltype
end

# Test set for the type `SimpleHydrogenStorage`
@testset "SimpleHydrogenStorage" begin
    # Specify the input parameters
    𝒯 = TwoLevel(1, 1, SimpleTimes(5, 1); op_per_strat=8760)

    # Modify the parameter set
    supply = OperationalProfile([10, 15, 10, 20, 0])
    demand = OperationalProfile([5, 15, 5, 15, 15])

    # Run the model
    m, case, modeltype = stor_test_case(𝒯; supply, demand)

    # Extract the sets and variables
    h2_source, h2_stor, h2_demand = get_nodes(case)[[1, 3,4]]
    flow_in = value.(m[:flow_in][h2_stor, :, :])

    @testset "Utlities" begin
        # Test the EMB utility functions
        @test charge(h2_stor) == StorCapOpexVar(FixedProfile(5), FixedProfile(1))
        @test level(h2_stor) == StorCap(FixedProfile(100))
        @test storage_resource(h2_stor) == h2
        @test inputs(h2_stor) == [h2, power] || inputs(h2_stor) == [power, h2]
        @test outputs(h2_stor) == [h2]
        @test node_data(h2_stor) == ExtensionData[]

        # Test the EMH utility functions
        @test EMH.discharge_charge(h2_stor) == 2
        @test EMH.level_charge(h2_stor) == 20
    end

    @testset "Mathematical formulation" begin
        # Test that the electricity demand is correctly included
        # (showing that we do not need a new function)
        @test all(flow_in[t, power] ≈ 0.01 * flow_in[t, h2] for t ∈ 𝒯)

        # Test that the maximum discharge is limited by the charge capacity and the multiplier
        #   EMB.constraints_capacity(m, n::AbstractH2Storage, 𝒯::TimeStructure, modeltype::EnergyModel)
        @test all(
            value.(m[:stor_discharge_use][h2_stor, t]) ≤
                2 * value.(m[:stor_charge_inst][h2_stor, t]) + TEST_ATOL
        for t ∈ 𝒯)
        @test all(
            value.(m[:stor_discharge_use][h2_stor, t]) ≤ 10 + TEST_ATOL
        for t ∈ 𝒯)

        # Test that the maximum discharge is only occuring a single time and that there is a
        # total deficit of 5 in the system, although the supplier and the demand equal
        @test sum(value.(m[:stor_discharge_use][h2_stor, t]) ≈ 10 for t ∈ 𝒯) == 1
        @test sum(value(m[:cap_use][h2_source, t]) for t ∈ 𝒯) ==
            sum(value(m[:cap_use][h2_demand, t]) for t ∈ 𝒯)
        @test sum(value.(m[:sink_deficit][h2_demand, t]) ≈ 5 for t ∈ 𝒯) == 1
    end

    # Release the environment
    finalize(backend(m).optimizer.model)
end

# Test set for the type `HydrogenStorage`
@testset "HydrogenStorage" begin
    # Create a function that calculates the energy demand
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

    # Specify the input parameters
    𝒯 = TwoLevel(1, 1, SimpleTimes(20, 2); op_per_strat=8760)
    supply = OperationalProfile(vcat(ones(10)*15, ones(10)*5))
    demand = FixedProfile(10)
    stor_type = HydrogenStorage

    @testset "Utlities" begin
        # Build and run the model
        m, case, modeltype = stor_test_case(𝒯; stor_type, supply, demand)

        # Extract the sets and variables
        h2_stor = get_nodes(case)[3]

        # Test the EMB utility functions
        @test charge(h2_stor) == StorCapOpexVar(FixedProfile(5), FixedProfile(1))
        @test level(h2_stor) == StorCap(FixedProfile(100))
        @test storage_resource(h2_stor) == h2
        @test inputs(h2_stor) == [h2, power] || inputs(h2_stor) == [power, h2]
        @test outputs(h2_stor) == [h2]
        @test node_data(h2_stor) == ExtensionData[]

        # Test the EMH utility functions
        @test EMH.discharge_charge(h2_stor) == 2
        @test EMH.level_charge(h2_stor) == 20
        @test EMH.p_min(h2_stor) == 30.0
        @test EMH.p_charge(h2_stor) == 30.0
        @test EMH.p_max(h2_stor) == 150.0
    end

    @testset "Equal charge to min pressure" begin
        # Modify the charge pressure
        p_charge = 30.0

        # Build and run the model
        m, case, modeltype = stor_test_case(𝒯; stor_type, p_charge, supply, demand)

        # Extract the sets and variables
        h2_stor, h2_demand = get_nodes(case)[[3, 4]]
        flow_in = value.(m[:flow_in][h2_stor, :, :])

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
        # Modify the charge pressure
        p_charge = 20.0

        # Build and run the model
        m, case, modeltype = stor_test_case(𝒯; stor_type, p_charge, supply, demand)

        # Extract the sets and variables
        h2_stor, h2_demand = get_nodes(case)[[3, 4]]
        flow_in = value.(m[:flow_in][h2_stor, :, :])
        𝒯 = get_time_struct(case)

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
        # Modify the charge pressure
        p_charge = 70.0

        # Build and run the model
        m, case, modeltype = stor_test_case(𝒯; stor_type, p_charge, supply, demand)

        # Extract the sets and variables
        h2_stor, h2_demand = get_nodes(case)[[3, 4]]
        flow_in = value.(m[:flow_in][h2_stor, :, :])
        𝒯 = get_time_struct(case)

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
