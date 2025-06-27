# Release Notes

## Unversioned

* Renamed `Data` to `ExtensionData` as introduced in [`EnergyModelsBase` v0.9.1](https://github.com/EnergyModelsX/EnergyModelsBase.jl/releases/tag/v0.9.1).

## Version 0.8.1 (2025-02-10)

* Adjusted to [`EnergyModelsBase` v0.9.0](https://github.com/EnergyModelsX/EnergyModelsBase.jl/releases/tag/v0.9.0):
  * Increased version nubmer for EMB.
  * Model worked without adjustments.
  * Adjustments only required for simple understanding of changes.

## Version 0.8.0 (2024-12-05)

### Rework of stack replacement

* Replaced the formulation in stack replacement with an approach reducing the number of binary variables.
* The approach is equivalent to the previous with respect to the results.
* The documentation is updated with the new formulation.

### Hydrogen storage

* Developed two nodes for hydrogen storage:
  1. `SimpleHydrogenStorage` incorporates a constraint on the maximum discharge through a multiplier of the charge capacity as well as providing an upper bound for the maximum charge capacity as a function of the storage level capacity.
  2. `HydrogenStorage` includes a storage level dependent term for the compression electricity requirement using a piecewise linear representation of the non-linear compression curves through SOS2 constraints and a bilinear term.
    Investment are not possible for this node.
* Included checks, documentations, and tests for both nodes.
* Included an example for `HydrogenStorage`.

### Misc

* Split file `constraint_functions.jl`:
  * `constraint/general.jl` for methods dispatching on `EnergyModelsBase` constraints,
  * `constraint/electrolyzer.jl` for functions introduced for `AbstractElectrolyzer` types, and
  * `constraint/reformer.jl` for functions introduced for `Reformer` nodes.
* Updated the checks with the new functionality from `EnergyModelsBase` v0.8.3.
* Included a *how to contribute* section to documentation.

## Version 0.7.3 (2024-11-11)

* Fixed a bug when providing a lower bound in linear refomulation enforcing in this case 100 % usage of the node.
* Added tests for linear reformulation to avoid any future issues.

## Version 0.7.2 (2024-11-03)

### Enhancement

* Provide the correct lower and upper bounds for the lienar reformulation.

### Bugfix

* Reverted change included in 0.7.0 point 2 as the previous implementation was after all correct.
* The error did not have any impact on the results if the lower bound was specified as larger than 0. It would however impact the linear relaxation as the constraints were not as tight.

## Version 0.7.1 (2024-10-24)

* Included new examples for both reformer and electrolysis.
* Minor updates on docstrings and descriptions.
* Adjusted to [`EnergyModelsBase` v0.8.1](https://github.com/EnergyModelsX/EnergyModelsBase.jl/releases/tag/v0.8.1).

## Version 0.7.0 (2024-08-02)

### Feature - Ramping

* Added rate of change constraints for reformer to limit its change within a given time.
* The constraint is only active if the reformer is not switching state through implementation of a disjunction.
* It is possible to only limit the positive or negative utilization change through the application of `AbstractRampParameters`.

### Documentation

* Added external references to refer to types and methods from `EnergyModelsBase`.
* Significantly improved the documentation through inclusion of the mathematical descriptions for the individual nodes as well as restructuring the library.

### Enhancement

* Rewrote the dynamic constraints for improved potential for extensions with differing time structures and in preparation for a receding horizon framework.
* Moved the load limits to a separate type for a reduced number of input of the different `Node`s.
* Moved the unit commitment parameters to a separate type for a reduced number of input of the different `Node`s.
* Reduced lines in test of checks.

### Bugfix

* Fixed a bug in a system with investments in which the initial valus for the `Electrolyzer` binaries were not properly applied. This appraoch lead to non-investments in electrolysis.
* Fixed an error in the function `linear_reformulation` regarding:
  1. The indexing of the bounds was wrong if the resulting variable is indexed over two time levels
  2. One of the constraints would result in wrong values if a lower bound was specified.
* The bugs in `linear_reformulation` did not affect our results as we specified a lower bound of 0 and and a ``FixedProfile` for bounds.
* Fixed a bug in the checks for the `degradation_rate` of `AbstractElectrolyzer` nodes.

## Version 0.6.2 (2024-07-24)

* Added checks and tests of the checks for both `AbstractElectrolyzer` and `AbstractReformer`.

## Version 0.6.1 (2024-07-23)

* Moved `EnergyModelsInvestments` extension to a separate subfolder in the extension folder.

## Version 0.6.0 (2024-07-23)

* Adjusted to changes introduced in `TimeStruct` v0.8 (and correspondingly `EnergyModelsBase` v0.7 and `EnergyModelsInvestments` v0.6).

### Implementation of `Reformer` node

* Reformer work as unit commitment nodes with minimum time for startup, shutdown and offline states with associated costs.
* The initial version is based on the work of Erik Svendsmark for the startup shutdown technology.
* The work was extended based on new available features in `TimeStruct` (namely `chunk` and `chunk_duration`).
* In addition, the introduced costs are now dependent on the installed capacity.

## Version 0.5.2 (2024-04-03)

* Fixed a bug when utilizing representative periods.
* Added a function for fixing the binary variables in periods they do not change.

## Version 0.5.1 (2024-02-16)

* Introduced a new type `SimpleElectrolyzer` to implement stack degradation and minimum operational point without the penalty of the bilinear term.
* Add `EnergyModelsInvestments` as weak dependency to avoid cration of unnecessary variables for the reformulation of the bilinear terms.
* Introduced utilities that can be used for the bilinear reformulation.

## Version 0.5.0 (2024-02-14)

* Adjusted to changes introduced throuch `EnergyModelsBase` v0.6.
* Representative periods in `TimeStruct` are now included for the calculation of the efficiency penalty.

## Version 0.4.0 (2023-06-02)

### Switch to TimeStruct.jl

* Switched the time structure representation to [`TimeStruct`](https://sintefore.github.io/TimeStruct.jl/stable/).
* TimeStruct is implemented with only the basis features that were available in TimesStructures.jl. This implies that neither operational nor strategic uncertainty is included in the model.

## Version 0.3.0 (2023-05-31)

* Adjustment to changes in `EnergyModelsBase` v0.4.0 related to extra input data.

## Version 0.2.1 (2023-05-15)

* Adjustment to changes in `EnergyModelsBase` v0.3.3 related to the calls for the constraint functions.

## Version 0.2.0 (2023-02-03)

### Adjustmends to updates in EnergyModelsBase

Adjustment to version `EnergyModelsBase` 0.3.0, namely:

* The removal of emissions from `Node` type definition that do not require them. In this case, this is the type `Electrolyzer` and all tests.
* Adjustment of the changes in the call of `variables_node`.
* Utlization of the new function calls for constraint generations.
* Removal of the type `GlobalData` and replacement with fields in the type `OperationalModel` in all tests.

## Version 0.1.3 (2023-01-13)

### Bug fixes

* Fixed a bug, that required stack replacement in all years after the initial stack replacement.

## Version 0.1.2 (2023-01-10)

### Bug fixes

* Fixed a bug that forces the electrolyser to operate when the parameter Minimum_load was not equal to 0.

## Version 0.1.1 (2022-12-12)

Updated Readme.

## Version 0.1.0 (2022)

Initial version.
