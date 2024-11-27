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
    generate_h2_storage_example_data()

Generate the data for an example consisting of an electricity source, a hydrogen source,
a hydrogen storage, and a time varying hydrogen demand

It illustrates the dependency of the electricity requirement on the storage level, and hence,
utilizes the bilinear-piecewise linear formulation.
"""
function generate_h2_storage_example_data()
    @info "Generate case data - Reformer example"

    # Define the different resources and their emission intensity in t CO₂/MWh
    Power = ResourceCarrier("Power", 0.0)
    H2    = ResourceCarrier("H2", 0.0)
    CO2   = ResourceEmit("CO2", 1.0)
    products = [Power, H2, CO2]

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
    h2_price = OperationalProfile([ones(10)*30; ones(5)*50; ones(5)*70; 40; 40; 45; 45; 40])

    # Create the individual test nodes, corresponding to a system with an electricity (1)
    # and hydrogen (2) source, a hydrogen storage (3), and a hydrogen demand (4).
    nodes = [
        RefSource(
            "electricity source",   # Node id
            FixedProfile(10),       # Installed capacity in MW
            FixedProfile(30),       # Variable OPEX in €/MWh
            FixedProfile(0),        # Fixed OPEX in €/MW/a
            Dict(Power => 1),       # Output from the node, in this case, Power
        ),
        RefSource(
            "hydrogen source",      # Node id
            FixedProfile(40),       # Installed capacity in MW
            h2_price,               # Variable OPEX in €/MWh
            FixedProfile(0),        # Fixed OPEX in €/MW/a
            Dict(H2 => 1),          # Output from the node, in this case, hydrogen (H2)
        ),
        HydrogenStorage{CyclicStrategic}(
            "hydrogen storage",
            StorCap(FixedProfile(10)),   # Charge parameters, in this case only capacity in MW
            StorCap(FixedProfile(200)), # Level parameters, in this case, only capacity in MWh
            H2,                 # Stored resource
            Power,              # Electricity resource
            2.0,                # Discharge to charge ratio
            20.0,               # Level to charge ratio
            30.0,               # Minimum pressure in the storage vessel in bar
            45.0,               # Charging pressure in the storage vessel in bar
            150.0,              # Maximum pressure in the storage vessel in bar
        ),
        RefSink(
            "hydrogen demand",      # Node id
            h2_demand,              # Required demand in MW
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(150)),
            # Line above: Surplus and deficit penalty for the node in €/MWh
            Dict(H2 => 1),          # Energy carrier and corresponding ratio to demand
        ),
    ]

    # Connect all nodes for the overall energy/mass balance
    # Another possibility would be to instead couple the nodes with an `Availability` node
    links = [
        Direct("el_source-h2_storage", nodes[1], nodes[3], Linear())
        Direct("h2_source-h2_storage", nodes[2], nodes[3], Linear())
        Direct("h2_source-h2_demand",  nodes[2], nodes[4], Linear())
        Direct("h2_storage-h2_demand", nodes[3], nodes[4], Linear())
    ]

    # WIP data structure
    case = Dict(
        :nodes => nodes,
        :links => links,
        :products => products,
        :T => T,
    )
    return case, model
end

"""
    process_h2_stor_results(m, case)

Function for processing the results to be represented in the a table afterwards.
"""
function process_h2_stor_results(m, case)
    # Extract the nodes and the first strategic period from the data
    supply, h2_stor = case[:nodes][[2,3]]           # Extract the h2 supply and storage node
    Power = case[:products][1]                      # Extract the electricity resource
    sp1 = collect(strategic_periods(case[:T]))[1]   # Extract the first strategic period

    # Extracting the different pressures and calculate the multiplier
    pₘᵢₙ = EMH.p_min(h2_stor)
    pₘₐₓ = EMH.p_max(h2_stor)
    mult_p = (pₘₐₓ-pₘᵢₙ) / capacity(level(h2_stor), sp1[1])

    # h2 supply variables
    supply = JuMP.Containers.rowtable(              # Capacity utilization
        value,
        m[:cap_use][supply, collect(sp1)];
        header=[:t, :h2_supply]
    )

    # h2 storage variables
    stor_level = JuMP.Containers.rowtable(              # Storage level
        value,
        m[:stor_level][h2_stor, collect(sp1)];
        header=[:t, :storage_level]
    )
    stor_charge = JuMP.Containers.rowtable(             # Storage charge
        value,
        m[:stor_charge_use][h2_stor, collect(sp1)];
        header=[:t, :storage_charge]
    )
    el_demand = JuMP.Containers.rowtable(               # Storage electricity demand
        value,
        m[:flow_in][h2_stor, collect(sp1), Power];
        header=[:t, :el_demand]
    )
    stor_discharge = JuMP.Containers.rowtable(          # Storage discharge
        value,
        m[:stor_discharge_use][h2_stor, collect(sp1)];
        header=[:t, :storage_discharge]
    )
    pressure = JuMP.Containers.rowtable(                # Storage pressure
        value,
        m[:stor_level][h2_stor, collect(sp1)].*mult_p .+ pₘᵢₙ;
        header=[:t, :storage_pressure]
    )

    # Set up the individual named tuples as a single named tuple
    table = [(
            t = repr(con_1.t), supply = round(con_1.h2_supply, digits=2),
            storage_level = round(con_2.storage_level, digits=2),
            storage_charge = round(con_3.storage_charge, digits=2),
            electricity_demand = round(con_4.el_demand, digits=2),
            storage_discharge = round(con_5.storage_discharge, digits=2),
            storage_pressure = round(con_6.storage_pressure, digits=2),
        ) for (con_1, con_2, con_3, con_4, con_5, con_6) ∈
        zip(supply, stor_level, stor_charge, el_demand, stor_discharge, pressure)
    ]
    return table
end

# Generate the case and model data and run the model
case, model = generate_h2_storage_example_data()
optimizer = optimizer_with_attributes(
    SCIP.Optimizer,
    "limits/gap" => 1e-3,
)
m = run_model(case, model, optimizer)

# Display some results
table = process_h2_stor_results(m, case)
@info(
    "Operational periods 1-5 illustrate the storage of hydrogen at low prices resulting in an\n" *
    "increase in the storage level of 20 per operational period.\n" *
    "Note that electricity is not required in the first operational period as the charge pressure\n" *
    "is higher than the storage pressure."
)
pretty_table(table[1:5])

@info(
    "Operational periods 6-10 illustrate the storage of hydrogen at low prices resulting in an\n" *
    "increase in the storage level of 20 per operational period.\n" *
    "The electricity demand is increasing given the raising storage level (and hence, pressure).\n" *
    "The final storage level is the maximum possible level."
)
pretty_table(table[6:10])

@info(
    "In operational periods 11-15, the demand is entirely satisfied by the supply.\n" *
    "The storage level (and hence, pressure) remains unchanged."
)
pretty_table(table[11:15])

@info(
    "In operational periods 16-20, the supply is expensive and not able to satisfy the demand.\n" *
    "Hence, the storage is discharging at the maximum discharge rate (due to its limits given\n" *
    "by the field `discharge_charge`) resulting in an empty storage.\n" *
    "The supply is operating below its capacity due to its high price."
)
pretty_table(table[16:20])

@info(
    "In operational periods 21-25, the supply is sufficient to satisfy the demand.\n" *
    "The partial increase in storage level is due to the lower prices in period 21 and 25."
)
pretty_table(table[21:25])
