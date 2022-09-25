using EnergyModelsBase
using TimeStructures
using JuMP
using SCIP

"""
    Returns `data` dictionary of default model that uses a converter of type `EnergyModelsBase.RefGen`.
"""
function build_default_EMB_model(Params::Dict{Symbol, Int64})
    @info "Area 1: Wind power to electrolysis with one hydrogen consumer."
    # A. Inputting the case data
    # Step 1: Defining the overall time structure.
    # 1 strategic period. `Num_hours` of operation. 1 hour resolution.
    overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,Params[:Num_hours],1))

    # Step 2: Define all the arc flow streams for all areas which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power = EnergyModelsBase.ResourceCarrier("Power", 0.0)
    H2    = EnergyModelsBase.ResourceCarrier("H2", 0.0)
    
    # Step 3: Define the products, nodes, links for each area
    # Area 1 - 3a. Defining products
    products_area_1 = [Power, H2]
    𝒫_area_1 = Dict(k => 0 for k ∈ products_area_1)

    # 3b: Defining nodes (conversion units)
    Central_node_A1 = Geo.GeoAvailability("CN", 𝒫_area_1, 𝒫_area_1)
    Wind_turbine = EMB.RefSource("WT", FixedProfile(100), FixedProfile(0), FixedProfile(0), Dict(Power => 1), Dict(), Dict())
    PEM_electrolyzer = EnergyModelsHydrogen.Electrolyzer("El", FixedProfile(100), FixedProfile(10), FixedProfile(0), Dict(Power => 1), Dict(H2 => 0.62), Dict(), 0.0, Dict(), 5/60, 0, 160, Params[:Equipment_lifetime], Params[:Degradation_rate]) 
    End_hydrogen_consumer = EMB.RefSink("Con",FixedProfile(50),Dict(:Surplus => 0, :Deficit => Params[:Deficit_cost]), Dict(H2 => 1), Dict())
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
end


@test 1 == 1