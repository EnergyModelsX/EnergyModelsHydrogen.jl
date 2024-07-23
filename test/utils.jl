
const TEST_ATOL = 1e-6
⪆(x, y) = x > y || isapprox(x, y; atol = TEST_ATOL)
⪅(x, y) = x < y || isapprox(x, y; atol = TEST_ATOL)

const OPTIMIZER = optimizer_with_attributes(SCIP.Optimizer,
                                         MOI.Silent() => true)

"""
Returns `(JuMP.model, case)` dictionary of default model that uses an electrolyzer
of the type defined in the package `EnergyModelsHydrogen`.
"""
function build_run_electrolyzer_model(params; cap=FixedProfile(100))
    @debug "Degradation electrolyzer model."
    # Step 1: Defining the overall time structure.
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

    # Step 3: Defining products:
    products = Array{EMB.Resource}([Power, H2])

    # Step 4: Defining nodes:
    Central_node = GenAvailability("CN", products)

    Wind_turbine = RefSource(
        "WT",
        FixedProfile(100),  # Installed capacity [MW]
        FixedProfile(0),    # Variable Opex
        FixedProfile(0),    # Fixed Opex
        Dict(Power => 1),   # Ratio of output to characteristic throughput
    )

    if params[:simple]
        PEM_electrolyzer = EMH.SimpleElectrolyzer(
            "PEM",
            cap,                # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(0),    # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            params[:data],              # Data
            0,                          # Min load
            1,                          # Max load
            params[:degradation_rate],  # Degradation rate
            params[:stack_cost],        # Stack replacement costs
            params[:stack_lifetime],    # Stack lifetime in h
        )
    else
        PEM_electrolyzer = EMH.Electrolyzer(
            "PEM",
            cap,                # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(0),    # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            params[:data],              # Data
            0,                          # Min load
            1,                          # Max load
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

    # Step 5: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links = [
        Direct("l1", Wind_turbine, Central_node, Linear())
        Direct("l2", Central_node, PEM_electrolyzer, Linear())
        Direct("l3", PEM_electrolyzer, Central_node, Linear())
        Direct("l4", Central_node, End_hydrogen_consumer, Linear())
    ]

    # Step 6: Include all parameters in a single dictionary
    case = Dict(
        :T => T,
        :products => products,
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{EMB.Link}(links),
    )

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
        @debug "elect_previous_usage $(value.(m[:elect_previous_usage]))"
        @debug "elect_usage_sp $(value.(m[:elect_usage_sp]))"
        @debug "elect_stack_replacement_sp_b $(value.(m[:elect_stack_replacement_sp_b]))"
        @debug "elect_efficiency_penalty $(value.(m[:elect_efficiency_penalty]))"
    end
    return (m, case)
end

"""
    penalty_test(m, case, params)

Test function for analysing that the previous operational period has an efficiency
penalty that is at least as large as the one of the current period as well as that
the lifetime constraint.
"""
function penalty_test(m, case, params)

    # Reassign types and variables
    elect = case[:nodes][3]
    𝒯     = case[:T]
    penalty = m[:elect_efficiency_penalty]

    # Calculation of the penalty
    @test sum(
            value.(penalty[elect, t]) <= value.(penalty[elect, t_prev]) ||
            value.(penalty[elect, t]) ≈ value.(penalty[elect, t_prev])
            for (t_prev, t) ∈ withprev(𝒯) if !isnothing(t_prev)
        ) == length(𝒯) - params[:num_sp] * (params[:rep]+1)
    @test sum(
            value.(m[:elect_previous_usage][elect, t]) ≤ params[:stack_lifetime] for t ∈ 𝒯
        ) == length(𝒯)
end

"""
    build_run_reformer_model(params)

Returns `(JuMP.model, case)` dictionary of default model that uses a reformer of the type
defined in the package `EnergyModelsHydrogen`.
"""
function build_run_reformer_model(params)
    @debug "Degradation electrolyzer model."
    # Step 1: Defining the overall time structure.
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

    # Step 3: Defining products:
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

    if params[:simple]
        reformer = EMH.SimpleElectrolyzer(
            "PEM",
            FixedProfile(50),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(0),    # Fixed Opex
            Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput
            Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
            params[:data],              # Data
            0,                          # Min load
            1,                          # Max load
            params[:degradation_rate],  # Degradation rate
            params[:stack_cost],        # Stack replacement costs
            params[:stack_lifetime],    # Stack lifetime in h
        )
    else
        reformer = EMH.Reformer(
            "reformer",
            FixedProfile(50),   # Installed capacity [MW]
            FixedProfile(5),    # Variable Opex
            FixedProfile(0),    # Fixed Opex
            Dict(NG => 1.25, Power => 0.11),   # Input: Ratio of Input flows to characteristic throughput
            output,             # Ouput: Ratio of Output flow to characteristic throughput
            params[:data],      # Data

            FixedProfile(0.2),  # Hourly cost for startup [€/MW/h]
            FixedProfile(0.2),  # Hourly cost for shutdown [€/MW/h]
            FixedProfile(0.02), # Hourly cost when offline [€/MW/h]

            FixedProfile(5),    # Startup time [h]
            FixedProfile(5),    # Shutdown time [h]
            FixedProfile(10),   # Minimum off time [h]

            0.2,                # Min load [-]
            1.0,                # Max load [-]
        )
    end

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


    # Step 5: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links = [
        Direct("ng_source-ref", ng_source, reformer, Linear())
        Direct("el_source-ref", el_source, reformer, Linear())
        Direct("ref-h2_sink", reformer, H2_sink, Linear())
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


    # Step 7: Include all parameters in a single dictionary
    case = Dict(
        :T => T,
        :products => products,
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{EMB.Link}(links),
    )

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

    𝒯 = case[:T]
    ref = case[:nodes][3]

    @test termination_status(m) == MOI.OPTIMAL
    @test sum(value.(m[:ref_on_b][ref, t]) for t ∈ 𝒯) > 0
    @test sum(value.(m[:cap_use][ref, t]) for t ∈ 𝒯) > 0

end
