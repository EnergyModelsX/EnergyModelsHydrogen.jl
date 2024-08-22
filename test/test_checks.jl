# Set the global to true to suppress the error message
EMB.TEST_ENV = true

# Resources used in the checks
NG = ResourceCarrier("NG", 0.2)
Power = ResourceCarrier("Power", 0.0)
H2 = ResourceCarrier("Hydrogen", 0.0)
CO2 = ResourceEmit("CO2", 1.0)

# Function for setting up the system for testing an `AbstractElectrolyzer` node
function simple_graph_elec(;
    cap = FixedProfile(-25),        # Installed capacity [MW]
    opex_var = FixedProfile(5),     # Variable Opex
    opex_fixed = FixedProfile(100), # Fixed Opex
    input = Dict(Power => 1),       # Input: Ratio of Input flows to characteristic throughput
    output = Dict(H2 => 0.62),      # Ouput: Ratio of Output flow to characteristic throughput
    load_limits = LoadLimits(0, 1), # Minimum and maximum load
    degradation_rate = 0.1,         # Degradation rate
    stack_replacement_cost = FixedProfile(3e5),  # Stack replacement costs
    stack_lifetime = 60000,         # Stack lifetime in h
)

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
    elec = SimpleElectrolyzer(
        "PEM",
        cap,
        opex_var,
        opex_fixed,
        input,
        output,
        Data[],
        load_limits,
        degradation_rate,
        stack_replacement_cost,
        stack_lifetime
    )

    resources = [Power, H2, CO2]
    ops = SimpleTimes(5, 2)
    T = TwoLevel(2, 2, ops; op_per_strat=10)

    nodes = [source, elec, sink]
    links = [
        Direct(12, source, elec)
        Direct(23, elec, sink)
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

# Test that the fields of a `AbstractElectrolyzenr` are correctly checked
# - EMB.check_node(n::AbstractElectrolyzer, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
@testset "Test checks - AbstractElectrolyzer" begin

    # Test that a wrong capacity is caught by the checks
    @test_throws AssertionError simple_graph_elec(cap=FixedProfile(-25))

    # Test that a wrong fixed OPEX is caught by the checks
    @test_throws AssertionError simple_graph_elec(;opex_var=FixedProfile(5))

    # Test that a wrong input dictionary is caught by the checks
    @test_throws AssertionError simple_graph_elec(;input=Dict(Power => -1))

    # Test that a wrong output dictionary is caught by the checks
    @test_throws AssertionError simple_graph_elec(;output=Dict(H2 => -0.62))

    # Test that a wrong minimum load is caught by the checks
    @test_throws AssertionError simple_graph_elec(;load_limits=LoadLimits(-0.5, 1.0))

    # Test that a wrong maximum load is caught by the checks
    @test_throws AssertionError simple_graph_elec(;load_limits=LoadLimits(1.5, 1.0))

    # Test that a wrong degradation rate load is caught by the checks
    @test_throws AssertionError simple_graph_elec(;degradation_rate=-0.1)
    @test_throws AssertionError simple_graph_elec(;degradation_rate=100)

    # Test that a wrong stack replacement profile is caught by the checks
    stack_replacement_cost = FixedProfile(-5)
    @test_throws AssertionError simple_graph_elec(;stack_replacement_cost)
    stack_replacement_cost = StrategicProfile([10])
    @test_throws AssertionError simple_graph_elec(;stack_replacement_cost)
    stack_replacement_cost = OperationalProfile([10])
    @test_throws AssertionError simple_graph_elec(;stack_replacement_cost)

    # Test that a wrong lifetime is caught by the checks
    @test_throws AssertionError simple_graph_elec(;stack_lifetime=-10)
end

# Function for setting up the system for testing a `Reformer` node
function simple_graph_ref(;
    cap = FixedProfile(-25),  # Installed capacity [MW]
    opex_var = FixedProfile(5),    # Variable Opex
    opex_fixed = FixedProfile(100),  # Fixed Opex
    input = Dict(NG => 1.36),   # Input: Ratio of Input flows to characteristic throughput
    output = Dict(H2 => 1.0),   # Ouput: Ratio of Output flow to characteristic throughput
    load_limits = LoadLimits(0, 1),   # Minimum and maximum load
    startup = CommitParameters(FixedProfile(1), FixedProfile(1)),
    shutdown = CommitParameters(FixedProfile(1), FixedProfile(1)),
    offline = CommitParameters(FixedProfile(1), FixedProfile(1)),
    rate_limit = RampNone(),    # Rate of change parameter
)

    # Used source, reformer, and sink
    source = RefSource(
        "source",
        FixedProfile(4),
        FixedProfile(10),
        FixedProfile(0),
        Dict(NG => 1),
    )

    reformer = Reformer(
        "Reformer",
        cap,
        opex_var,
        opex_fixed,
        input,
        output,
        Data[],
        load_limits,
        startup,
        shutdown,
        offline,
        rate_limit,
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

    nodes = [source, reformer, sink]
    links = [
        Direct(12, source, reformer)
        Direct(23, reformer, sink)
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

# Test that the fields of an `AbstractReformer` are correctly checked
# - EMB.check_node(n::AbstractReformer, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
@testset "Test checks - AbstractReformer" begin

    # Test that a wrong capacity is caught by the checks
    @test_throws AssertionError simple_graph_ref(;cap=FixedProfile(-25))

    # Test that a wrong fixed OPEX is caught by the checks
    @test_throws AssertionError simple_graph_ref(;opex_fixed=FixedProfile(-100))

    # Test that a wrong input dictionary is caught by the checks
    @test_throws AssertionError simple_graph_ref(;input=Dict(NG => -1))

    # Test that a wrong output dictionary is caught by the checks
    @test_throws AssertionError simple_graph_ref(;output=Dict(H2 => -1.0))

    # Test that a wrong minimum load is caught by the checks
    @test_throws AssertionError simple_graph_ref(;load_limits=LoadLimits(-0.5, 1.0))

    # Test that a wrong maximum load is caught by the checks
    @test_throws AssertionError simple_graph_ref(;load_limits=LoadLimits(1.5, 1.0))

    # Test that a wrong unit commitment times are caught by the checks
    commit_param = CommitParameters(FixedProfile(-1), FixedProfile(1))
    @test_throws AssertionError simple_graph_ref(;startup=commit_param)
    @test_throws AssertionError simple_graph_ref(;shutdown=commit_param)
    @test_throws AssertionError simple_graph_ref(;offline=commit_param)

    # Test that a wrong profiles for minimum time of unit commitment are caught by the checks
    # - check_commitment_profile()
    startup = CommitParameters(FixedProfile(1), OperationalProfile([10]))
    @test_throws AssertionError simple_graph_ref(;startup)
    startup = CommitParameters(FixedProfile(1), StrategicProfile([OperationalProfile([10])]))
    @test_throws AssertionError simple_graph_ref(;startup)
    startup = CommitParameters(FixedProfile(1), FixedProfile(-5))
    @test_throws AssertionError simple_graph_ref(;startup)
    startup = CommitParameters(FixedProfile(1), StrategicProfile([-5]))
    @test_throws AssertionError simple_graph_ref(;startup)
    startup = CommitParameters(FixedProfile(1), StrategicProfile([10, 10]))
    @test_throws AssertionError simple_graph_ref(;startup)

    # Test that a wrong rate of change value is caught by the checks
    @test_throws AssertionError simple_graph_ref(;rate_limit=RampBi(FixedProfile(-1)))
    @test_throws AssertionError simple_graph_ref(;rate_limit=RampBi(FixedProfile(1.5)))
end

# Function for setting up the system for testing a `SimpleHydrogenStorage` node
function simple_graph_simple_stor(;
    charge_cap = FixedProfile(10),          # Installed capacity [MW]
    level_cap = FixedProfile(1000),         # Installed capacity [MWh]
    charge_opex_fixed = FixedProfile(5),    # Fixed Opex
    level_opex_fixed = FixedProfile(5),     # Fixed Opex
    input = Dict(H2 => 1.0),    # Input: Ratio of Input flows to characteristic throughput
    output = Dict(H2 => 1.0),   # Ouput: Ratio of Output flow to characteristic throughput
    discharge_charge = 2.0,     # Maximum discharge rate to charge capacity ratio
    level_charge = 100.0,       # Maximum level capacity to charge capacity ratio
)

    # Used source, reformer, and sink
    source = RefSource(
        "source",
        FixedProfile(4),
        FixedProfile(10),
        FixedProfile(0),
        Dict(H2 => 1),
    )

    storage = SimpleHydrogenStorage{CyclicStrategic}(
        "Storage",
        StorCapOpexFixed(charge_cap, charge_opex_fixed),
        StorCapOpexFixed(level_cap, level_opex_fixed),
        H2,
        input,
        output,
        discharge_charge,
        level_charge,
    )

    sink = RefSink(
        "sink",
        FixedProfile(3),
        Dict(:surplus => FixedProfile(4), :deficit => FixedProfile(100)),
        Dict(H2 => 1),
    )

    resources = [H2, CO2]
    ops = SimpleTimes(1, 2)
    T = TwoLevel(1, 2, ops; op_per_strat=10)

    nodes = [source, storage, sink]
    links = [
        Direct(12, source, storage)
        Direct(23, storage, sink)
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
# - EMB.check_node(n::SimpleHydrogenStorage, 𝒯, modeltype::EnergyModel, check_timeprofiles::Bool)
@testset "Test checks - SimpleHydrogenStorage" begin

    # Test that a wrong capacity is caught by the checks
    @test_throws AssertionError simple_graph_simple_stor(;charge_cap=FixedProfile(-25))
    @test_throws AssertionError simple_graph_simple_stor(;level_cap=FixedProfile(-25))

    # Test that a wrong fixed OPEX is caught by the checks
    @test_throws AssertionError simple_graph_simple_stor(;charge_opex_fixed=FixedProfile(-100))
    @test_throws AssertionError simple_graph_simple_stor(;level_opex_fixed=FixedProfile(-100))

    # Test that a wrong input dictionary is caught by the checks
    @test_throws AssertionError simple_graph_simple_stor(;input=Dict(H2 => -1))

    # Test that a wrong output dictionary is caught by the checks
    @test_throws AssertionError simple_graph_simple_stor(;output=Dict(H2 => -1.0))

    # Test that a wrong discharge to charge ratio is caught by the checks
    @test_throws AssertionError simple_graph_simple_stor(;discharge_charge=-0.5)

    # Test that a wrong level to charge ratio is caught by the checks
    @test_throws AssertionError simple_graph_simple_stor(;level_charge=-0.5)
    @test_throws AssertionError simple_graph_simple_stor(;level_charge=1000.0)
end
# Set the global again to false
EMB.TEST_ENV = false
