# EnergyModelsHydrogen

[![Build Status](https://gitlab.sintef.no/clean_export/energymodelshydrogen.jl/badges/main/pipeline.svg)](https://gitlab.sintef.no/clean_export/energymodelshydrogen.jl/-/jobs)
[![Stable](https://img.shields.io/badge/docs-stable-4495d1.svg)](https://clean_export.pages.sintef.no/energymodelshydrogen.jl)

`EnergyModelsHydrogen` is a package extending `EnergyModelsBase` to model hydrogen production in greater detail.
It provides new types for both electrolysis and reformer technologies.

> **Note**
>
> This is an internal pre-release not intended for distribution outside the project consortium.

> **Warning**
>
> This package needs a non-linear non-convex solver to run the tests. Examples of supported solvers are SCIP and Gurobi.

## Usage

The usage of the package is best illustrated through the commented [`examples`](examples).
The examples are minimum working examples highlighting how to build simple energy system models.

## Cite

If you find `EnergyModelsHydrogen` useful in your work, we kindly request that you cite the following [publication](https://doi.org/10.21105/joss.06619):

```bibtex
@article{hellemo2024energymodelsx,
  title={EnergyModelsX: Flexible Energy Systems Modelling with Multiple Dispatch},
  author={Hellemo, Lars and B{\o}dal, Espen Flo and Holm, Sigmund Eggen and Pinel, Dimitri and Straus, Julian},
  journal={Journal of Open Source Software},
  volume={9},
  number={97},
  pages={6619},
  year={2024}
}
```

If you utilize the `Reformer` node, we kindly request that you cite the following [publication](https://doi.org/10.1016/j.apenergy.2024.124130) explaining the implementation:

```bibtex
@article{svendsmark2024,
  title = {Developing hydrogen energy hubs: {T}he role of H$_2$ prices, wind power and infrastructure investments in Northern Norway},
  author = {Erik Svendsmark and Julian Straus and Pedro {Crespo del Granado}},
  journal = {Applied Energy},
  volume = {376},
  pages = {124130},
  year = {2024},
  }
```

For earlier work, see our [paper in Applied Energy](https://www.sciencedirect.com/science/article/pii/S0306261923018482):

```bibtex
@article{boedal_2024,
  title = {Hydrogen for harvesting the potential of offshore wind: A {N}orth {S}ea case study},
  journal = {Applied Energy},
  volume = {357},
  pages = {122484},
  year = {2024},
  issn = {0306-2619},
  doi = {https://doi.org/10.1016/j.apenergy.2023.122484},
  url = {https://www.sciencedirect.com/science/article/pii/S0306261923018482},
  author = {Espen Flo B{\o}dal and Sigmund Eggen Holm and Avinash Subramanian and Goran Durakovic and Dimitri Pinel and Lars Hellemo and Miguel Mu{\~n}oz Ortiz and Brage Rugstad Knudsen and Julian Straus}
}
```

## Project Funding

The development of `EnergyModelsBase` was funded by the Norwegian Research Council in the project [Clean Export](https://www.sintef.no/en/projects/2020/cleanexport/), project number [308811](https://prosjektbanken.forskningsradet.no/project/FORISS/308811)
