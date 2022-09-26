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
- The overall time structure is divided into **strategic/investment periods** and **operational periods**. A capital investment into a given capacity can be made once within a strategic period; this capacity is then fixed for all **operational periods** within this strategic period.

For example, consider a project life time of 30 years. The next step is to figure out how many investments will be made in this period. Say the answer is 5, this corresponds to 5 **strategic periods**. These 5 strategic/investment periods may be uniform (i.e., 6 years each) or dynamic (e.g., [2, 3, 5, 10, 10] years if we care more about investing in the near-term than far term).

- Each investment period is further divided into operational periods in which an operational problem is solved. For each strategic period, one can have at most one operational time structure. It is also possible for all strategic periods to have a single operational time structure (i.e., the `DynamicStrategicLevel` case).

- The most general overall time structure is:
```
struct DynamicTwoLevel <: TimeStructure
	first # Start year of the analysis
	len::Integer # Number of strategic investment periods 
	duration::Array # Duration of each strategic period
	operational::Array{TimeStructure} # Àrray of operational period time structures
end
```

- **Note**
- The top-level `len` corresponds to the number of strategic investment periods.
- The top-level `duration` corresponds to the number of **years** in each of the strategic/investment periods. 
- The units of `duration` in the `operational` time structure is [hours]. Thus, `duration` denotes the resolution at the operational level. 
- `len` in the operational time structure denotes the number of time steps (each of resolution given by `duration`).
- For consistency, the length of each element of the `operational` time structure **must** be 8760 hours i.e., `@assert op.len*op.duration == 8760` must be true for all elements of `operational`.
- The `Operational_time_struct ∈ {UniformTimes, DynamicTimes}`. `UniformTimes` uses a **uniform time resolution** while `DynamicTimes` uses a **variable time resolution**. Both have 3 fields: `first`, `len`, `duration`; `duration` is a real number in `UniformTimes` but an array in `DynamicTimes`. The default unit is **hours**. If the user sets the operational time structure as: `UniformTimes(1, 48, 1)` it means we are looking at a 2 day period with a 1 hour resolution. One can also have `UniformTimes(1,48,4)` which is 2 days with 4 hour resolution.

Returning to the example, for the first 2 years, we may want to solve the operational problem with an hourly resolution (thus `op.duration == 1`). we may want to use a daily resolutions for the 2nd and 3rd investment period (thus `op.duration` = 24) and a weekly resolution for the 4th and 5th investment periods (this `op.duration` = 24*7).

The timestructure  for this example is written as:

`𝒯 = DynamicTwoLevel(1, 5, [2, 3, 5, 10, 10], [UniformTimes(1, 8760, 1), UniformTimes(1, 365, 24), UniformTimes(1, 365, 24), UniformTimes(1, (8760/(24*7)), 24*7), UniformTimes(1, (8760/(24*7)), 24*7)]`

**Confusing notation**
- There seems to be no real reason to use the fields `len` and `duration` for both strategic and operational time structures. 
- The term `duration` is unclear. At the top-level, it is used to denote a multiple of the corresponding element of `operational` time structure, yet it is used to denote resolution at the operational level. This can be clarified by making the corresponding units [years] and [hours] clearer. 
- The length of each element of the `operational` time structure **must** be 8760 hours. This doesn't hold for almost all the tests and examples making all of them misleading.
"

# ╔═╡ 530dedd7-b3f0-4151-a5f3-9c6ab3dcff4c
md" ## TIMESTRUCTURE ITERATION [WIP]"

# ╔═╡ 71a23c39-473d-4193-b33a-184eae7d2878
md" Short note on how iteration works in Julia. Consider a custom data type which may be a `struct` such as a `TimeStructure`. We want to translate such a container into an **iterable**. For example, if we want to iterate through all the time steps in a given `TimeStructure`: 

```
for item in iter
	# body
end
``` 

this is translated into 
```
next = iterate(iter)
while next !== nothing
    (item, state) = next
    # body
    next = iterate(iter, state)
end
```
Thus, it is essential to add the following two methods are added to the `Base` module:
- `iterate(iter)`
- `iterate(iter, state)`"

# ╔═╡ 7d98ac6f-d04f-420c-9174-68a02eba3d65
md" The item that is returned in the iteration is a subtype of a `TimePeriod`. For the general case of iteration in the optimization model `e.g, [t ∈ 𝒯]` the item returned is an `OperationalPeriod`.
```
struct OperationalPeriod <: TimePeriod{UniformTwoLevel}
	sp
	op
	duration
end
```


**QN**: Is there any particular reason  why we use a parametric struct `TimePeriod` since both are parameterized by `UniformTwoLevel`, and none of the fields depend on the parametric input type?

- Termination condition for the iteration, given by the 
"

# ╔═╡ fab54a9c-95cf-4e97-aa4a-c7bd07250bc7
md"
`Base.length` function. Note the following: - `length` is the number of strategic periods * number of operational periods. The model does not consider the `sp.duration`. So the units are the number of 
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


# ╔═╡ cfaa1d02-ec30-442e-8fe2-6dbfee41c252
md"## OPTIMIZATION PROBLEM FORMULATION"

# ╔═╡ 09161362-53e6-47bf-9658-80f9b83992d7
md"Once `create_model(case, modeltype::EnergyModel)` is called, the following 4 actions are performed:"

# ╔═╡ 3120a539-0bcb-4baa-a77a-9707b1b4fd3d
md"**1.** The problem data dictionary is unpacked and consistency checks are run"

# ╔═╡ 67743202-d571-437c-9bad-cdbf6003bfa0
md"**2.** All the optimization problem variables are declared:
In general, the indices and sets are as follows:
- Nodes - `n ∈ 𝒩`, time structure - `t ∈ 𝒯`, products - `p ∈ 𝒫`, links - `l ∈ ℒ`
- **`variables_flow()`** `: flow_in[n,t,p], flow_out[n,t,p], link_in[l,t,p], link_out[l,t,p]`
- **`variables_emission()`** `: emissions_node[n,t,p], emissions_total[t,p], emissions_strategic[t,p]`
- **`variables_opex()`** `: opex_var[n,t], opex_fixed[n,t]`. `opex_var` is the variable opex over all the operational periods in a strategic period.
- **`variables_capex()`**
- **`variables_capacity()`** `: cap_use[n,t], cap_inst[n,t] == n.Cap. cap_use` not for `Storage` or `Availability`. Each node only has one `cap_use` for all products. **Note that `cap_use[n,t]` is the characteristic throughput of a given node at a time period `t`**.
- **`variables_surplus_deficit()`** `: sink_surplus[n,t], sink_deficit[n,t]`
- **`variables_storage()`** `: stor_level[n,t], stor_rate_use[n,t], stor_cap_inst[n,t] == n.Stor_cap, stor_rate_inst[n,t] == n.Rate_cap`. Note that only a single product can be stored and this should strictly be specified in the `Input` dictionary.
- **`variables_node(m, nodes, T, modeltype)`**. Again this seems unnecessarily complicated. The usage is as follows:
The method `variables_node(m, nodes, T, modeltype)` is called with the `𝒩, 𝒯` sets.

However, there is another `variables_node(m, 𝒩, 𝒯, node, modeltype::EnergyModel)` method (with the additional  `node` argument) that is used to create tailored constraints for each node type (why does this have to be the same name as the calling method?): 

Note the following: 
- The submethod `variables_node(m, 𝒩, 𝒯, node, modeltype::EnergyModel)` is called when the first node of a type is reached in the outer `variables_node()` method. It is not called again when the next node of that type is reached. 
- This implies that the user specialized `variables_node(m, 𝒩, 𝒯, node, modeltype::EnergyModel)` method **MUST** create variables for **ALL** nodes of the given type `node`. This is in line with JuMP variables working with sets.
"

# ╔═╡ 687ef3f7-122c-40a6-a2f2-455c71655627
md"**3.** The constraints are introduced:"

# ╔═╡ a9c15d96-a666-4671-b523-afe8a4e499f7
md"
- **`constraints_node()`** :"

# ╔═╡ a9537c72-5d65-4b09-9312-ba7a22bbc4ec
md"**i.** constrains the input (`flow_in[n,t,p]`) and output (`flow_out[n,t,p]`) flows from a node to be equal to the sum of the correspond link flows (`link_in[l,t,p]`) and (`link_out[l,t,p]`)"

# ╔═╡ e908c021-a296-4d63-a45b-6e636eaf0ae3
md"**ii.** Creates node specific constraints `create_node`.

For `Source` and `Network` nodes, this sets:
`cap_use[n, t] <= cap_inst[n, t]`.  

- `create_node(n::Source)`: Sets `flow_out` to be the `cap_use*n.Output` i.e., the characteristic capacity into the `Output` multiple from dictionary. Similarly, sets `emissions_node` and `opex_var` (over the entire strategic period). 
- `create_node(n::Network)`: Sets `flow_in` and `flow_out` to be a multiple of the characteristic capacity and the corresponding multiples in `Input` or `Output`. So 
`flow_in[n,t,p] == cap_use[n,t]*n.Input[p]`

`flow_out[n,t,p] == cap_use[n,t]*n.Output[p]`

- `create_node(n::Storage)`: Sets the characteristic flow `stor_rate_use` to be the `flow_in` of the specified product in `Input` with the multiple of 1. Introduces the time dependent constraints on `stor_level` linking it in with the previous level. Also sets the relations with the `flow_out` variable

- `create_node(n::Sink)`: Sets characteristic throughput as `flow_in`.

`flow_in[n, t, p] == cap_use[n, t] * n.Input[p]`

In this case, `cap_inst` is the set demand but we can go above and below.

`cap_use[n,t] + sink_deficit[n,t] == cap_inst[n, t] + sink_surplus[n,t]`


Sets the `opex_var` for the strategic period based on `Penalty` dict"


# ╔═╡ 86da1dea-0a4a-4fea-8496-d4eecec731d4
md"**iii.** constrains the fixed opex `opex_fixed` based on the installed capacities (`cap_inst`) or (`stor_cap_inst`). **Note that the fixed opex is a function of the installed capacity. The variable opex is a function of the characteristic `cap_use`**"

# ╔═╡ ccb5dbb2-8a15-413c-a436-21e13a9fde5d
md"**`constraints_emissions`**: Emissions constraints not very important atm"

# ╔═╡ 41998aea-d15b-498d-b6ad-f3fcbcc9221f
md"**`constraints_link`**: Sets mass balance constraints for every link.

`link_out[l, t, p] == link_in[l, t, p]`"

# ╔═╡ Cell order:
# ╟─f1e88e7c-09bd-11ed-2d4e-ababaa4234ba
# ╟─5789f16f-29b8-481d-8957-b02c0f1e2d99
# ╟─f055a289-df3a-4ca1-89aa-8770dccdddc8
# ╟─3e95d186-c348-4f44-a1ef-f4d2b2f8a377
# ╟─fa10c704-73ea-4a67-98ff-d471ec32f72a
# ╟─1499f20b-4280-4b4b-9cb2-e2249f4dfcf2
# ╟─58e907a2-26f4-479f-a01d-8b59c7b31698
# ╠═530dedd7-b3f0-4151-a5f3-9c6ab3dcff4c
# ╟─71a23c39-473d-4193-b33a-184eae7d2878
# ╠═7d98ac6f-d04f-420c-9174-68a02eba3d65
# ╠═fab54a9c-95cf-4e97-aa4a-c7bd07250bc7
# ╟─27be7592-765d-491a-921b-211b5f81d992
# ╟─95ad0c8c-e317-46d2-a758-8914a08fb01b
# ╟─1cf75d4a-7043-4ea7-abc1-bf9e9c65299e
# ╟─e7b8aa14-82e7-4bb6-b47d-97a4c91cef62
# ╟─8298f365-55c5-4b4a-b7cb-23ceda851546
# ╟─7da9b2e3-7954-4bc2-a177-560db4242526
# ╟─cfaa1d02-ec30-442e-8fe2-6dbfee41c252
# ╟─09161362-53e6-47bf-9658-80f9b83992d7
# ╟─3120a539-0bcb-4baa-a77a-9707b1b4fd3d
# ╠═67743202-d571-437c-9bad-cdbf6003bfa0
# ╟─687ef3f7-122c-40a6-a2f2-455c71655627
# ╟─a9c15d96-a666-4671-b523-afe8a4e499f7
# ╟─a9537c72-5d65-4b09-9312-ba7a22bbc4ec
# ╟─e908c021-a296-4d63-a45b-6e636eaf0ae3
# ╟─86da1dea-0a4a-4fea-8496-d4eecec731d4
# ╟─ccb5dbb2-8a15-413c-a436-21e13a9fde5d
# ╟─41998aea-d15b-498d-b6ad-f3fcbcc9221f
