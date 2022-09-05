### A Pluto.jl notebook ###
# v0.19.9

#> [frontmatter]

using Markdown
using InteractiveUtils

# ╔═╡ 5b1b825d-4533-4411-bcde-a0eb79b3c0b8
begin
	using Pkg
	Pkg.activate(Base.current_project())
end

# ╔═╡ 7afb886a-612b-417e-9678-8cf1b6ea04a5
begin
	using EnergyModelsBase
	using TimeStructures
	using Test
	using JuMP
	using GLPK
	using Plots
end

# ╔═╡ b950ee83-8262-4bad-9ed8-9994b506e3f5
md"""# Model over only 1 geographical area.
- `Area 1`: Wind Power turbine to Electrolysis converter to produce hydrogen. One hydrogen end consumer. 
  
**Note**  : This simple example only relies on the functionality of `EnergyModelsBase`, `TimeStructures`. The `Geography` package is not required since only 1 local area is considered. It provides a reference for the basic functionality which will then be extended by `EnergyModelsHydrogen`."""

# ╔═╡ b3c176c4-7f22-4ecf-8f0b-9e5cbeca0162
md" ## ENVIRONMENT SET-UP"

# ╔═╡ 3c777be7-fe54-4d0b-ba51-12ab748c8697
md"**Prelim** : Set environment variable to main project.toml. Note that this step won't be necessary once packages are registered."

# ╔═╡ be3f8c35-dfe3-4c93-92fe-0eea6af13496
md"**1.** Importing the relevant packages we will need"

# ╔═╡ bb41c689-b81f-45db-bf1f-fdcd2f09645e
md" ## PROBLEM INPUT DATA" 

# ╔═╡ c438fdc1-c598-4a64-ba83-779dbc87951e
md"""**2.** Next, the problem data is input by specifying the following in turn: the time structure **`T`**, **`products`**, **`nodes`**, **`links`**, and **`global_data`.**"""

# ╔═╡ ca35a0c7-5d76-4024-a366-76ff8e4eb5d6
md" ### TimeStructure"

# ╔═╡ 0c3943ff-b70f-4f1d-bb48-b74417856285
md"""**a.** `T` which defines the overall `TimeStructure`. Let's consider an operational decision-making problem with a project life time of 4 hours with operational decisions made every 1 hour."""

# ╔═╡ 0827d85b-8112-41b0-bfe5-97eb448b1ac4
overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,4,1))

# ╔═╡ e8f9148e-314c-49f6-b3d5-2eb45eb1095f
md" ### Products"

# ╔═╡ 4d647ea3-ce9c-4d98-a467-bd6fd249f3fd
md"**b.** Define the products which are structs in `{ResourceEmit, ResourceCarrier} <: Resource`"

# ╔═╡ 6346dcd7-ed99-4591-80b1-b7823d95d43e
Power = EnergyModelsBase.ResourceCarrier("Power", 0.0)

# ╔═╡ a82e484b-e845-4c16-a9bb-9d12e2e9cfdf
H2    = EnergyModelsBase.ResourceCarrier("H2", 0.0)

# ╔═╡ 05616de7-36e9-43b2-8161-450a7e4837b7
products = [Power, H2]

# ╔═╡ 07f1d5aa-1704-4c82-97a8-c742aeaf4f1b
md" ### Nodes"

# ╔═╡ c1284454-6342-4ee8-8dbb-28cb5c47a74d
md"**c.** Step 3: Define the `nodes`"

# ╔═╡ 97654c21-a774-4beb-ac6c-ddc9b775f7e0
md"i. For convenience, one defines a central node for each area through which all the flows in an area are routed. This would be of type `EnergyModelsBase.GenAvailability` in a single area case or `Geography.GeoAvailability` if multiple areas with inter-area import/export is allowed"

# ╔═╡ 8db84d0c-863a-429b-a1f0-5f384079ea2e
Central_node = EnergyModelsBase.GenAvailability("CN", Dict(products .=> 0), Dict(products .=> 0))

# ╔═╡ be2c38d5-8383-4305-a7ea-59b32af30319
md"ii. Following this, one can define the appropriate `Source`, `Network` and `Sink`nodes"

# ╔═╡ 484d7bc6-c9d5-4b52-af79-c677b85227cd
Wind_turbine = EnergyModelsBase.RefSource("WT", FixedProfile(100), FixedProfile(0), FixedProfile(0), Dict(Power => 1), Dict(), Dict()) 

# ╔═╡ 6a67b83c-61b0-436e-9064-aa1f3c131632
PEM_electrolyzer = EnergyModelsBase.RefGeneration("PEM", FixedProfile(100), FixedProfile(10), FixedProfile(0), Dict(Power => 1), Dict(H2 => 0.62), Dict(), 0.0, Dict())

# ╔═╡ b672dffc-12eb-49af-8031-ef07ad9a5fd3
End_hydrogen_consumer = EnergyModelsBase.RefSink("Con",FixedProfile(50),Dict(:Surplus => FixedProfile(0), :Deficit => FixedProfile(2000)), Dict(H2 => 1), Dict())

# ╔═╡ 777fb62b-d5a4-4fee-859c-620943cfc70c
nodes = [Central_node, Wind_turbine, PEM_electrolyzer, End_hydrogen_consumer]

# ╔═╡ 0fc91bd6-c347-4e0b-aa39-c2bdd5f1e0e9
md" ### Links"

# ╔═╡ a11c0fe4-a6d4-4455-99cd-237e7cd97e93
md"**d.** Next we define the links between the different nodes. This is where the directionality of the links with respect to the central node becomes useful. Note that all the links are defined as either to or from the central node." 

# ╔═╡ 9866bd6e-9aec-462e-bcd0-5677a640491e
links = [
	EnergyModelsBase.Direct("nWT_c",Wind_turbine,Central_node,EnergyModelsBase.Linear())
	EnergyModelsBase.Direct("c_nPEM",Central_node,PEM_electrolyzer,EnergyModelsBase.Linear())
	EnergyModelsBase.Direct("nPEM_c",PEM_electrolyzer,Central_node,EnergyModelsBase.Linear())
	EnergyModelsBase.Direct("c_nCon",Central_node,End_hydrogen_consumer,EnergyModelsBase.Linear())
]

# ╔═╡ 6c355d3e-0d7b-4eee-bae8-9ccccb0684a0
md"**e.** Now we are ready to define the problem instance which is a `Dict()` containing the following keys"

# ╔═╡ a035c429-3a1d-41ad-b3b1-d52cb664f922
problem_data = Dict(
	:T => overall_time_structure,
	:products => products,
	:nodes => nodes,
	:links => links,
	:global_data => EnergyModelsBase.GlobalData(Dict())
)

# ╔═╡ 4af1a55f-9226-4789-97ba-8a035f51896d
md" ## OPTIMIZATION PROBLEM FORMULATION"

# ╔═╡ 67a6ccfb-d5c2-4429-8f10-6deaf2bf281a
md"**3.** To formulate the problem. The basic choice provided by `EnergyModelsBase.jl` is for an `OperationalModel`. The `InvestmentModels.jl` package also provides an `InvestmentModel`. Select `modeltype` to be of type `OperationalModel`"

# ╔═╡ e4b31615-9fa3-4533-abde-404c356df1e1
m = EnergyModelsBase.create_model(problem_data, OperationalModel())

# ╔═╡ a691b8e0-d36e-4ec9-8f4f-7b40e7597666
JuMP.set_optimizer(m, GLPK.Optimizer)

# ╔═╡ 4f4837b6-45b7-4345-b63b-4b1e90158aaf
optimize!(m)

# ╔═╡ c1be8c5a-f99b-4c07-aa93-c5f38ff49825
@test JuMP.termination_status(m) == OPTIMAL

# ╔═╡ c4973400-af54-4722-9c37-69ed3d622de1
println("objective value ", objective_value(m))

# ╔═╡ 789f4079-5245-4fe7-ae29-fdaa85e82b81
md"Processing the results"

# ╔═╡ c85bec0c-1c41-4e2f-bd4f-cd065913707f
begin
	cap_inst = value.(m[:cap_inst])
	cap_use = value.(m[:cap_use])
	sink_surplus = value.(m[:sink_surplus])
	sink_deficit = value.(m[:sink_deficit])
	flow_in = value.(m[:flow_in])
	flow_out = value.(m[:flow_out])
end

# ╔═╡ c01261ce-f214-4c1f-90f2-ae035bb4fc3b
num,tmax = size(cap_inst)

# ╔═╡ b957f59f-e6c7-4293-ad19-17cb8f2c5791
x_t = 1:tmax

# ╔═╡ caaeac75-ad1f-4273-9906-b285519734e7
pl = plot(x_t, cap_inst.data[1,:])

# ╔═╡ ac936503-b2a8-4ae5-9cab-6d5aa6aaa1e0
plot!(pl, x_t, cap_inst.data[1,:])

# ╔═╡ ee070acf-b62e-4b64-8ea8-2de4f6cd5eb7


# ╔═╡ 60232869-7650-4e24-b5fe-7f21819524eb


# ╔═╡ 8d89df90-62bd-4975-a009-791c25023bef


# ╔═╡ 1f54488f-02f2-49f2-adf2-3a774a340333


# ╔═╡ c2902637-ac19-432b-9a11-39b14b8a8d1d
alue.(m)

# ╔═╡ 3682b2ee-7aef-4ca9-aaad-68c0eba119de
typeof(m[:cap_use])

# ╔═╡ 5e74a6f2-7d07-422a-a0b2-6834c801ff52


# ╔═╡ 797b02d2-cb69-4e1f-b0b0-1ce5b1f39f61


# ╔═╡ 020354f3-8afb-479a-af7e-d398c740283e


# ╔═╡ 216964cb-6e3d-4999-b7ea-03ecfe56d872


# ╔═╡ d8578d99-15d9-46c4-aec9-1e4f79a53859
cap_inst.data[1, :]

# ╔═╡ ca0d00f3-35b8-415c-86dc-3a0b4dba2fe7


# ╔═╡ b8d1fe30-6932-455f-8fd0-92454726e68b


# ╔═╡ f62686a9-f2de-4e31-9480-d1f08f776210


# ╔═╡ 8b2b6bbc-2d75-4e2b-94c6-78b1edec9e9b
for node in axes(cap_inst, 1)
	#for t in axes(cap_inst, 2)
		cap_inst[node]
	#end
end

# ╔═╡ a4e1da7c-8ecf-45b6-b8df-0cd675bd9f5b


# ╔═╡ daed0385-64bc-4398-9935-5b23c8013c18


# ╔═╡ bc1c6fb3-2829-43d9-b5d4-c243ee01da4c
n1 = axes(cap_inst, 1)[1]

# ╔═╡ 2414cf44-de7a-4c6b-aef7-4d01d547789f
ci_vals = cap_inst[n1, :]

# ╔═╡ 55ed14b9-2efe-4e7c-803a-17a176436311
typeof(ci_vals)

# ╔═╡ fdea234f-757a-4ebb-9749-d8c6985fe657


# ╔═╡ 51d3cd8e-355c-4241-a3e9-39885e8e9a81
plot(ci_vals)

# ╔═╡ 7877474b-ca18-41f2-8136-ea0422816ca2


# ╔═╡ 98b25511-8e02-41fc-8539-335bc76f16c2


# ╔═╡ d073297c-7d9a-42e8-a949-d873298f7819


# ╔═╡ f6b22b2e-d809-4281-8f0d-498462492c95


# ╔═╡ e3a4544e-0afb-417a-80eb-9de2f5eafd28


# ╔═╡ 9d72d0da-db93-4946-95c8-5176d4cc3f75


# ╔═╡ dda04bf3-78cd-42ca-aec3-993b96408385
typeof(cap)

# ╔═╡ 85644e9f-118f-4170-9570-ede0ff64112c
axes(cap_inst, 1)

# ╔═╡ 48705e93-a8be-4512-ae7b-147c12bb3656
axes(cap_inst, 2)

# ╔═╡ d218660b-503b-4302-9571-e96644a86c0d


# ╔═╡ 00253df1-2bec-4468-91b0-fe2333597c2b


# ╔═╡ 7112f5a0-3938-40b1-885c-7b4857685d90


# ╔═╡ 47ba2e33-b40a-4a5f-a8b6-7b53507b97cf


# ╔═╡ beb23356-06bd-479b-8551-2ae2be3de9f6


# ╔═╡ e55dc75d-9835-4bd3-b67f-16ff027c145d


# ╔═╡ 564b4401-7d5b-46d1-adc7-f55c1db38938
cap[nWT, t1_1]

# ╔═╡ 6b1aca48-950f-4451-b4a7-6661ee58d055


# ╔═╡ 7cef1121-ed4d-470e-b843-73ed6a67d4cd


# ╔═╡ c7b35f76-23e3-4af0-82bc-4f7347d17eb2


# ╔═╡ 037d377e-2d79-4c09-8d38-b58baeea8985


# ╔═╡ 94995bf0-8144-419c-b5ff-ceff87852ebf


# ╔═╡ acd53228-7ff9-4d49-8ad7-cc61f1573e46
plot(value.(m[:cap_inst]))

# ╔═╡ ded52127-9dc1-46e3-99c0-9c477064b8e9


# ╔═╡ Cell order:
# ╟─b950ee83-8262-4bad-9ed8-9994b506e3f5
# ╟─b3c176c4-7f22-4ecf-8f0b-9e5cbeca0162
# ╟─3c777be7-fe54-4d0b-ba51-12ab748c8697
# ╠═5b1b825d-4533-4411-bcde-a0eb79b3c0b8
# ╟─be3f8c35-dfe3-4c93-92fe-0eea6af13496
# ╠═7afb886a-612b-417e-9678-8cf1b6ea04a5
# ╟─bb41c689-b81f-45db-bf1f-fdcd2f09645e
# ╟─c438fdc1-c598-4a64-ba83-779dbc87951e
# ╟─ca35a0c7-5d76-4024-a366-76ff8e4eb5d6
# ╟─0c3943ff-b70f-4f1d-bb48-b74417856285
# ╠═0827d85b-8112-41b0-bfe5-97eb448b1ac4
# ╟─e8f9148e-314c-49f6-b3d5-2eb45eb1095f
# ╟─4d647ea3-ce9c-4d98-a467-bd6fd249f3fd
# ╠═6346dcd7-ed99-4591-80b1-b7823d95d43e
# ╠═a82e484b-e845-4c16-a9bb-9d12e2e9cfdf
# ╠═05616de7-36e9-43b2-8161-450a7e4837b7
# ╟─07f1d5aa-1704-4c82-97a8-c742aeaf4f1b
# ╟─c1284454-6342-4ee8-8dbb-28cb5c47a74d
# ╟─97654c21-a774-4beb-ac6c-ddc9b775f7e0
# ╠═8db84d0c-863a-429b-a1f0-5f384079ea2e
# ╟─be2c38d5-8383-4305-a7ea-59b32af30319
# ╠═484d7bc6-c9d5-4b52-af79-c677b85227cd
# ╠═6a67b83c-61b0-436e-9064-aa1f3c131632
# ╠═b672dffc-12eb-49af-8031-ef07ad9a5fd3
# ╠═777fb62b-d5a4-4fee-859c-620943cfc70c
# ╟─0fc91bd6-c347-4e0b-aa39-c2bdd5f1e0e9
# ╟─a11c0fe4-a6d4-4455-99cd-237e7cd97e93
# ╠═9866bd6e-9aec-462e-bcd0-5677a640491e
# ╟─6c355d3e-0d7b-4eee-bae8-9ccccb0684a0
# ╠═a035c429-3a1d-41ad-b3b1-d52cb664f922
# ╟─4af1a55f-9226-4789-97ba-8a035f51896d
# ╟─67a6ccfb-d5c2-4429-8f10-6deaf2bf281a
# ╠═e4b31615-9fa3-4533-abde-404c356df1e1
# ╠═a691b8e0-d36e-4ec9-8f4f-7b40e7597666
# ╠═4f4837b6-45b7-4345-b63b-4b1e90158aaf
# ╠═c1be8c5a-f99b-4c07-aa93-c5f38ff49825
# ╠═c4973400-af54-4722-9c37-69ed3d622de1
# ╟─789f4079-5245-4fe7-ae29-fdaa85e82b81
# ╠═c85bec0c-1c41-4e2f-bd4f-cd065913707f
# ╠═c01261ce-f214-4c1f-90f2-ae035bb4fc3b
# ╠═b957f59f-e6c7-4293-ad19-17cb8f2c5791
# ╠═caaeac75-ad1f-4273-9906-b285519734e7
# ╠═ac936503-b2a8-4ae5-9cab-6d5aa6aaa1e0
# ╠═ee070acf-b62e-4b64-8ea8-2de4f6cd5eb7
# ╠═60232869-7650-4e24-b5fe-7f21819524eb
# ╠═8d89df90-62bd-4975-a009-791c25023bef
# ╠═1f54488f-02f2-49f2-adf2-3a774a340333
# ╠═c2902637-ac19-432b-9a11-39b14b8a8d1d
# ╠═3682b2ee-7aef-4ca9-aaad-68c0eba119de
# ╠═5e74a6f2-7d07-422a-a0b2-6834c801ff52
# ╠═797b02d2-cb69-4e1f-b0b0-1ce5b1f39f61
# ╠═020354f3-8afb-479a-af7e-d398c740283e
# ╠═216964cb-6e3d-4999-b7ea-03ecfe56d872
# ╠═d8578d99-15d9-46c4-aec9-1e4f79a53859
# ╠═ca0d00f3-35b8-415c-86dc-3a0b4dba2fe7
# ╠═b8d1fe30-6932-455f-8fd0-92454726e68b
# ╠═f62686a9-f2de-4e31-9480-d1f08f776210
# ╠═8b2b6bbc-2d75-4e2b-94c6-78b1edec9e9b
# ╠═a4e1da7c-8ecf-45b6-b8df-0cd675bd9f5b
# ╠═daed0385-64bc-4398-9935-5b23c8013c18
# ╠═bc1c6fb3-2829-43d9-b5d4-c243ee01da4c
# ╠═2414cf44-de7a-4c6b-aef7-4d01d547789f
# ╠═55ed14b9-2efe-4e7c-803a-17a176436311
# ╠═fdea234f-757a-4ebb-9749-d8c6985fe657
# ╠═51d3cd8e-355c-4241-a3e9-39885e8e9a81
# ╠═7877474b-ca18-41f2-8136-ea0422816ca2
# ╠═98b25511-8e02-41fc-8539-335bc76f16c2
# ╠═d073297c-7d9a-42e8-a949-d873298f7819
# ╠═f6b22b2e-d809-4281-8f0d-498462492c95
# ╠═e3a4544e-0afb-417a-80eb-9de2f5eafd28
# ╠═9d72d0da-db93-4946-95c8-5176d4cc3f75
# ╠═dda04bf3-78cd-42ca-aec3-993b96408385
# ╠═85644e9f-118f-4170-9570-ede0ff64112c
# ╠═48705e93-a8be-4512-ae7b-147c12bb3656
# ╠═d218660b-503b-4302-9571-e96644a86c0d
# ╠═00253df1-2bec-4468-91b0-fe2333597c2b
# ╠═7112f5a0-3938-40b1-885c-7b4857685d90
# ╠═47ba2e33-b40a-4a5f-a8b6-7b53507b97cf
# ╠═beb23356-06bd-479b-8551-2ae2be3de9f6
# ╠═e55dc75d-9835-4bd3-b67f-16ff027c145d
# ╠═564b4401-7d5b-46d1-adc7-f55c1db38938
# ╠═6b1aca48-950f-4451-b4a7-6661ee58d055
# ╠═7cef1121-ed4d-470e-b843-73ed6a67d4cd
# ╠═c7b35f76-23e3-4af0-82bc-4f7347d17eb2
# ╠═037d377e-2d79-4c09-8d38-b58baeea8985
# ╠═94995bf0-8144-419c-b5ff-ceff87852ebf
# ╠═acd53228-7ff9-4d49-8ad7-cc61f1573e46
# ╠═ded52127-9dc1-46e3-99c0-9c477064b8e9
