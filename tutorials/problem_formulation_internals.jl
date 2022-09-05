### A Pluto.jl notebook ###
# v0.19.9

using Markdown
using InteractiveUtils

# ╔═╡ f1e88e7c-09bd-11ed-2d4e-ababaa4234ba
md"# INTERNALS OF CLEAN EXPORT MODEL"

# ╔═╡ 3e95d186-c348-4f44-a1ef-f4d2b2f8a377
md"## SCOPE"

# ╔═╡ fa10c704-73ea-4a67-98ff-d471ec32f72a
md"This notebook summarizes how the optimization problem is built particularly using the basic functionality of `EnergyModelsBase`. The point is to allow for a quick reference when getting back to coding after a while"

# ╔═╡ 1499f20b-4280-4b4b-9cb2-e2249f4dfcf2
md"## TIMESTRUCTURES"

# ╔═╡ 58e907a2-26f4-479f-a01d-8b59c7b31698
md"
1. Usually begin by determining the **operational time structure**: 
- `Operational_time_struct ∈ {UniformTimes, DynamicTimes}`

2. Defining the **overall project time structure** for both the strategic and operational problem. This usually includes the `operational_time_struct` as a field.
- `𝒯 ∈ {UniformTwoLevel, DynamicOperationalLevel, DynamicStrategicLevel, DynamicTwoLevel}`

3. A struct to hold a single time-step. A single time-step is generally called a **TimePeriod** and it could be a single operational time-step or strategic time-step:
- `OperationalPeriod <: TimePeriod{UniformTwoLevel}`
- `StrategicPeriod <: TimePeriod{UniformTwoLevel}`

4. **`TimeProfile{T}`**: This is used to define actual values of an **input parameter** defined at every time period. The structure used depends on if we want to define the parameters over the operational time structure, strategic time structure, or both. 
- `FixedProfile{T}` e.g., `capacity = FixedProfile(10.0)`
- `OperationalFixedProfile{T}`
- `StrategicFixedProfile{T}`
- `DynamicProfile{T}`
"

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
# ╟─3e95d186-c348-4f44-a1ef-f4d2b2f8a377
# ╟─fa10c704-73ea-4a67-98ff-d471ec32f72a
# ╟─1499f20b-4280-4b4b-9cb2-e2249f4dfcf2
# ╟─58e907a2-26f4-479f-a01d-8b59c7b31698
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
