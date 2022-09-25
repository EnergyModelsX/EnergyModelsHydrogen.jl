using EnergyModelsBase
using TimeStructures
using JuMP
using SCIP

# TO SET LOGGING LEVEL
using Logging
logger = Logging.SimpleLogger(stdout, Logging.Debug)


"""
    Returns `(JuMP.model, data)` dictionary of default model that uses a converter of type `EnergyModelsBase.RefGen`.
"""
function build_run_default_EMB_model(Params::Dict{Symbol, Int64})
    @info "Area 1: Wind power to electrolysis with one hydrogen consumer."
    # Step 1: Defining the overall time structure.
    # Project lifetime: 2 days. 1 strategic investment period over the 2 days. 
    # operations: period of 1 day, 4 hour resolution. 
    overall_time_structure = UniformTwoLevel(1,1,2,UniformTimes(1,6,4))

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



function build_default_EMB_model(Params::Dict{Symbol, Int64})
    @info "Area 1: Wind power to electrolysis with one hydrogen consumer."
    # Step 1: Defining the overall time structure.
    # Project lifetime: 2 days. 1 strategic investment period over the 2 days. 
    # operations: period of 1 day, 4 hour resolution. 
    overall_time_structure = UniformTwoLevel(1,1,2,UniformTimes(1,6,4))

    # Step 2: Define all the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = EnergyModelsBase.ResourceCarrier("Power", 0.0)
    H2    = EnergyModelsBase.ResourceCarrier("H2", 0.0)
    
    # Step 3: Defining products:
    products = [Power, H2]
    𝒫 = Dict(k => 0 for k ∈ products)

    # Step 4: Defining nodes:
    Central_node_A1 = EnergyModelsBase.GenAvailability("CN", 𝒫_area_1, 𝒫_area_1)
    Wind_turbine = EMB.RefSource("WT", FixedProfile(100), FixedProfile(0), FixedProfile(0), Dict(Power => 1), Dict(), Dict())
    PEM_electrolyzer = EnergyModelsHydrogen.Electrolyzer("El", FixedProfile(100), FixedProfile(10), FixedProfile(0), Dict(Power => 1), Dict(H2 => 0.62), Dict(), 0.0, Dict(), 5/60, 0, 160, Params[:Equipment_lifetime], Params[:Degradation_rate]) 
    End_hydrogen_consumer = EMB.RefSink("Con",FixedProfile(50),Dict(:Surplus => 0, :Deficit => Params[:Deficit_cost]), Dict(H2 => 1), Dict())
    nodes_area_1 = [Central_node_A1, Wind_turbine, PEM_electrolyzer, End_hydrogen_consumer]

    # Step 5: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links_area_1 = [
        EMB.Direct("A1_l1",Wind_turbine,Central_node_A1,EMB.Linear())
        EMB.Direct("A1_l2",Central_node_A1,PEM_electrolyzer,EMB.Linear())
        EMB.Direct("A1_l3",PEM_electrolyzer,Central_node_A1,EMB.Linear())
        EMB.Direct("A1_l4",Central_node_A1,End_hydrogen_consumer,EMB.Linear())
    ]

    # Step 6: Defining the area. This is not important in this case
    areas = [
        Geo.Area("A1", "Test_Area_1", 0.0, 0.0, Central_node_A1)
    ]

    # Step 5: Setting up the global data. Data for the entire project and not node or arc dependent
    global_data = EMB.GlobalData(Dict())

    data = Dict(
        :T => overall_time_structure,
        :products => products_area_1,
        :nodes => Array{EMB.Node}(nodes_area_1),
        :links => Array{EMB.Link}(links_area_1),
        :global_data => global_data,
        :areas          => Array{Geo.Area}(areas),
        :transmission => Array{Geo.Transmission}([])
    )
end


# The optimization model expects these default keys
params_dict = Dict(:Deficit_cost => 100, :Num_hours => 2, :Degradation_rate => 10, :Equipment_lifetime => 85000)
# Test case m1
with_logger(logger) do
    (m0, d0) = build_run_default_EMB_model(params_dict)
end




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