
# TO SET LOGGING LEVEL
# ENV["JULIA_DEBUG"] = all

#using Logging # Use for tailored logging.
#logger = Logging.SimpleLogger(stdout, Logging.Debug)


"""
    Returns `(JuMP.model, data)` dictionary of default model that uses a converter of type `EMB.RefGen`.
"""
function build_run_default_EMB_model(Params)
    @info "RefGen model."
    # Step 1: Defining the overall time structure.
    # Project lifetime: Params[:Num_hours] hours. 1 strategic investment period.
    # operations: period of Params[:Num_hours] hours, 1 hour resolution. 
    overall_time_structure = UniformTwoLevel(1,3,2,UniformTimes(1,Params[:Num_hours],1))

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = ResourceCarrier("Power", 0.0)
    H2    = ResourceCarrier("H2", 0.0)
    
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
                                Dict(),             # Emissions
                                Dict(),             # Data
                                )
    
    Gen_Electrolyzer = RefGeneration("El",
                                FixedProfile(100),  # Installed capacity [MW]
                                FixedProfile(10),   # Variable Opex
                                FixedProfile(0),    # Fixed Opex
                                Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput 
                                Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
                                Dict(),             # Emissions dict
                                0.0,                # CO2 capture
                                Dict(),             # Data  
                                )

    End_hydrogen_consumer = RefSink("Con",
                                FixedProfile(50),   # Installed capacity [MW]
                                Dict(:Surplus => FixedProfile(0),
                                     :Deficit => Params[:Deficit_cost]), # Penalty dict
                                Dict(H2 => 1),      # Ratio of sink flows to sink characteristic throughput.
                                Dict(),             # Emissions dict
                                )

    nodes= [Central_node, Wind_turbine, Gen_Electrolyzer, End_hydrogen_consumer]

    # Step 5: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links = [
        Direct("l1", Wind_turbine, Central_node, Linear())
        Direct("l2", Central_node, Gen_Electrolyzer, Linear())
        Direct("l3", Gen_Electrolyzer, Central_node, Linear())
        Direct("l4", Central_node, End_hydrogen_consumer, Linear())
    ]

    # Step 6: Setting up the global data. Data for the entire project and not node or arc dependent
    global_data = GlobalData(Dict())

    data = Dict(
        :T => overall_time_structure,
        :products => products,
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{EMB.Link}(links),
        :global_data => global_data,
    )

    # B Formulating and running the optimization problem
    modeltype = OperationalModel()
    m = create_model(data, modeltype)
    @debug "Optimization model: $(m)"

    set_optimizer(m, optim)
    set_optimizer_attribute(m, "OutputFlag", 0)
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
    end
    return (m, data)
end




"""
    Returns `(JuMP.model, data)` dictionary of default model that uses a converter of type `EnergyModelsHydrogen`.
"""
function build_run_electrolyzer_model(Params)
    @info "Degradation electrolyzer model."
    # Step 1: Defining the overall time structure.
    # Project lifetime: Params[:Num_hours] hours. 1 strategic investment period.
    # operations: period of Params[:Num_hours] hours, 1 hour resolution. 
    overall_time_structure = UniformTwoLevel(1,3,2,UniformTimes(1,Params[:Num_hours],1))

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = ResourceCarrier("Power", 0.0)
    H2    = ResourceCarrier("H2", 0.0)
    
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
                                Dict(),             # Emissions
                                Dict(),             # Data
                                )

    PEM_electrolyzer = EMH.Electrolyzer("PEM",
                                FixedProfile(100),  # Installed capacity [MW]
                                FixedProfile(10),   # Variable Opex
                                FixedProfile(0),    # Fixed Opex
                                Dict(Power => 1),   # Input: Ratio of Input flows to characteristic throughput 
                                Dict(H2 => 0.62),   # Ouput: Ratio of Output flow to characteristic throughput
                                Dict(),             # Emissions dict
                                0.0,                # CO2 capture
                                Dict(),             # Data
                                5/60,               # Startup time  
                                0,                  # Min load
                                160,                # Max load
                                Params[:Equipment_lifetime],  
                                Params[:Degradation_rate]
                                ) 

    End_hydrogen_consumer = RefSink("Con",
                                FixedProfile(50),   # Installed capacity [MW]
                                Dict(:Surplus => FixedProfile(0),
                                     :Deficit => Params[:Deficit_cost]), # Penalty dict
                                Dict(H2 => 1),      # Ratio of sink flows to sink characteristic throughput.
                                Dict(),             # Emissions dict
                                )


    nodes= [Central_node, Wind_turbine, PEM_electrolyzer, End_hydrogen_consumer]

    # Step 5: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links = [
        Direct("l1", Wind_turbine, Central_node, Linear())
        Direct("l2", Central_node, PEM_electrolyzer, Linear())
        Direct("l3", PEM_electrolyzer, Central_node, Linear())
        Direct("l4", Central_node, End_hydrogen_consumer, Linear())
    ]

    # Step 6: Setting up the global data. Data for the entire project and not node or arc dependent
    global_data = GlobalData(Dict())

    data = Dict(
        :T => overall_time_structure,
        :products => products,
        :nodes => Array{EMB.Node}(nodes),
        :links => Array{EMB.Link}(links),
        :global_data => global_data,
    )

    # B Formulating and running the optimization problem
    modeltype = OperationalModel()
    m = create_model(data, modeltype)

    @debug "Optimization model: $(m)"

    set_optimizer(m, optim)
    set_optimizer_attribute(m, "NonConvex", 2)
    set_optimizer_attribute(m, "MIPGap", 1e-3)
    set_optimizer_attribute(m, "OutputFlag", 0)

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
        @debug "elect_usage_in_sp $(value.(m[:elect_usage_in_sp]))"
        @debug "elect_efficiency_penalty $(value.(m[:elect_efficiency_penalty]))"
    end
    return (m, data)
end


# The optimization model expects these default keys
params_dict = Dict(:Deficit_cost => FixedProfile(0), :Num_hours => 2, :Degradation_rate => 1, :Equipment_lifetime => 85000)

@testset "RefGen - Basic sanity tests" begin
    (m0, d0) = build_run_default_EMB_model(params_dict)
    @test objective_value(m0) ≈ 0
    m1_dict = deepcopy(params_dict)
    m1_dict[:Deficit_cost] = FixedProfile(17)
    (m1, d1) = build_run_default_EMB_model(m1_dict)
    @test (objective_value(m0) >= objective_value(m1) || objective_value(m0) ≈ objective_value(m1)) # Levying a deficit penalty should increase minimum cost
    finalize(backend(m0).optimizer.model)
    finalize(backend(m1).optimizer.model)
end

@testset "Electrolyzer - Basic sanity tests" begin
    (m0, d0) = build_run_electrolyzer_model(params_dict)
    @test objective_value(m0) ≈ 0
    m1_dict = deepcopy(params_dict)
    m1_dict[:Deficit_cost] = FixedProfile(17)
    (m1, d1) = build_run_electrolyzer_model(m1_dict)
    @test (objective_value(m0) >= objective_value(m1) || objective_value(m0) ≈ objective_value(m1)) # Levying a deficit penalty should increase minimum cost
    finalize(backend(m0).optimizer.model)
    finalize(backend(m1).optimizer.model)
end


@testset "Electrolyzer - Degradation tests" begin
    m2_dict = deepcopy(params_dict)
    m2_dict[:Num_hours] = 5
    m2_dict[:Deficit_cost] = StrategicFixedProfile([10, 20, 25])
    m2_dict[:Degradation_rate] = 1
    m2_dict[:Equipment_lifetime] = 120
    (m2, d2) = build_run_electrolyzer_model(m2_dict)
    n = d2[:nodes][3]
    for t ∈ d2[:T]
        t_prev = TS.previous(t,d2[:T])
        if (t_prev != nothing)
            @test (value.(m2[:elect_efficiency_penalty][n, t]) <= value.(m2[:elect_efficiency_penalty][n, t_prev]) || value.(m2[:elect_efficiency_penalty][n, t]) ≈ value.(m2[:elect_efficiency_penalty][n, t_prev]))
            @test value.(m2[:elect_previous_usage][n,t]) <= m2_dict[:Equipment_lifetime]
        end
    end
    finalize(backend(m2).optimizer.model)
end