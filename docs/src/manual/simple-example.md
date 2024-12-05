# [Examples](@id man-exampl)

For the content of the example, see the *[examples](https://github.com/EnergyModelsX/EnergyModelsHydrogen.jl/tree/main/examples)* directory in the project repository.

!!! note "Solver"
    If you use windows, you must have installed the binaries of the solver in addition.
    This is explained on the *[quick start](@ref man-quick_start)* page.

## The package is installed with `] add`

From the Julia REPL, run

```julia
# Starts the Julia REPL
julia> using EnergyModelsHydrogen
# Get the path of the examples directory
julia> exdir = joinpath(pkgdir(EnergyModelsHydrogen), "examples")
# Include the code into the Julia REPL to run the electrolyzer node example
julia> include(joinpath(exdir, "electrolyzer.jl"))
# Include the code into the Julia REPL to run the reformer node example
julia> include(joinpath(exdir, "reformer.jl"))
# Include the code into the Julia REPL to run the H2 storage ndoe example
julia> include(joinpath(exdir, "h2_storage.jl"))
```

## The code was downloaded with `git clone`

The examples can then be run from the terminal with

```shell script
/path/to/EnergyModelsHydrogen.jl/examples $ julia electrolyzer.jl
/path/to/EnergyModelsHydrogen.jl/examples $ julia reformer.jl
/path/to/EnergyModelsHydrogen.jl/examples $ julia h2_storage.jl
```
