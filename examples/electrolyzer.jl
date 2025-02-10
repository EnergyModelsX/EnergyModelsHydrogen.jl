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
    generate_electrolyzer_example_data()

Generate the data for an example consisting of a simple electrolyzer system.
The electrolyzer experiences stack degradation and replacement in some strategic periods.
"""
function generate_electrolyzer_example_data()
    @info "Generate case data - Electrolyzer example"

    # Define the different resources and their emission intensity in t CO₂/MWh
    Power = ResourceCarrier("Power", 0.0)
    H2    = ResourceCarrier("H2", 0.0)
    CO2   = ResourceEmit("CO2", 1.0)
    products = [Power, H2, CO2]

    # Variables for the individual entries of the time structure
    op_duration = 2 # Each operational period has a duration of 2 h
    op_number = 5   # There are in total 5 operational periods in each strategic period
    operational_periods = SimpleTimes(op_number, op_duration)

    # The total time within a strategic period is given by 8760 h
    # This implies that the individual operational period are scaled:
    # Each operational period is scaled with a factor of 8760/2/5 = 876
    op_per_strat = 8760

    # Creation of the time structure and global data
    sp_duration = 2 # Each strategic period has a duration of 2 a
    sp_number = 8   # There are in total 8 strategic periods
    T = TwoLevel(sp_number, sp_duration, operational_periods; op_per_strat)

    # Creation of the model type with global data
    model = OperationalModel(Dict(CO2 => FixedProfile(0)), Dict(CO2 => FixedProfile(0)), CO2)

    # Create the individual test nodes, corresponding to a system with an electricity (1)
    # source [1], aen electrolyzer plant (2), and a hydrogen demand (4).
    nodes = [
        RefSource(
            "electricity source",   # Node id
            FixedProfile(100),      # Installed capacity in MW
            FixedProfile(30),       # Variable OPEX in €/MWh
            FixedProfile(0),        # Fixed OPEX in €/MW/a
            Dict(Power => 1),       # Output from the node, in this case, Power
        ),
        Electrolyzer(
            "PEM",                  # Node id
            FixedProfile(100),      # Installed capacity in MW
            FixedProfile(5),        # Variable OPEX in €/MWh
            FixedProfile(0),        # Fixed OPEX in €/MW/a
            Dict(Power => 1),       # Input to the node with input ratio
            Dict(H2 => 0.69),       # Output from the node with output ratio
            # Lines above: This implies that the capacity is defined via the electricity
            # input as it is usually the case for electrolyzer
            Data[],                 # Data
            LoadLimits(0, 1),       # Minimum and maximum load
            0.1,                    # Stack degradation rate in %/1000 h
            FixedProfile(1.5e5),    # Stack replacement costs in €/MW
            65000,                  # Stack lifetime in h
        ),
        RefSink(
            "hydrogen demand",      # Node id
            FixedProfile(50),       # Required demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(100)),
            # Line above: Surplus and deficit penalty for the node in €/MWh
            Dict(H2 => 1),          # Energy carrier and corresponding ratio to demand
        ),
    ]

    # Connect all nodes for the overall energy/mass balance
    # Another possibility would be to instead couple the nodes with an `Availability` node
    links = [
        Direct("el_source-electrolyzer", nodes[1], nodes[2], Linear())
        Direct("electrolyzer-h2_demand", nodes[2], nodes[3], Linear())
    ]


    # Input data structure
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])
    return case, model
end

# Generate the case and model data and run the model
case, model = generate_electrolyzer_example_data()
optimizer = optimizer_with_attributes(SCIP.Optimizer, MOI.Silent() => true)
m = run_model(case, model, optimizer)

"""
    process_elec_results(m, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_elec_results(m, case)
    # Extract the nodes and the strategic periods from the data
    elect = get_nodes(case)[2]
    𝒯ᴵⁿᵛ = strategic_periods(get_time_struct(case))

    # Extract the first operational period of each strategic period
    first_op = [first(t_inv) for t_inv ∈ 𝒯ᴵⁿᵛ]

    # Electrolyzer variables
    stack_replacement = JuMP.Containers.rowtable(   # Stack replacement
        value,
        m[:elect_stack_replace_b][elect, :];
        header=[:t, :stack_replacement]
    )
    prev_usage = JuMP.Containers.rowtable(          # Previous usage up to this state
        value,
        m[:elect_prev_use][elect, first_op];
        header=[:t, :previous_usage]
    )
    penalty = JuMP.Containers.rowtable(             # Efficiency penalty
        value,
        m[:elect_efficiency_penalty][elect, first_op];
        header=[:t, :penalty]
    )


    # Set up the individual named tuples as a single named tuple
    table = [(
            t = repr(con_1.t), stack_replacement = round(Int64, con_1.stack_replacement),
            previous_usage = round(con_2.previous_usage; digits=2),
            penalty = round(con_3.penalty; digits=4),
        ) for (con_1, con_2, con_3) ∈ zip(stack_replacement, prev_usage, penalty)
    ]
    return table
end

# Display some results
table = process_elec_results(m, case)

@info(
    "Individual results from the electrolyzer node:\n" *
    "(previous_usage (in 1000 h) and penalty in the first operational period of the strategic period)\n" *
    "Stack replacement is occuring in strategic period 5 resulting in a reset of the\n" *
    "previous usage and the efficiency penalty."
)
pretty_table(table)
