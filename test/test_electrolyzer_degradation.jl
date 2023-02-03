"""
Returns `(JuMP.model, data)` dictionary of default model that uses an electrolyzer
of the type defined in the package `EnergyModelsHydrogen`.
"""
function build_run_electrolyzer_model(params)
    @debug "Degradation electrolyzer model."
    # Step 1: Defining the overall time structure.
    #   params[:num_sp] - # of strategic periods with a duration of 2.
    #   params[:num_op] - # of operational periods with a total durationg of 8760 h.
    overall_time_structure = UniformTwoLevel(1,params[:num_sp],2,UniformTimes(1,params[:num_op],8760/params[:num_op]))

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = ResourceCarrier("Power", 0.0)
    H2    = ResourceCarrier("H2", 0.0)
    CO2   = ResourceEmit("CO2", 1.0)
    
    # Step 3: Defining products:
    products = [Power, H2]
    𝒫 = Dict(k => 0 for k ∈ products)

    # Step 4: Defining nodes:
    Central_node = GenAvailability("CN", 𝒫 , 𝒫)
    
    Wind_turbine = RefSource("WT",
                                FixedProfile(100),  # Installed capacity [MW]
                                FixedProfile(0),    # Variable Opex    
                                FixedProfile(0),    # Fixed Opex
                                Dict(Power => 1),   # Ratio of output to characteristic throughput
                                Dict(),             # Data
    )

    PEM_electrolyzer = EMH.Electrolyzer("PEM",
                                FixedProfile(100),  # Installed capacity [MW]
                                FixedProfile(5),    # Variable Opex
                                FixedProfile(0),    # Fixed Opex
                                params[:stack_cost],  # Stack replacement costs
                                Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput 
                                Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
                                Dict(),             # Data
                                5/60,               # Startup time  
                                0,                  # Min load
                                160,                # Max load
                                params[:stack_lifetime],    # Stack lifetime in h
                                params[:degradation_rate]   # Degradation rate
    ) 

    End_hydrogen_consumer = RefSink("Con",
                                FixedProfile(50),   # Installed capacity [MW]
                                Dict(:Surplus => FixedProfile(0),
                                     :Deficit => params[:deficit_cost]), # Penalty dict
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
    data = Dict(
        :T => overall_time_structure,
        :products => products,
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{EMB.Link}(links),
    )

    # B Formulating and running the optimization problem
    model = OperationalModel(Dict(), CO2)
    m = create_model(data, model)

    @debug "Optimization model: $(m)"

    set_optimizer(m, optim)
    
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
    return (m, data)
end

"""
    penalty_test(m, data, params)

Test function for analysing that the previous operational period has an efficiency
penalty that is at least as large as the one of the current period as well as that
the lifetime constraint.
"""
function penalty_test(m, data, params)
    
    # Reassign types and variables
    elect = data[:nodes][3]
    𝒯     = data[:T]
    penalty = m[:elect_efficiency_penalty]

    # Degradation test
    for t ∈ 𝒯
        t_prev = TS.previous(t, 𝒯)
        if t_prev !== nothing
            @test value.(penalty[elect, t]) <= value.(penalty[elect, t_prev]) || 
                    value.(penalty[elect, t]) ≈ value.(penalty[elect, t_prev])
                    
            @test value.(m[:elect_previous_usage][elect, t]) <= params[:stack_lifetime]
        end
    end
end

# The optimization model expects these default keys
params_dict = Dict(
                    :deficit_cost => FixedProfile(0),
                    :num_op => 2,
                    :num_sp => 5,
                    :degradation_rate => .1/1000,
                    :stack_lifetime => 60000,
                    :stack_cost => FixedProfile(3e5),
)

# Test set for simple degradation tests without stack replacement due to the prohibitive costs
# for the replacement of the stack
@testset "Electrolyzer - Degradation tests" begin
    # Modifying the input parameters
    params_deg = deepcopy(params_dict)
    params_deg[:num_op] = 5
    params_deg[:deficit_cost] = StrategicFixedProfile([10, 10, 20, 25, 30])

    params_deg[:stack_cost] = FixedProfile(3e8)
    # Run and test the model
    (m, data) = build_run_electrolyzer_model(params_deg)
    penalty_test(m, data, params_deg)
    finalize(backend(m).optimizer.model)
end

# Test set for analysing the correct implementation of stack replacement
# Set deficit cost to be high to motivate electrolyzer use.
# params are adjusted that stack replacement is done once the lifetime is reached.
@testset "Electrolyzer - Stack replacement tests" begin
    # Modifying the input parameters
    params_rep = deepcopy(params_dict)
    params_rep[:num_op] = 5
    params_rep[:num_sp] = 8
    params_rep[:deficit_cost] = FixedProfile(1000)
    params_rep[:stack_cost] = FixedProfile(3e5)

    # Run and test the model
    (m, data) = build_run_electrolyzer_model(params_rep)
    penalty_test(m, data, params_rep)

    # Reassign types
    elect = data[:nodes][3]
    𝒯     = data[:T]
    𝒯ᴵⁿᵛ = EMB.strategic_periods(𝒯)
    stack_replace = m[:elect_stack_replacement_sp_b]
    stack_mult   = m[:elect_usage_mult_sp_b]

    # General test for the number of stack_replacements
    @test sum(value.(stack_replace[elect, t_inv]) for t_inv ∈ 𝒯ᴵⁿᵛ) ≈ 𝒯.len - 6
    
    # Test for the multiplier matrix that it is 0 for the block if there was a stack 
    # replacement. It will reset the block via the variable `t_replace` to the new
    # `t_inv`, if the variable`:elect_stack_replacement_sp_b` is 1
    @testset "Multiplier test" begin
        t_replace = nothing
        logic     = false
        for t_inv ∈ 𝒯ᴵⁿᵛ, t_inv_pre ∈ 𝒯ᴵⁿᵛ
            if value.(stack_replace[elect, t_inv]) ≈ 1 
                t_replace = t_inv
                logic = true
            elseif t_inv.sp == 1
                t_replace = t_inv
                logic = false
            end
            if logic
                if EMH.is_prior(t_inv_pre, t_replace)
                    @test value.(stack_mult[elect, t_inv, t_inv_pre]) ≈ 0 atol = TEST_ATOL
                else
                    @test value.(stack_mult[elect, t_inv, t_inv_pre]) ≈ 1 
                end
            else
                @test value.(stack_mult[elect, t_inv, t_inv_pre]) ≈ 1
            end
        end
    end

    finalize(backend(m).optimizer.model)
end