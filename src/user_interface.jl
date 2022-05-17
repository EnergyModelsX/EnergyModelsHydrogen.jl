
# This function sets the data of the optimization problem instance
function read_data(fn)
    @debug "Read data"
    @info "Hard coded toy example: Area 1: Wind power to electrolysis with one power end consumer. Area 2: End power hydrogen consumer"

    # Step 1: Defining the overall time structure.
    # Project life time = 7 days, strategic decisions made at start of each day, operational decisions made every hour.
    overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,10,1))
    #overall_time_structure = UniformTwoLevel(1,7,1,UniformTimes(1,24,1))

    # Step 2: Define all the arc flow streams for all areas which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Power    = EMB.ResourceCarrier("Power", 0.0)
    Hydrogen    = EMB.ResourceCarrier("Hydrogen", 0.0)
    
    # Step 3: Define the products, nodes, links for each area
    # Area 1 - 3a. Defining products
    products_area_1 = [Power, Hydrogen]
    𝒫_area_1 = Dict(k => 0 for k ∈ products_area_1)

    # 3b: Defining nodes (conversion units)
    Central_node_A1 = Geo.GeoAvailability(A1_1, 𝒫_area_1, 𝒫_area_1)
    Wind_turbine = EMB.RefSource(A1_2, FixedProfile(100), FixedProfile(0), FixedProfile(0), Dict(Power => 1), Dict(), Dict())
    PEM_electrolyzer = EMB.RefGeneration(A1_3, FixedProfile(100), FixedProfile(10), FixedProfile(0), Dict(Power => 1), Dict(Hydrogen => 0.62), Dict(), 0.0, Dict()) 
    End_power_consumer = EMB.RefSink(A1_4,FixedProfile(50),Dict(:Surplus => 0, :Deficit => 2000), Dict(Power => 1), Dict())
    nodes_area_1 = [Central_node_A1, Wind_turbine, PEM_electrolyzer, End_power_consumer]

    # Step 3c: Defining the links (graph connections). Using the GeoAvailability node for convenience.
    links_area_1 = [
        EMB.Direct(A1_l1,Wind_turbine,Central_node_A1,EMB.Linear())
        EMB.Direct(A1_l2,Central_node_A1,PEM_electrolyzer,EMB.Linear())
        EMB.Direct(A1_l3,PEM_electrolyzer,Central_node_A1,EMB.Linear())
        EMB.Direct(A1_l4,Central_node_A1,End_power_consumer,EMB.Linear())
    ]

    # Area 2 - Products
    products_area_2 = [Hydrogen]
    𝒫_area_2 = Dict(k => 0 for k ∈ products_area_2)

    # Area 2 - Nodes
    Central_node_A2 = Geo.GeoAvailability(A2_1, 𝒫_area_2, 𝒫_area_2)
    End_hydrogen_consumer = EMB.RefSink(A2_2,FixedProfile(50),Dict(:Surplus => 0, :Deficit => 2000), Dict(Hydrogen => 1), Dict())
    nodes_area_2 = [Central_node_A2, End_hydrogen_consumer]

    # Area 2 - Links
    links_area_2 = [
        EMB.Direct(A2_l1,Central_node_A2,End_hydrogen_consumer,EMB.Linear())
    ]

    # Step 4. Defining the areas. 
    areas = [
        Geo.Area(A1, "Test_Area_1", 0.0, 0.0, Central_node_A1)
        Geo.Area(A2, "Test_Area_2", 5.0, 5.0, Central_node_A2)
    ]

    # Step 5- Defining the transmission technologies between the areas
    # 5a. Defining the transmission modes
    #Hydrogen_pipeline_linepack = Geo.Pipeline_linepack()

    # 5b. Definining the transmission links
    transmission = [
        Geo.Transmission(areas[1], areas[2], [Hydrogen_pipeline_linepack], Dict())
    ]

    # Step 6: Setting up the global data. Data for the entire project and not node or arc dependent
    global_data = EMB.GlobalData(Dict())

    # Concatenate and get unique products, nodes, links

    # Step 7. Putting everything together
    #=
    case = Dict(
                :areas          => Array{Area}(areas),
                :transmission   => Array{Transmission}(transmission),
                :nodes          => Array{EMB.Node}(nodes),
                :links          => Array{EMB.Link}(links),
                :products       => products,
                :T              => T,
                :global_data    => global_data,
                )
    =#
    data = Dict(
                :nodes => nodes,
                :links => connections,
                :products => arc_flow_types,
                :T => overall_time_structure,
                :global_data    => global_data,
                )
    return data
end

function run_model(fn, optimizer=nothing)
    @debug "Hydrogen: run model" fn optimizer

     data = read_data(fn)
     model = EMB.OperationalModel()

     m = EMB.create_model(data, model)
     print(m)
 
     if !isnothing(optimizer)
         set_optimizer(m, optimizer)
         optimize!(m)
         # TODO: print_solution(m) optionally show results summary (perhaps using upcoming JuMP function)
         # TODO: save_solution(m) save results
     else
         @info "No optimizer given."
     end
     return m, data
 end
