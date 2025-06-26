"""
    build_run_reformer_model(params)

Returns `(JuMP.model, case)` dictionary of default model that uses a reformer of the type
defined in the package `EnergyModelsHydrogen`.
"""
function build_run_reformer_model(params)
    # Step 1: Declare the overall time structure.
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
    NG    = ResourceCarrier("NG", 0.2)
    H2    = ResourceCarrier("H2", 0.0)
    CO2   = ResourceEmit("CO2", 1.0)

    # Step 3: Declare products:
    products = Array{EMB.Resource}([Power, NG, H2, CO2])

    ng_source = RefSource(
        "NG source",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(9),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(NG => 1),   # Ratio of output to characteristic throughput
    )

    el_source = RefSource(
        "El source",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(30),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(Power => 1),   # Ratio of output to characteristic throughput
    )

    if (typeof(params[:data][1]) <: EMB.CaptureData)
        output = Dict(H2 => 1.0, CO2 => 0)
    else
        output = Dict(H2 => 1.0)
    end
    reformer = Reformer(
        "reformer",
        FixedProfile(50),   # Installed capacity [MW]
        FixedProfile(5),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(NG => 1.25, Power => 0.11),   # Input: Ratio of Input flows to characteristic throughput
        output,             # Ouput: Ratio of Output flow to characteristic throughput
        params[:data],      # ExtensionData

        params[:load_limits], # Minimum and maximum load

        # Hourly cost for startup [€/MW/h] and startup time [h]
        CommitParameters(FixedProfile(0.2), FixedProfile(5)),
        # Hourly cost for shutdown [€/MW/h] and shutdown time [h]
        CommitParameters(FixedProfile(0.2), FixedProfile(5)),
        # Hourly cost when offline [€/MW/h] and minimum off time [h]
        CommitParameters(FixedProfile(0.02), FixedProfile(10)),

        params[:rate_change], # Rate of change limit [-/h]
    )

    H2_sink = RefSink(
        "h2_demand",
        params[:demand],   # Demand [MW]
        Dict(
            :surplus => FixedProfile(0),
            :deficit => params[:deficit_cost]
            ), # Penalty dict
        Dict(H2 => 1),      # Ratio of sink flows to sink characteristic throughput.
    )

    nodes= [ng_source, el_source, reformer, H2_sink]

    # Step 5: Declare the links (graph connections)
    links = [
        Direct("ng_source-ref", ng_source, reformer)
        Direct("el_source-ref", el_source, reformer)
        Direct("ref-h2_sink", reformer, H2_sink)
    ]


    # Step 6: Add the CO2 sink, if required
    if (typeof(params[:data][1]) <: EMB.CaptureData)
        CO2_sink = RefSink(
            "CO2 sink",
            FixedProfile(0),
            Dict(:surplus => FixedProfile(9.1), :deficit => FixedProfile(20)),
            Dict(CO2 => 1),
        )
        push!(nodes, CO2_sink)
        append!(links, [Direct("ref-co2_stor", reformer, CO2_sink)])
    end


    # Step 7: Include all parameters in the input data structure
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])

    # B Formulating and running the optimization problem

    if EMI.has_investment(reformer)
        model = InvestmentModel(
            Dict(CO2 => FixedProfile(params[:co2_limit])),
            Dict(CO2 => FixedProfile(0)),
            CO2,
            0.07,
        )
    else
        model = OperationalModel(
            Dict(CO2 => FixedProfile(params[:co2_limit])),
            Dict(CO2 => FixedProfile(0)),
            CO2,
        )
    end
    m = create_model(case, model)

    @debug "Optimization model: $(m)"

    set_optimizer(m, OPTIMIZER)

    optimize!(m)
    return (m, case)
end

"""
    reformer_test(m, case, params)

Test function for analysing that the reformer is producing at least in a single period.
"""
function reformer_test(m, case, params)

    𝒯 = get_time_struct(case)
    ref = get_nodes(case)[3]

    @test termination_status(m) == MOI.OPTIMAL
    @test sum(value.(m[:ref_on_b][ref, t]) for t ∈ 𝒯) > 0
    @test sum(value.(m[:cap_use][ref, t]) for t ∈ 𝒯) > 0
end


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
