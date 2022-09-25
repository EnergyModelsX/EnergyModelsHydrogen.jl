### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# ╔═╡ e7b8aa14-82e7-4bb6-b47d-97a4c91cef62
begin
	using Pkg
	Pkg.activate(joinpath(@__DIR__, ".."))
end

# ╔═╡ f055a289-df3a-4ca1-89aa-8770dccdddc8
begin
	using TimeStructures
	using EnergyModelsBase
end

# ╔═╡ f1e88e7c-09bd-11ed-2d4e-ababaa4234ba
md"# INTERNALS OF CLEAN EXPORT MODEL"

# ╔═╡ 5789f16f-29b8-481d-8957-b02c0f1e2d99
@__DIR__

# ╔═╡ 3e95d186-c348-4f44-a1ef-f4d2b2f8a377
md"## SCOPE"

# ╔═╡ fa10c704-73ea-4a67-98ff-d471ec32f72a
md"This notebook summarizes how the optimization problem is built particularly using the basic functionality of `EnergyModelsBase`. The point is to allow for a quick reference when getting back to coding after a while"

# ╔═╡ 1499f20b-4280-4b4b-9cb2-e2249f4dfcf2
md"## TIMESTRUCTURES"

# ╔═╡ 58e907a2-26f4-479f-a01d-8b59c7b31698
md"
1. Begin by figuring out the project life time. Say this is 30 years. The next step is to figure out how many investments will be made in this period. Say the answer is 5, this corresponds to 5 **investment periods**, in each investment period the capacity is fixed. These 5 investment periods may be uniform (i.e., 6 years each) or dynamic (e.g., [2, 3, 5, 10, 10] years if we care more about near term resolution than far term). Each investment period is further divided into operational periods in which an operational problem is solved e.g., for the first 2 years, we may want to divide it into 731 days each lasting 24 hours. The remaining 3, 5, 10 and 10 year investment periods could each have weekly resolutions (the operation is unchanged within the week):

This case is written as


```
struct DynamicTwoLevel <: TimeStructure
	first # Start year of the analysis
	len::Integer # Number of strategic investment periods 
	duration::Array # Duration of each strategic period
	operational::Array{TimeStructure} # Àrray of operational period time structures
end
```
`T = DynamicTwoLevel(1, 5, [2, 3, 5, 10, 10], [UniformTimes(1, 52*2*7, 24), UniformTimes(1, 52*3, 24*7), UniformTimes(1, 52*5, 24*7), UniformTimes(1, 52*10, 24*7), UniformTimes(1, 52*10, 24*7))`

This is quite confusing and the notation is done poorly. Some questions/remarks:
- The top `len` denotes the number of strategic ivestment periods. For each strategic period, one can have at most one operational time structure. It is also possible for all strategic periods to have a single operational time structure (i.e., the `DynamicStrategicLevel` case).
- So for a given strategic period, the operational period is given by the `duration` field of the corresponding operational time structure.


2. Usually begin by determining the **operational time structure**: 
- `Operational_time_struct ∈ {UniformTimes, DynamicTimes}`
 Consider an operational period under study (say a year or a week), this time structure determines the time steps at which one solves an operational period. `UniformTimes` uses a **uniform time resolution** while `DynamicTimes` uses a **variable time resolution**. Both have 3 fields: `first`, `len`, `duration`; `duration` is a real number in `UniformTimes` but an array in `DynamicTimes`. The default unit is **hours**. If the user sets the operational time structure as: `UniformTimes(1, 48, 1)` it means we are looking at a 2 day period with a 1 hour resolution. One can also have `UniformTimes(1,48,4)` which is 2 days with 4 hour resolution.    


2. Defining the **overall project time structure** for both the strategic and operational problem. This usually includes the `operational_time_struct` as a field.
- `𝒯 ∈ {UniformTwoLevel, DynamicOperationalLevel, DynamicStrategicLevel, DynamicTwoLevel}`. The names of the fields are unnecessarily confusing.
Fields: 
-- `len`: Is the number of strategic periods.
-- `duration`: 
-- `operational`

3. A struct to hold a single time-step. A single time-step is generally called a **TimePeriod** and it could be a single operational time-step or strategic time-step:
- `OperationalPeriod <: TimePeriod{UniformTwoLevel}`
- `StrategicPeriod <: TimePeriod{UniformTwoLevel}`
"

# ╔═╡ 27be7592-765d-491a-921b-211b5f81d992
md" ## TIMEPROFILES"

# ╔═╡ 95ad0c8c-e317-46d2-a758-8914a08fb01b
md" Short note on **Parametric Composite Types**. This is when one wants to have the fields of a `struct` to be determined when the struct is created not when it is defined. For instance, one could have a: 
```
struct Point
	x::Float64
	y::Float64
end
```
and another
```
struct Point
	x::Int
	y::Int
end
```. However, we can allow any arbitrary concrete type of `Point` with 
```
struct Point{T}
	x::T
	y::T
end
```

All this does is specify the concrete types of the members"

# ╔═╡ 1cf75d4a-7043-4ea7-abc1-bf9e9c65299e


md" Onto **TIMEPROFILES**. Note that `TimeProfile` doesn't have much to do with time structures. Just to be more confusing.

**`TimeProfile{T}`**: This is used to define actual values of an **input parameter** defined at every time period. The structure used depends on if we want to define the parameters over the operational time structure, strategic time structure, or both. 
- `FixedProfile{T}` e.g., `capacity = FixedProfile(10.0)`
- `OperationalFixedProfile{T}. Fixed strategic profile with varying operational profiles`
- `StrategicFixedProfile{T}. Fixed operational profiles, varying strategic profiles (e.g., varying capacities)`
- `DynamicProfile{T}`"

# ╔═╡ 8298f365-55c5-4b4a-b7cb-23ceda851546
md" ## PROBLEM SET-UP"

# ╔═╡ 7da9b2e3-7954-4bc2-a177-560db4242526
md" A typical formulation is as follows:"


# ╔═╡ f610b810-3814-468c-8dee-ed523542fa0b


# ╔═╡ cfaa1d02-ec30-442e-8fe2-6dbfee41c252
md"## OPTIMIZATION PROBLEM FORMULATION"

# ╔═╡ 09161362-53e6-47bf-9658-80f9b83992d7
md"Once `create_model(case, modeltype::EnergyModel)` is called, the following 4 actions are performed:"

# ╔═╡ 3120a539-0bcb-4baa-a77a-9707b1b4fd3d
md"**1.** The problem data dictionary is unpacked and consistency checks are run"

# ╔═╡ 67743202-d571-437c-9bad-cdbf6003bfa0
md"**2.** All the optimization problem variables are declared:
In general, the sets are as follows:
- Nodes - 𝒩, time structure - 𝒯, products - 𝒫, links - ℒ
- **`variables_flow()`** `: flow_in[n,t,p], flow_out[n,t,p], link_in[l,t,p], link_out[l,t,p]`
- **`variables_emission()`** `: emissions_node[n,t,p], emissions_total[t,p], emissions_strategic[t,p]`
- **`variables_opex()`** `: opex_var[n,t], opex_fixed[n,t]`. `opex_var` is the variable opex over all the operational periods in a strategic period.
- **`variables_capex()`**
- **`variables_capacity()`** `: cap_use[n,t], cap_inst[n,t] == n.Cap. cap_use` not for `Storage` or `Availability`. Each node only has one `cap_use` for all products.
- **`variables_surplus_deficit()`** `: sink_surplus[n,t], sink_deficit[n,t]`
- **`variables_storage()`** `: stor_level[n,t], stor_rate_use[n,t], stor_cap_inst[n,t] == n.Stor_cap, stor_rate_inst[n,t] == n.Rate_cap`. Note that only a single product can be stored and this should strictly be specified in the `Input` dictionary.
- **`variables_node()`**. For later use."

# ╔═╡ 687ef3f7-122c-40a6-a2f2-455c71655627
md"**3.** The constraints are introduced:"

# ╔═╡ a9c15d96-a666-4671-b523-afe8a4e499f7
md"
- **`constraints_node()`** :"

# ╔═╡ a9537c72-5d65-4b09-9312-ba7a22bbc4ec
md"**i.** constrains the input (`flow_in[n,t,p]`) and output (`flow_out[n,t,p]`) flows from a node to be equal to the sum of the correspond link flows (`link_in[l,t,p]`) and (`link_out[l,t,p]`)"

# ╔═╡ e908c021-a296-4d63-a45b-6e636eaf0ae3
md"**ii.** Creates node specific constraints `create_node`
- `create_node(n::Source)`: Sets `flow_out` to be the `cap_use*n.Output` i.e., the characteristic capacity into the `Output` multiple from dictionary. Similarly, sets `emissions_node` and `opex_var` (over the entire strategic period). 
- `create_node(n::Network)`: Sets `flow_in` and `flow_out` to be a multiple of the characteristic capacity and the corresponding multiples in `Input` or `Output`.
- `create_node(n::Storage)`: Sets the characteristic flow `stor_rate_use` to be the `flow_in` of the specified product in `Input` with the multiple of 1. Introduces the time dependent constraints on `stor_level` linking it in with the previous level. Also sets the relations with the `flow_out` variable 
- `create_node(n::Sink)`: Sets the relationship between `flow_in`, `cap_use` and the `Input` dictionary. Allows use of `sink_deficit` and `sink_surplus` to supply `cap_inst`[?? - This means `cap_inst` is like the set demand but we can go above and below]. Sets the `opex_var` for the strategic period. "


# ╔═╡ 86da1dea-0a4a-4fea-8496-d4eecec731d4
md"**iii.** constrains the fixed opex `opex_fixed` based on the installed capacities (`cap_inst`) or (`stor_cap_inst`)"

# ╔═╡ 41998aea-d15b-498d-b6ad-f3fcbcc9221f
md"**`constraints_link`**: Sets mass balance constraints for every link"

# ╔═╡ Cell order:
# ╟─f1e88e7c-09bd-11ed-2d4e-ababaa4234ba
# ╟─5789f16f-29b8-481d-8957-b02c0f1e2d99
# ╟─f055a289-df3a-4ca1-89aa-8770dccdddc8
# ╟─3e95d186-c348-4f44-a1ef-f4d2b2f8a377
# ╟─fa10c704-73ea-4a67-98ff-d471ec32f72a
# ╟─1499f20b-4280-4b4b-9cb2-e2249f4dfcf2
# ╟─58e907a2-26f4-479f-a01d-8b59c7b31698
# ╟─27be7592-765d-491a-921b-211b5f81d992
# ╟─95ad0c8c-e317-46d2-a758-8914a08fb01b
# ╟─1cf75d4a-7043-4ea7-abc1-bf9e9c65299e
# ╟─e7b8aa14-82e7-4bb6-b47d-97a4c91cef62
# ╟─8298f365-55c5-4b4a-b7cb-23ceda851546
# ╟─7da9b2e3-7954-4bc2-a177-560db4242526
# ╠═f610b810-3814-468c-8dee-ed523542fa0b
# ╟─cfaa1d02-ec30-442e-8fe2-6dbfee41c252
# ╟─09161362-53e6-47bf-9658-80f9b83992d7
# ╟─3120a539-0bcb-4baa-a77a-9707b1b4fd3d
# ╟─67743202-d571-437c-9bad-cdbf6003bfa0
# ╟─687ef3f7-122c-40a6-a2f2-455c71655627
# ╟─a9c15d96-a666-4671-b523-afe8a4e499f7
# ╟─a9537c72-5d65-4b09-9312-ba7a22bbc4ec
# ╠═e908c021-a296-4d63-a45b-6e636eaf0ae3
# ╟─86da1dea-0a4a-4fea-8496-d4eecec731d4
# ╟─41998aea-d15b-498d-b6ad-f3fcbcc9221f
