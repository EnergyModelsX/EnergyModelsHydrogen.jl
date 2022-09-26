using EnergyModelsBase
using TimeStructures
using JuMP
using SCIP

# TO SET LOGGING LEVEL
ENV["JULIA_DEBUG"] = all

#using Logging # Use for tailored logging.
#logger = Logging.SimpleLogger(stdout, Logging.Debug)


"""
    Returns `(JuMP.model, data)` dictionary of default model that uses a converter of type `EnergyModelsBase.RefGen`.
"""
function build_run_default_EMB_model(Params::Dict{Symbol, Int64})
    @info "RefGen model."
    # Step 1: Defining the overall time structure.
    # Project lifetime: 4 hours. 1 strategic investment period.
    # operations: period of 4 hours, 1 hour resolution. 
    overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,1,4))

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = EnergyModelsBase.ResourceCarrier("Power", 0.0)
    H2    = EnergyModelsBase.ResourceCarrier("H2", 0.0)
    
    # Step 3: Defining products:
    products = [Power, H2]
    𝒫 = Dict(k => 0 for k ∈ products)

    # Step 4: Defining nodes:
    Central_node = EnergyModelsBase.GenAvailability("CN", 𝒫 , 𝒫)
    
    Wind_turbine = EnergyModelsBase.RefSource("WT",
                                        FixedProfile(100), # Installed capacity [MW]
                                        FixedProfile(0),   # Variable Opex    
                                        FixedProfile(0),   # Fixed Opex
                                        Dict(Power => 1),  # Ratio of output to characteristic throughput
                                        Dict(),            # Emissions
                                        Dict()            # Data
                                        )
    
    Gen_Electrolyzer = EnergyModelsBase.RefGeneration("El",
                                        FixedProfile(100), # Installed capacity [MW]
                                        FixedProfile(10),  # Variable Opex
                                        FixedProfile(0),   # Fixed Opex
                                        Dict(Power => 1),  # Input: Ratio of Input flows to characteristic throughput 
                                        Dict(H2 => 0.62), # Ouput: Ratio of Output flow to characteristic throughput
                                        Dict(),             # Emissions dict
                                        0.0,                # CO2 capture
                                        Dict()              # Data  
                                        )

    End_hydrogen_consumer = EnergyModelsBase.RefSink("Con",
                                        FixedProfile(50), # Installed capacity [MW]
                                        Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(Params[:Deficit_cost])), # Penalty dict
                                        Dict(H2 => 1),          # Ratio of sink flows to sink characteristic throughput.
                                        Dict()                  # Emissions dict
                                        )

    nodes= [Central_node, Wind_turbine, Gen_Electrolyzer, End_hydrogen_consumer]

    # Step 5: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links = [
        EnergyModelsBase.Direct("l1", Wind_turbine, Central_node, EnergyModelsBase.Linear())
        EnergyModelsBase.Direct("l2", Central_node, Gen_Electrolyzer, EnergyModelsBase.Linear())
        EnergyModelsBase.Direct("l3", Gen_Electrolyzer, Central_node, EnergyModelsBase.Linear())
        EnergyModelsBase.Direct("l4", Central_node, End_hydrogen_consumer, EnergyModelsBase.Linear())
    ]

    # Step 6: Setting up the global data. Data for the entire project and not node or arc dependent
    global_data = EnergyModelsBase.GlobalData(Dict())

    data = Dict(
        :T => overall_time_structure,
        :products => products,
        :nodes => Array{EnergyModelsBase.Node}(nodes),
        :links => Array{EnergyModelsBase.Link}(links),
        :global_data => global_data,
    )

    # B Formulating and running the optimization problem
    modeltype = EnergyModelsBase.OperationalModel()
    m = EnergyModelsBase.create_model(data, modeltype)
    @debug "Optimization model: $(m)"

    JuMP.set_optimizer(m, SCIP.Optimizer)
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
function build_run_electrolyzer_model(Params::Dict{Symbol, Int64})
    @info "Degradation electrolyzer model."
    # Step 1: Defining the overall time structure.
    # Project lifetime: 4 hours. 1 strategic investment period.
    # operations: period of 4 hours, 1 hour resolution. 
    overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,1,4))

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = EnergyModelsBase.ResourceCarrier("Power", 0.0)
    H2    = EnergyModelsBase.ResourceCarrier("H2", 0.0)
    
    # Step 3: Defining products:
    products = [Power, H2]
    𝒫 = Dict(k => 0 for k ∈ products)

    # Step 4: Defining nodes:
    Central_node = EnergyModelsBase.GenAvailability("CN", 𝒫 , 𝒫)
    
    Wind_turbine = EnergyModelsBase.RefSource("WT",
                                        FixedProfile(100), # Installed capacity [MW]
                                        FixedProfile(0),   # Variable Opex    
                                        FixedProfile(0),   # Fixed Opex
                                        Dict(Power => 1),  # Ratio of output to characteristic throughput
                                        Dict(),            # Emissions
                                        Dict()            # Data
                                        )
    PEM_electrolyzer = EnergyModelsHydrogen.Electrolyzer("PEM",
                                        FixedProfile(100), # Installed capacity [MW]
                                        FixedProfile(10),  # Variable Opex
                                        FixedProfile(0),   # Fixed Opex
                                        Dict(Power => 1),  # Input: Ratio of Input flows to characteristic throughput 
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

    End_hydrogen_consumer = EnergyModelsBase.RefSink("Con",
                                        FixedProfile(50), # Installed capacity [MW]
                                        Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(Params[:Deficit_cost])), # Penalty dict
                                        Dict(H2 => 1),          # Ratio of sink flows to sink characteristic throughput.
                                        Dict()                  # Emissions dict
                                        )

    nodes= [Central_node, Wind_turbine, PEM_electrolyzer, End_hydrogen_consumer]

    # Step 5: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links = [
        EnergyModelsBase.Direct("l1", Wind_turbine, Central_node, EnergyModelsBase.Linear())
        EnergyModelsBase.Direct("l2", Central_node, PEM_electrolyzer, EnergyModelsBase.Linear())
        EnergyModelsBase.Direct("l3", PEM_electrolyzer, Central_node, EnergyModelsBase.Linear())
        EnergyModelsBase.Direct("l4", Central_node, End_hydrogen_consumer, EnergyModelsBase.Linear())
    ]

    # Step 6: Setting up the global data. Data for the entire project and not node or arc dependent
    global_data = EnergyModelsBase.GlobalData(Dict())

    data = Dict(
        :T => overall_time_structure,
        :products => products,
        :nodes => Array{EnergyModelsBase.Node}(nodes),
        :links => Array{EnergyModelsBase.Link}(links),
        :global_data => global_data,
    )

    # B Formulating and running the optimization problem
    modeltype = EnergyModelsBase.OperationalModel()
    m = EnergyModelsBase.create_model(data, modeltype)
    #=
    @debug "Optimization model: $(m)"

    JuMP.set_optimizer(m, SCIP.Optimizer)
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
        @debug "elect_on $(value.(m[:elect_on]))"
        @debug "previous_usage $(value.(m[:previous_usage]))"
        @debug "efficiency_penalty $(value.(m[:efficiency_penalty]))"
    end
    =#
    return (m, data)
end


# The optimization model expects these default keys
params_dict = Dict(:Deficit_cost => 0, :Num_hours => 2, :Degradation_rate => 10, :Equipment_lifetime => 85000)
@testset "RefGen - Should all be zero" begin
    (m0_def, d0) = build_run_default_EMB_model(params_dict)
    @test objective_value(m0) ≈ 0
    m1_dict = params_dict
    m1_dict[:Deficit_cost] = 15
    (m1, d1) = build_run_default_EMB_model(m1_dict)
    @test (objective_value(m0) <= objective_value(m1) || objective_value(m0) ≈ objective_value(m1)) # Levying a deficit penalty should increase minimum cost
end

# Test case m1
m1_dict = params_dict
m1_dict[:Deficit_cost] = 15
(m1, d1) = build_run_electrolyzer_model(m1_dict)






@test objective_value(m0) ≈ 0
n = d0[:nodes][3]
@test value.(m0[:elect_on][n, t] for t ∈ d0[:T]) ≈ [0.0, 0.0]

# Test case m1
m1_dict = params_dict
m1_dict[:Deficit_cost] = 15
(m1, d1) = build_run_model(m1_dict)
@test (objective_value(m0) <= objective_value(m1) || objective_value(m0) ≈ objective_value(m1)) # Levying a deficit penalty should increase minimum cost

# Test case m2
m2_dict = params_dict
m2_dict[:Num_hours] = 10
m2_dict[:Deficit_cost] = 100
m2_dict[:Degradation_rate] = 5
m2_dict[:Equipment_lifetime] = 7
(m2, d2) = build_run_model(m2_dict)
n = d2[:nodes][3]
for t in d2[:T]
    t_prev = TS.previous(t,d2[:T])
    if (t_prev != nothing)
        @test (value.(m2[:efficiency_penalty][n, t]) <= value.(m2[:efficiency_penalty][n, t_prev]) || value.(m2[:efficiency_penalty][n, t]) ≈ value.(m2[:efficiency_penalty][n, t_prev]))
        @test value.(m2[:previous_usage][n,t]) <= m2_dict[:Equipment_lifetime]
    end
end

@test 1 == 1