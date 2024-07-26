# Set the global to true to suppress the error message
EMB.TEST_ENV = true

@testset "Test checks - Nodes" begin

    # Resources used in the checks
    NG = ResourceCarrier("NG", 0.2)
    Power = ResourceCarrier("Power", 0.0)
    H2 = ResourceCarrier("Hydrogen", 0.0)
    CO2 = ResourceEmit("CO2", 1.0)

    # Function for setting up the system for testing an `AbstractElectrolyzer` node
    function simple_graph(network::SimpleElectrolyzer)

        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(Power => 1),
        )

        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(H2 => 1),
        )

        resources = [Power, H2, CO2]
        ops = SimpleTimes(5, 2)
        T = TwoLevel(2, 2, ops; op_per_strat=10)

        nodes = [source, network, sink]
        links = [
            Direct(12, source, network)
            Direct(23, network, sink)
            ]

        model = OperationalModel(
            Dict(CO2 => FixedProfile(100)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return create_model(case, model), case, model
    end

    # Test that the fields of a NetworkNode are correctly checked
    # - EMB.check_node(n::AbstractElectrolyzer, 𝒯, modeltype::EnergyModel)
    @testset "Test checks - AbstractElectrolyzer" begin

        # Test that a wrong capacity is caught by the checks.
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(-25),  # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            0.1,                # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)


        # Test that a wrong fixed OPEX is caught by the checks.
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(-100), # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            0.1,                # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)

        # Test that a wrong input dictionary is caught by the checks.
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => -1),  # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            0.1,                # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)

        # Test that a wrong output dictionary is caught by the checks.
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => -0.62),  # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            0.1,                # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)

        # Test that a wrong minimum load is caught by the checks.
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(-0.5, 1.0),   # Minimum and maximum load
            0.1,                # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)

        # Test that a wrong maximum load is caught by the checks.
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(1.5, 1.0), # Minimum and maximum load
            0.1,                # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)

        # Test that a wrong degradation rate load is caught by the checks.
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            -0.1,               # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            1,                  # Degradation rate
            FixedProfile(3e5),  # Stack replacement costs
            60000,              # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)

        # Test that a wrong stack replacement profile is caught by the checks.
        function check_stack_replace_prof(stack_replace)
            elec = SimpleElectrolyzer(
                "PEM",
                FixedProfile(25),   # Installed capacity [MW]
                FixedProfile(5),    # Variable Opex
                FixedProfile(100),  # Fixed Opex
                Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
                Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
                Data[],             # Data
                LoadLimits(0, 1),   # Minimum and maximum load
                1,                  # Degradation rate
                stack_replace,      # Stack replacement costs
                60000,              # Stack lifetime in h
            )
            return simple_graph(elec)
        end
        stack_replace = FixedProfile(-5)
        @test_throws AssertionError check_stack_replace_prof(stack_replace)
        stack_replace = StrategicProfile([10])
        @test_throws AssertionError check_stack_replace_prof(stack_replace)
        stack_replace = OperationalProfile([10])
        @test_throws AssertionError check_stack_replace_prof(stack_replace)

        # Test that a wrong lifetime is caught by the checks.
        elec = SimpleElectrolyzer(
            "PEM",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            0.1,                # Degradation rate
            FixedProfile(3e5), # Stack replacement costs
            -10,                # Stack lifetime in h
        )
        @test_throws AssertionError simple_graph(elec)
    end

    # Function for setting up the system for testing an `AbstractElectrolyzer` node
    function simple_graph(network::Reformer)

        # Used source, network, and sink
        source = RefSource(
            "source",
            FixedProfile(4),
            FixedProfile(10),
            FixedProfile(0),
            Dict(NG => 1),
        )

        sink = RefSink(
            "sink",
            FixedProfile(3),
            Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
            Dict(H2 => 1),
        )

        resources = [NG, H2, CO2]
        ops = SimpleTimes(1, 2)
        T = TwoLevel(1, 2, ops; op_per_strat=10)

        nodes = [source, network, sink]
        links = [
            Direct(12, source, network)
            Direct(23, network, sink)
            ]

        model = OperationalModel(
            Dict(CO2 => FixedProfile(1e5)),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
        case = Dict(
                    :T => T,
                    :nodes => nodes,
                    :links => links,
                    :products => resources,
        )
        return create_model(case, model), case, model
    end

    # Test that the fields of a NetworkNode are correctly checked
    # - EMB.check_node(n::AbstractReformer, 𝒯, modeltype::EnergyModel)
    @testset "Test checks - AbstractReformer" begin

        # Test that a wrong capacity is caught by the checks.
        ref = Reformer(
            "Reformer",
            FixedProfile(-25),  # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1.0),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            FixedProfile(1),    # Startup OPEX
            FixedProfile(1),    # Shutdown OPEX
            FixedProfile(1),    # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )
        @test_throws AssertionError simple_graph(ref)


        # Test that a wrong fixed OPEX is caught by the checks.
        ref = Reformer(
            "Reformer",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(-100), # Fixed Opex
            Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1.0),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            FixedProfile(1),    # Startup OPEX
            FixedProfile(1),    # Shutdown OPEX
            FixedProfile(1),    # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )
        @test_throws AssertionError simple_graph(ref)

        # Test that a wrong input dictionary is caught by the checks.
        ref = Reformer(
            "Reformer",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(Power => -1),  # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1.0),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            FixedProfile(1),    # Startup OPEX
            FixedProfile(1),    # Shutdown OPEX
            FixedProfile(1),    # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )
        @test_throws AssertionError simple_graph(ref)

        # Test that a wrong output dictionary is caught by the checks.
        ref = Reformer(
            "Reformer",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => -1.0),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            FixedProfile(1),    # Startup OPEX
            FixedProfile(1),    # Shutdown OPEX
            FixedProfile(1),    # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )
        @test_throws AssertionError simple_graph(ref)

        # Test that a wrong unit commitment times are caught by the checks.
        ref = Reformer(
            "Reformer",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1.0),    # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            FixedProfile(-1),   # Startup OPEX
            FixedProfile(1),    # Shutdown OPEX
            FixedProfile(1),    # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )
        ref = Reformer(
            "Reformer",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1.0),    # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            FixedProfile(1),    # Startup OPEX
            FixedProfile(-1),   # Shutdown OPEX
            FixedProfile(1),    # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )
        ref = Reformer(
            "Reformer",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1.0),    # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(0, 1),   # Minimum and maximum load
            FixedProfile(1),    # Startup OPEX
            FixedProfile(1),    # Shutdown OPEX
            FixedProfile(-1),   # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )

        # Test that a wrong profiles for minimum time of unit commitment are caught by the checks.
        # - check_commitment_profile()
        function check_commitment_prof(time_profile)
            ref = Reformer(
                "Reformer",
                FixedProfile(25),   # Installed capacity [MW]
                FixedProfile(5),    # Variable Opex
                FixedProfile(100),  # Fixed Opex
                Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
                Dict(H2 => 1.0),    # Ouput: Ratio of Output flow to characteristic throughput
                Data[],             # Data
                LoadLimits(0, 1),   # Minimum and maximum load
                FixedProfile(1),    # Startup OPEX
                FixedProfile(1),    # Shutdown OPEX
                FixedProfile(1),    # Offline OPEX
                time_profile,       # Minimum startup time
                FixedProfile(1),    # Minimum shutdown time
                FixedProfile(1),    # Minimum offline time
            )
            return simple_graph(ref)
        end
        min_start = OperationalProfile([10])
        @test_throws AssertionError check_commitment_prof(min_start)
        min_start = StrategicProfile([OperationalProfile([10])])
        @test_throws AssertionError check_commitment_prof(min_start)
        min_start = FixedProfile(-5)
        @test_throws AssertionError check_commitment_prof(min_start)
        min_start = StrategicProfile([-5])
        @test_throws AssertionError check_commitment_prof(min_start)
        min_start = StrategicProfile([10, 10])
        @test_throws AssertionError check_commitment_prof(min_start)

        # Test that a wrong minimum load is caught by the checks.
        ref = Reformer(
            "Reformer",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1.0),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(-0.5, 1.0),   # Minimum and maximum load
            FixedProfile(1),    # Startup OPEX
            FixedProfile(1),    # Shutdown OPEX
            FixedProfile(1),    # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )
        @test_throws AssertionError simple_graph(ref)

        # Test that a wrong maximum load is caught by the checks.
        ref = Reformer(
            "Reformer",
            FixedProfile(25),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(100),  # Fixed Opex
            Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1.0),   # Ouput: Ratio of Output flow to characteristic throughput
            Data[],             # Data
            LoadLimits(1.5, 1.0), # Minimum and maximum load
            FixedProfile(1),    # Startup OPEX
            FixedProfile(1),    # Shutdown OPEX
            FixedProfile(1),    # Offline OPEX
            FixedProfile(1),    # Minimum startup time
            FixedProfile(1),    # Minimum shutdown time
            FixedProfile(1),    # Minimum offline time
        )
        @test_throws AssertionError simple_graph(ref)

    end

end

# Set the global again to false
EMB.TEST_ENV = false
