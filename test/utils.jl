"""
    build_run_h2_storage_model(params)

Returns `(JuMP.model, case)` dictionary of default model that uses a H₂ storage node of the
type defined in the package `EnergyModelsHydrogen`.
"""
function build_run_h2_storage_model(params)
    # Step 1: Declare the overall time structure
    if params[:rep]
        T = TwoLevel(
            1,                          # Number of strategic periods
            1,                          # Duration of each strategic period
            RepresentativePeriods(
                2,                      # Number of representative periods
                8760,                   # Total duration in a strategic period
                [0.5, 0.5],             # Probability of each representative period
                [
                    SimpleTimes(Int(params[:num_op]/2), params[:dur_op]),
                    SimpleTimes(Int(params[:num_op]/2), params[:dur_op]),
                ]
            );
            op_per_strat=8760,      # Total duration in a strategic period
        )
    else
        T = TwoLevel(
            1,                      # Number of strategic periods
            1,                      # Duration of each strategic period
            SimpleTimes(
                params[:num_op],    # Number of operational periods
                params[:dur_op],    # Duration of each operational period
            );
            op_per_strat=8760,      # Total duration in a strategic period
        )
    end

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = ResourceCarrier("Power", 0.0)
    H2    = ResourceCarrier("H2", 0.0)
    CO2   = ResourceEmit("CO2", 1.0)

    # Step 3: Declare products:
    products = Array{EMB.Resource}([Power, H2, CO2])

    h2_source = RefSource(
        "H2 source",
        params[:supply],    # Installed supply of hydrogen [MW]
        FixedProfile(9),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(H2 => 1),      # Ratio of output to characteristic throughput
    )

    el_source = RefSource(
        "El source",
        FixedProfile(5),    # Installed capacity [MW]
        FixedProfile(30),   # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(Power => 1),   # Ratio of output to characteristic throughput
    )

    if params[:simple]
        h2_storage = SimpleHydrogenStorage{CyclicStrategic}(
            "H₂ storage",
            StorCapOpexVar(FixedProfile(5), FixedProfile(1)),   # Charge parameters
            StorCap(FixedProfile(100)),                         # Level parameters
            H2,                 # Stored resource
            Dict(H2 => 1, Power => 0.01), # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 1),      # Ouput: Ratio of Output flow to characteristic throughput
            2.0,                # Discharge to charge ratio
            20.0,               # Level to charge ratio
        )
    else
        h2_storage = HydrogenStorage{CyclicStrategic}(
            "Storage",
            StorCapOpexVar(FixedProfile(5), FixedProfile(1)),   # Charge parameters
            StorCap(FixedProfile(100)),                         # Level parameters
            H2,                 # Stored resource
            Power,              # Electricity resource
            2.0,                # Discharge to charge ratio
            20.0,               # Level to charge ratio
            params[:p_min],
            params[:p_charge],
            params[:p_max],
        )
    end

    h2_sink = RefSink(
        "h2_demand",
        params[:demand],   # Demand [MW]
        Dict(
            :surplus => FixedProfile(0),
            :deficit => FixedProfile(200),
            ), # Penalty dict
        Dict(H2 => 1),      # Ratio of sink flows to sink characteristic throughput.
    )

    nodes= [h2_source, el_source, h2_storage, h2_sink]

    # Step 5: Declare the links (graph connections)
    links = [
        Direct("h2_source-h2_stor", h2_source, h2_storage)
        Direct("el_source-h2_stor", el_source, h2_storage)
        Direct("h2_stor-h2_sink", h2_storage, h2_sink)
        Direct("h2_source-h2_sink", h2_source, h2_sink)
    ]

    # Step 7: Include all parameters in parameters in the input data structure
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])

    # B Formulating and running the optimization problem
    model = OperationalModel(
        Dict(CO2 => FixedProfile(10)),
        Dict(CO2 => FixedProfile(0)),
        CO2,
    )
    m = create_model(case, model)

    @debug "Optimization model: $(m)"

    set_optimizer(m, OPTIMIZER)

    optimize!(m)
    return (m, case)
end
