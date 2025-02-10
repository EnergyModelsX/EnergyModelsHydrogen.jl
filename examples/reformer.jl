using Pkg
# Activate the local environment including EnergyModelsHydrogen, SCIP, PrettyTables
Pkg.activate(@__DIR__)
# Use dev version if run as part of tests
haskey(ENV, "EMX_TEST") && Pkg.develop(path=joinpath(@__DIR__,".."))
# Install the dependencies.
Pkg.instantiate()

# Import the required packages
using EnergyModelsBase
using EnergyModelsHydrogen
using SCIP
using JuMP
using PrettyTables
using TimeStruct

const EMB = EnergyModelsBase
const EMH = EnergyModelsHydrogen
const TS = TimeStruct

"""
    generate_refomer_example_data()

Generate the data for an example consisting of an electricity source, a natural gas source,
a reformer with CO₂ capture, a time varying hydrogen demand, and CO₂ storage node, modelled,
as `RefSink` node

It illustrates the restrictions on the reformer node related to both shutdown, offline, and
startup times, as well as the minimum usage constraint.
"""
function generate_refomer_example_data()
    @info "Generate case data - Reformer example"

    # Define the different resources and their emission intensity in t CO₂/MWh
    Power = ResourceCarrier("Power", 0.0)
    NG    = ResourceCarrier("NG", 0.2)
    H2    = ResourceCarrier("H2", 0.0)
    CO2   = ResourceEmit("CO2", 1.0)
    products = [Power, NG, H2, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2 h
    op_number = 25  # There are in total 25 operational periods in each strategic period
    operational_periods = SimpleTimes(op_number, op_duration)

    # The total time within a strategic period is given by 8760 h
    # This implies that the individual operational period are scaled:
    # Each operational period is scaled with a factor of 8760/2/25 = 175.2
    op_per_strat = 8760

    # Creation of the time structure
    sp_duration = 1 # Each strategic period has a duration of 1 a
    sp_number = 1   # There is only a single strategic period
    T = TwoLevel(sp_number, sp_duration, operational_periods; op_per_strat)

    # Creation of the model type with global data
    model = OperationalModel(
        Dict(CO2 => FixedProfile(8760)),    # Emission cap for CO₂ in t/a
        Dict(CO2 => FixedProfile(0)),       # Emission price for CO₂ in €/t
        CO2,                                # CO₂ instance
    )

    # Specify the demand for hydrogen
    # The demand could also be specified directly in the node
    h2_demand = OperationalProfile([zeros(10); ones(5)*10; ones(5)*50; ones(5)*30])

    # Create the individual test nodes, corresponding to a system with an electricity (1)
    # and natural gas (2) source, a reformer plant (3), a hydrogen demand (4), and a CO₂
    # storage node (5). The CO₂ storage node is for simplicity modelled as a `RefSink` node.
    # This implies that it does not have a maximum storage level.
    nodes = [
        RefSource(
            "electricity source",   # Node id
            FixedProfile(100),      # Installed capacity in MW
            FixedProfile(30),       # Variable OPEX in €/MWh
            FixedProfile(0),        # Fixed OPEX in €/MW/a
            Dict(Power => 1),       # Output from the node, in this case, Power
        ),
        RefSource(
            "natural gas source",   # Node id
            FixedProfile(100),      # Installed capacity in MW
            FixedProfile(9),        # Variable OPEX in €/MWh
            FixedProfile(0),        # Fixed OPEX in €/MW/a
            Dict(NG => 1),          # Output from the node, in this case, natural gas (NG)
        ),
        Reformer(
            "reformer",             # Node id
            FixedProfile(50),       # Installed capacity in MW
            FixedProfile(5),        # Variable OPEX in €/MWh
            FixedProfile(0),        # Fixed OPEX in €/MW/a
            Dict(NG => 1.25, Power => 0.11),    # Input to the node with input ratio
            Dict(H2 => 1.0, CO2 => 0),          # Output from the node with output ratio
            # Line above: CO2 is required as output for variable definition, but the
            # value does not matter
            Data[CaptureEnergyEmissions(0.92)], # CO₂ capture rate  as fraction
            # The data vector above may also include, e.g., SingleInvData for inclusion of
            # investments

            LoadLimits(0.2, 1.0),   # Minimum and maximum load of the reformer as fraction

            # Hourly cost for startup [€/MW/h] and startup time [h]
            CommitParameters(FixedProfile(0.2), FixedProfile(5)),
            # Hourly cost for shutdown [€/MW/h] and shutdown time [h]
            CommitParameters(FixedProfile(0.2), FixedProfile(5)),
            # Hourly cost when offline [€/MW/h] and minimum off time [h]
            CommitParameters(FixedProfile(0.02), FixedProfile(10)),

            # Rate of change limit, corresponding to 10 % in both directions as fraction/h
            RampBi(FixedProfile(.1)),
        ),
        RefSink(
            "hydrogen demand",      # Node id
            h2_demand,              # Required demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(150)),
            # Line above: Surplus and deficit penalty for the node in €/MWh
            Dict(H2 => 1),          # Energy carrier and corresponding ratio to demand
        ),
        RefSink(
            "CO₂ storage",          # Node id
            FixedProfile(0),        # Demand in t/h
            Dict(:surplus => FixedProfile(9.1), :deficit => FixedProfile(20)),
            # Line above: Surplus and deficit penalty for the node in €/MWh
            Dict(CO2 => 1),         # Input to the CO₂ storage node
        ),
    ]

    # Connect all nodes for the overall energy/mass balance
    # Another possibility would be to instead couple the nodes with an `Availability` node
    links = [
        Direct("el_source-reformer", nodes[1], nodes[3], Linear())
        Direct("ng_source-reformer", nodes[2], nodes[3], Linear())
        Direct("reformer-h2_demand", nodes[3], nodes[4], Linear())
        Direct("reformer-co2_storage", nodes[3], nodes[5], Linear())
    ]

    # Input data structure
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])
    return case, model
end

"""
    process_ref_results(m, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_ref_results(m, case)
    # Extract the nodes and the first strategic period from the data
    reformer, demand = get_nodes(case)[[3,4]]          # Extract the reformer and demand node
    sp1 = collect(strategic_periods(get_time_struct(case)))[1]   # Extract the first strategic period

    # Reformer variables
    load = JuMP.Containers.rowtable(                # Capacity utilization
        value,
        m[:cap_use][reformer, collect(sp1)];
        header=[:t, :load]
    )
    online = JuMP.Containers.rowtable(              # Indicator for the online state
        value,
        m[:ref_on_b][reformer, collect(sp1)];
        header=[:t, :online]
    )
    startup = JuMP.Containers.rowtable(             # Indicator for the startup state
        value,
        m[:ref_start_b][reformer, collect(sp1)];
        header=[:t, :startup]
    )
    shutdown = JuMP.Containers.rowtable(            # Indicator for the shutdown state
        value,
        m[:ref_shut_b][reformer, collect(sp1)];
        header=[:t, :shutdown]
    )
    offline = JuMP.Containers.rowtable(             # Indicator for the offline state
        value,
        m[:ref_off_b][reformer, collect(sp1)];
        header=[:t, :offline]
    )


    # Sink variables
    surplus = JuMP.Containers.rowtable(             # Surplus of the node
        value,
        m[:sink_surplus][demand, collect(sp1)];
        header=[:t, :surplus]
    )


    # Set up the individual named tuples as a single named tuple
    table = [(
            t = con_1.t, load = con_1.load,
            startup = round(Int64, con_2.startup),
            online = round(Int64, con_3.online),
            shutdown = round(Int64, con_4.shutdown),
            offline = round(Int64, con_5.offline),
            surplus = con_6.surplus,
        ) for (con_1, con_2, con_3, con_4, con_5, con_6) ∈ zip(load, startup, online, shutdown, offline, surplus)
    ]
    return table
end

# Generate the case and model data and run the model
case, model = generate_refomer_example_data()
optimizer = optimizer_with_attributes(SCIP.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

# Display some results
table = process_ref_results(m, case)
@info(
    "Capacity usage of the reformer in the operational periods 1-5 illustrating the\n" *
    "transition form `shutdown` to `offline` state.\n" *
    "The system is in `shutdown` state due to the cyclic constraints imposed on the node."
)
pretty_table(table[1:5])
@info(
    "Capacity usage of the reformer in the operational periods 6-10 illustrating the\n" *
    "transition form `offline` to `startup` state."
)
pretty_table(table[6:10])
@info(
    "Capacity usage of the reformer in the operational periods 11-15 illustrating the\n" *
    "transition form `startup` to `online` state.\n" *
    "In addition, we can see that the `Reformer` produces more than required (surplus)\n" *
    "to avoid a deficit in later periods caused by the ramp up constraints."
)
pretty_table(table[11:15])
@info(
    "Capacity usage of the reformer in the operational periods 16-20 illustrating the\n"*
    "maximum production in the `online` state."
)
pretty_table(table[16:20])
@info(
    "Capacity usage of the reformer in the operational periods 21-25 illustrating the\n"*
    "ramping down in the `online` state with a surplus in operational period 21 due to\n" *
    "the ramp down constraint.\n" *
    "Note that the final capacity is higher than the minimum capacity as the reformer\n" *
    "is allowed to go offline from any state."
)
pretty_table(table[21:25])
