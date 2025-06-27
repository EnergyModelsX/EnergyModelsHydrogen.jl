const TEST_ATOL = 1e-6
⪆(x, y) = x > y || isapprox(x, y; atol = TEST_ATOL)
⪅(x, y) = x < y || isapprox(x, y; atol = TEST_ATOL)

const OPTIMIZER = optimizer_with_attributes(
    SCIP.Optimizer,
    "limits/gap" => 1e-4,
    MOI.Silent() => true,
)

"""
Returns `(JuMP.model, case)` dictionary of default model that uses an electrolyzer
of the type defined in the package `EnergyModelsHydrogen`.
"""
function build_run_electrolyzer_model(params; cap=FixedProfile(100))
    # Step 1: Declare the overall time structure.
    if params[:rep]
        T = TwoLevel(
            params[:num_sp],        # Number of strategic periods with a
            2,                      # duration of 2.
            RepresentativePeriods(
                2,                      # Number of representative periods
                8760,                   # Total duration in a strategic period
                [0.5, 0.5],             # Probability of each representative period
                [
                    SimpleTimes(Int(params[:num_op]/2), Int(8760/4/params[:num_op]*2)),
                    SimpleTimes(Int(params[:num_op]/2), Int(8760/4/params[:num_op]*2)),
                ]
            );
            op_per_strat=8760,      # Total duration in a strategic period
        )
    else
        T = TwoLevel(
            params[:num_sp],        # Number of strategic periods with a
            2,                      # duration of 2.
            SimpleTimes(
                params[:num_op],        # Number of operational periods with a
                8760/params[:num_op]    # total duration of 8760 h.
            );
            op_per_strat=8760,      # Total duration in a strategic period
        )
    end

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = ResourceCarrier("Power", 0.0)
    H2    = ResourceCarrier("H2", 0.0)
    CO2   = ResourceEmit("CO2", 1.0)

    # Step 3: Declare products:
    products = Array{EMB.Resource}([Power, H2])

    # Step 4: Declare nodes:
    Central_node = GenAvailability("CN", products)

    Wind_turbine = RefSource(
        "WT",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(0),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(Power => 1),   # Ratio of output to characteristic throughput
    )

    if params[:simple]
        PEM_electrolyzer = SimpleElectrolyzer(
            "PEM",
            cap,                # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(0),    # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            params[:data],      # ExtensionData
            LoadLimits(0, 1),   # Minimum and maximum load
            params[:degradation_rate],  # Degradation rate
            params[:stack_cost],        # Stack replacement costs
            params[:stack_lifetime],    # Stack lifetime in h
        )
    else
        PEM_electrolyzer = Electrolyzer(
            "PEM",
            cap,                # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(0),    # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            params[:data],      # ExtensionData
            LoadLimits(0, 1),   # Minimum and maximum load
            params[:degradation_rate],  # Degradation rate
            params[:stack_cost],        # Stack replacement costs
            params[:stack_lifetime],    # Stack lifetime in h
        )
    end

    End_hydrogen_consumer = RefSink(
        "Con",
        FixedProfile(50),   # Installed capacity [MW]
        Dict(
            :surplus => FixedProfile(0),
            :deficit => params[:deficit_cost]
            ), # Penalty dict
        Dict(H2 => 1),      # Ratio of sink flows to sink characteristic throughput.
    )


    nodes= [Central_node, Wind_turbine, PEM_electrolyzer, End_hydrogen_consumer]

    # Step 5: Declare the links (graph connections)
    links = [
        Direct("l1", Wind_turbine, Central_node)
        Direct("l2", Central_node, PEM_electrolyzer)
        Direct("l3", PEM_electrolyzer, Central_node)
        Direct("l4", Central_node, End_hydrogen_consumer)
    ]

    # Step 6: Include all parameters in the input data structure
    case = Case(T, products, [nodes, links], [[get_nodes, get_links]])

    # B Formulating and running the optimization problem
    if EMI.has_investment(PEM_electrolyzer)
        model = InvestmentModel(Dict(CO2 => FixedProfile(0)), Dict(CO2 => FixedProfile(0)), CO2, 0.07)
    else
        model = OperationalModel(Dict(CO2 => FixedProfile(0)), Dict(CO2 => FixedProfile(0)), CO2)
    end
    m = create_model(case, model)

    @debug "Optimization model: $(m)"

    set_optimizer(m, OPTIMIZER)

    optimize!(m)

    if (JuMP.termination_status(m) == OPTIMAL)
        @debug "Solution found"
        @debug "objective value $(objective_value(m))"
        @debug "cap_inst $(value.(m[:cap_inst]))"
        @debug "cap_use $(value.(m[:cap_use]))"
        @debug "sink_surplus $(value.(m[:sink_surplus]))"
        @debug "sink_deficit $(value.(m[:sink_deficit]))"
        @debug "flow_in $(value.(m[:flow_in]))"
        @debug "flow_out $(value.(m[:flow_out]))"
        @debug "elect_on_b $(value.(m[:elect_on_b]))"
        @debug "elect_prev_use $(value.(m[:elect_prev_use]))"
        @debug "elect_use_sp $(value.(m[:elect_use_sp]))"
        @debug "elect_stack_replace_b $(value.(m[:elect_stack_replace_b]))"
        @debug "elect_efficiency_penalty $(value.(m[:elect_efficiency_penalty]))"
    end
    return (m, case)
end

"""
    penalty_test(m, case, params)

Test function for analysing that the previous operational period has an efficiency
penalty that is at least as large as the one of the current period as well as that
the previous usage with stack replacement is correctly calculated.
"""
function penalty_test(m, case, params)

    # Reassign types and variables
    elect = get_nodes(case)[3]
    𝒯 = get_time_struct(case)
    𝒯ᴵⁿᵛ = strategic_periods(𝒯)
    penalty = m[:elect_efficiency_penalty]
    stack_replace = m[:elect_stack_replace_b][elect, :]

    # Calculation of the penalty
    @test sum(
            value.(penalty[elect, t]) ⪅ value.(penalty[elect, t_prev]) ||
            value.(penalty[elect, t]) ≈ value.(penalty[elect, t_prev])
            for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)
        ) == length(𝒯) - params[:num_sp] * (params[:rep]+1)
    @test all(
        value.(m[:elect_prev_use][elect, t]) ⪅ params[:stack_lifetime] for t ∈ 𝒯
    )
    @test all(
        value.(penalty[elect, t]) ≈
            1 - params[:degradation_rate]/100 * value.(m[:elect_prev_use][elect, t])
    for t ∈ 𝒯)

    # Test that the previous usage is correctly calculated
    @test all(isapprox(
        value.(m[:elect_prev_use_sp][elect, t_inv]),
        (
            value.(m[:elect_prev_use_sp][elect, t_inv_prev]) +
            value.(m[:elect_use_sp][elect, t_inv_prev]) * 2
        ) * (1 - value.(stack_replace[t_inv])),
        atol = TEST_ATOL)
    for (t_inv_prev, t_inv) ∈ withprev(𝒯ᴵⁿᵛ) if !isnothing(t_inv_prev))
end

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
