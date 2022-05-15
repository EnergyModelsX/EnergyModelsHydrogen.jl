# This function sets the data of the optimization problem instance
function read_data(fn)
    @debug "Read data"
    @info "Hard coded toy example: Wind power-based electrolysis into hydrogen for the end-user"

    # Step 1: Defining the overall time structure.
    # Project life time = 7 days, strategic decisions made at start of each day, operational decisions made every hour.
    overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,10,1))
    #overall_time_structure = UniformTwoLevel(1,7,1,UniformTimes(1,24,1))

    # Step 2: Define the arc flow streams which are structs in {ResourceEmit, ResourceCarrier} <: Resource
    Windpower    = ResourceCarrier("Windpower", 0.0)
    Hydrogen    = ResourceCarrier("Hydrogen", 0.0)
    arc_flow_types = [Windpower, Hydrogen]
    𝒫 = Dict(k => 0 for k ∈ arc_flow_types)

    # Step 3: Defining the nodes (conversion units)
    nodes = [
        EMB.GenAvailability(1, 𝒫, 𝒫),
        EMB.RefSource(2, FixedProfile(100), FixedProfile(0), FixedProfile(0), Dict(Windpower => 1), Dict(), Dict()),
        EMB.RefGeneration(3, FixedProfile(100), FixedProfile(10), FixedProfile(0), Dict(Windpower => 1), Dict(Hydrogen => 0.62), Dict(), 0.0, Dict()),
        #Electrolyzer(3,),
        EMB.RefSink(4,FixedProfile(50),Dict(:Surplus => 0, :Deficit => 2000), Dict(Hydrogen => 1), Dict())
    ]

    # Step 4: Defining the graph connections. Using the GenAvailability node for convenience.
    connections = [
        EMB.Direct(21,nodes[2],nodes[1],EMB.Linear())
        EMB.Direct(13,nodes[1],nodes[3],EMB.Linear())
        EMB.Direct(31,nodes[3],nodes[1],EMB.Linear())
        EMB.Direct(14,nodes[1],nodes[4],EMB.Linear())
    ]

    # Step 5: Setting up the global data. I suppose this is data that is for the entire project and not node or arc dependent
    global_data = EMB.GlobalData(Dict())

    # Step 6. Putting everything together
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
