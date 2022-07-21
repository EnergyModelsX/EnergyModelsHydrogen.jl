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
end

# ╔═╡ b950ee83-8262-4bad-9ed8-9994b506e3f5
md"""# Model over only 1 geographical area.
- `Area 1`: Wind Power turbine to Electrolysis converter to produce hydrogen. One hydrogen end consumer. 
  
**Note**  : This simple example only relies on the functionality of `EnergyModelsBase`, `TimeStructures`. The `Geography` package is not required since only 1 local area is considered. It provides a reference for the basic functionality which will then be extended by `EnergyModelsHydrogen`."""

# ╔═╡ 3c777be7-fe54-4d0b-ba51-12ab748c8697
md"**Prelim** : Set environment variable to main project.toml. Note that this step won't be necessary once packages are registered."

# ╔═╡ be3f8c35-dfe3-4c93-92fe-0eea6af13496
md"**1.** Importing the relevant packages we will need"

# ╔═╡ c438fdc1-c598-4a64-ba83-779dbc87951e
md"""**2.** Next, the problem data is input by specifying the following in turn: the time structure `T`, `products`, `nodes`, `links`, and `global_data`."""

# ╔═╡ 0c3943ff-b70f-4f1d-bb48-b74417856285
md"""**a.** `T` which defines the overall `TimeStructure`. Let's consider an operational decision-making problem with a project life time of 4 hours with operational decisions made every 1 hour."""

# ╔═╡ 0827d85b-8112-41b0-bfe5-97eb448b1ac4
overall_time_structure = UniformTwoLevel(1,1,1,UniformTimes(1,4,1))

# ╔═╡ a8331194-8284-4f5e-9f85-adf0f7f9c50e


# ╔═╡ 4eb2e4f2-c98d-439e-a096-18a35ee8a3f7


# ╔═╡ 4d647ea3-ce9c-4d98-a467-bd6fd249f3fd


# ╔═╡ efd1eb9a-7e22-44e9-8cac-b5c2d16f86ad


# ╔═╡ c36a7009-5456-467d-87b6-923c15674ac9


# ╔═╡ 0930906d-33bc-482e-8c1b-deca8aa7b34b


# ╔═╡ 358d0067-46a9-4e67-9755-761c9ea52885


# ╔═╡ a142522b-b05d-4748-b6cf-f13a4e247afa


# ╔═╡ 4e3e7752-aa93-448e-929f-937108b34f06


# ╔═╡ 378fd107-8a45-48b2-8d29-cb495a96a3a0


# ╔═╡ 125e358b-a522-463d-af14-73d19befb871


# ╔═╡ d9fc05a9-fbde-416c-b1f3-5fd9ef07815f


# ╔═╡ e6557ecc-7069-4722-853d-e59429141f5d


# ╔═╡ b0c3106d-4ba7-46fb-9851-1376451faf8f


# ╔═╡ Cell order:
# ╟─b950ee83-8262-4bad-9ed8-9994b506e3f5
# ╟─3c777be7-fe54-4d0b-ba51-12ab748c8697
# ╠═5b1b825d-4533-4411-bcde-a0eb79b3c0b8
# ╟─be3f8c35-dfe3-4c93-92fe-0eea6af13496
# ╠═7afb886a-612b-417e-9678-8cf1b6ea04a5
# ╟─c438fdc1-c598-4a64-ba83-779dbc87951e
# ╟─0c3943ff-b70f-4f1d-bb48-b74417856285
# ╠═0827d85b-8112-41b0-bfe5-97eb448b1ac4
# ╠═a8331194-8284-4f5e-9f85-adf0f7f9c50e
# ╠═4eb2e4f2-c98d-439e-a096-18a35ee8a3f7
# ╠═4d647ea3-ce9c-4d98-a467-bd6fd249f3fd
# ╠═efd1eb9a-7e22-44e9-8cac-b5c2d16f86ad
# ╠═c36a7009-5456-467d-87b6-923c15674ac9
# ╠═0930906d-33bc-482e-8c1b-deca8aa7b34b
# ╠═358d0067-46a9-4e67-9755-761c9ea52885
# ╠═a142522b-b05d-4748-b6cf-f13a4e247afa
# ╠═4e3e7752-aa93-448e-929f-937108b34f06
# ╠═378fd107-8a45-48b2-8d29-cb495a96a3a0
# ╠═125e358b-a522-463d-af14-73d19befb871
# ╠═d9fc05a9-fbde-416c-b1f3-5fd9ef07815f
# ╠═e6557ecc-7069-4722-853d-e59429141f5d
# ╠═b0c3106d-4ba7-46fb-9851-1376451faf8f
