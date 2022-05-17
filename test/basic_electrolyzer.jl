# This file builds a simple wind power to electrolyzer model using the basic functionality in EnergyModelsBase
using Hydrogen
using EnergyModelsBase
using TimeStructures
using Geography
using Test
using JuMP
using GLPK


const TS = TimeStructures
const EMB = EnergyModelsBase
const Geo = Geography

@testset "Electrolyzer basic RefGeneration model" begin
    @info "Area 1: Wind power to electrolysis with one hydrogen consumer. Basic electrolyzer model"
    # A. Inputting the case data
    # Step 1: Defining the overall time structure.
    # Project life time = 10 hours, strategic decisions made at start of day, operational decisions made every hour.
    overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,2,1))

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
    PEM_electrolyzer = EMB.RefGeneration("El", FixedProfile(100), FixedProfile(10), FixedProfile(0), Dict(Power => 1), Dict(H2 => 0.62), Dict(), 0.0, Dict()) 
    End_hydrogen_consumer = EMB.RefSink("Con",FixedProfile(50),Dict(:Surplus => 0, :Deficit => 2000), Dict(H2 => 1), Dict())
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
    JuMP.set_optimizer(m, GLPK.Optimizer)
    print(m)
    optimize!(m)
    @test JuMP.termination_status(m) == OPTIMAL
    if (JuMP.termination_status(m) == OPTIMAL)
        println("objective value ", objective_value(m))
        println("cap_inst ", value.(m[:cap_inst]))
        println("cap_use ", value.(m[:cap_use]))
        println("sink_surplus ", value.(m[:sink_surplus]))
        println("sink_deficit ", value.(m[:sink_deficit]))
        println("flow_in ", value.(m[:flow_in]))
        println("flow_out ", value.(m[:flow_out]))
        #println("link_in ", value.(m[:link_in]))
        #println("link_out ", value.(m[:link_out]))
    end

    
end