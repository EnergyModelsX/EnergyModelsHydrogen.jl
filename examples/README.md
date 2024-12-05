# Running the examples

You have to add the package `EnergyModelsHydrogen` to your current project in order to run the examples.
It is not necessary to add the other used packages, as the example is instantiating itself.
How to add packages is explained in the *[Quick start](https://energymodelsx.github.io/EnergyModelsHydrogen.jl/stable/manual/quick-start/)* of the documentation

You can run from the Julia REPL the following code:

```julia
# Import EnergyModelsHydrogen
using EnergyModelsHydrogen

# Get the path of the examples directory
exdir = joinpath(pkgdir(EnergyModelsHydrogen), "examples")

# Include the following code into the Julia REPL to run the reformer example
include(joinpath(exdir, "reformer.jl"))

# Include the following code into the Julia REPL to run the electrolyzer example
include(joinpath(exdir, "electrolyzer.jl"))

# Include the following code into the Julia REPL to run the H₂ storage example
include(joinpath(exdir, "h2_storage.jl"))
```
