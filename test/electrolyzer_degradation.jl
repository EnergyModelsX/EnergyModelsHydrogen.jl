# This file builds a Wind Turbine -> Electrolyzer -> End Hydrogen Consumer model. The electrolyzer model includes degradation of efficiency.
using Hydrogen
using EnergyModelsBase
using TimeStructures
using Geography
using Test
using JuMP
using GLPK
using SCIP


const TS = TimeStructures
const EMB = EnergyModelsBase
const Geo = Geography

function build_run_model(Deficit_cost, Num_hours, degradation_rate, verbose)
    @info "Area 1: Wind power to electrolysis with one hydrogen consumer. Electrolyzer model with degradation"
    # A. Inputting the case data
    # Step 1: Defining the overall time structure.
    # Project life time = 10 hours, strategic decisions made at start of day, operational decisions made every hour.
    overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,Num_hours,1))

    # Step 2: Define all the arc flow streams for all areas which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power    = EMB.ResourceCarrier("Power", 0.0)
    H2    = EMB.ResourceCarrier("H2", 0.0)
    
    # Step 3: Define the products, nodes, links for each area
    # Area 1 - 3a. Defining products
    products_area_1 = [Power, H2]
    𝒫_area_1 = Dict(k => 0 for k ∈ products_area_1)

    # 3b: Defining nodes (conversion units)
    Central_node_A1 = Geo.GeoAvailability("CN", 𝒫_area_1, 𝒫_area_1)
    Wind_turbine = EMB.RefSource("WT", FixedProfile(100), FixedProfile(0), FixedProfile(0), Dict(Power => 1), Dict(), Dict())
    PEM_electrolyzer = Hydrogen.Electrolyzer("El", FixedProfile(100), FixedProfile(10), FixedProfile(0), Dict(Power => 1), Dict(H2 => 0.62), Dict(), 0.0, Dict(), 5/60, 0, 160, 85000, degradation_rate) 
    End_hydrogen_consumer = EMB.RefSink("Con",FixedProfile(50),Dict(:Surplus => 0, :Deficit => Deficit_cost), Dict(H2 => 1), Dict())
    nodes_area_1 = [Central_node_A1, Wind_turbine, PEM_electrolyzer, End_hydrogen_consumer]

    # Step 3c: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links_area_1 = [
        EMB.Direct("A1_l1",Wind_turbine,Central_node_A1,EMB.Linear())
        EMB.Direct("A1_l2",Central_node_A1,PEM_electrolyzer,EMB.Linear())
        EMB.Direct("A1_l3",PEM_electrolyzer,Central_node_A1,EMB.Linear())
        EMB.Direct("A1_l4",Central_node_A1,End_hydrogen_consumer,EMB.Linear())
    ]

    # Step 4: Defining the area. This is not important in this case
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

    # B Formulating and running the optimization problem
    modeltype = EMB.OperationalModel()
    m = Geo.create_model(data, modeltype)
    if verbose
        print(m)
    end
    
    JuMP.set_optimizer(m, SCIP.Optimizer)
    optimize!(m)
    
    if (JuMP.termination_status(m) == OPTIMAL && verbose)
        println("objective value ", objective_value(m))
        println("cap_inst ", value.(m[:cap_inst]))
        println("cap_use ", value.(m[:cap_use]))
        println("sink_surplus ", value.(m[:sink_surplus]))
        println("sink_deficit ", value.(m[:sink_deficit]))
        println("flow_in ", value.(m[:flow_in]))
        println("flow_out ", value.(m[:flow_out]))
        println("elect_on ", value.(m[:elect_on]))
        println("previous_usage ", value.(m[:previous_usage]))
        #println("link_in ", value.(m[:link_in]))
        #println("link_out ", value.(m[:link_out]))
    end
    return (m, data)
end

@testset "Electrolyzer degradation model" begin
    verbose = false
    #(m0, d0) = build_run_model(0, 2, verbose)
    #(m1, d1) = build_run_model(15, 2, verbose)
    (m2, d2) = build_run_model(100, 2, 40, true)
    #=
    print(d0[:nodes])
    @test objective_value(m0) ≈ 0
    n = d0[:nodes][3]
    @test value.(m0[:elect_on][n, t] for t ∈ d0[:T]) ≈ [0.0, 0.0] 
    @test JuMP.termination_status(m1) == OPTIMAL
    @test objective_value(m1) <= objective_value(m2)
    =#
end


