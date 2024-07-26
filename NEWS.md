# Release Notes

## Unversioned (breaking changes)

### Documentation

* Added external references to refer to types and methods from `EnergyModelsBase`.

### Enhancement

* Rewrote the dynamic constraints for improved potential for extensions with differing time structures and in preparation for a receding horizon framework.
* Moved the load limits to a separate type for a reduced number of input of the different `Node`s.
* Moved the unit commitment parameters to a separate type for a reduced number of input of the different `Node`s.

### Bugfix

* Fixed a bug in a system with investments in which the initial valus for the `Electrolyser` binaries were not properly applied. This appraoch lead to non-investments in electrolysis.
* Fixed an error in the function `linear_reformulation` regarding:
  1. The indexing of the bounds was wrong if the resulting variable is indexed over two time levels
  2. One of the constraints would result in wrong values if a lower bound was specified.
* The bugs in `linear_reformulation` did not affect our results as we specified a lower bound of 0 and and a ``FixedProfile` for bounds.

## Version 0.6.2 (2024-07-24)

* Added checks and tests of the checks for both `AbstractElectrolyzer` and `AbstractReformer`.

## Version 0.6.1 (2024-07-23)

* Moved `EnergyModelsInvestments` extension to a separate subfolder in the extension folder.

## Version 0.6.0 (2024-07-23)

* Adjusted to changes introduced in `TimeStruct` v0.8 (and correspondingly `EnergyModelsBase` v0.7 and `EnergyModelsInvestments` v0.6).

### Implementation of Reformer node

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

* Adjusted to changes introduced throuch EnergyModelsBase version 0.6.
* Representative periods in `TimeStruct` are now included for the calculation of the efficiency penalty.

## Version 0.4.0 (2023-06-02)

### Switch to TimeStruct.jl

* Switched the time structure representation to [`TimeStruct`](https://sintefore.github.io/TimeStruct.jl/stable/).
* TimeStruct.jl is implemented with only the basis features that were. available in TimesStructures.jl. This implies that neither operational nor strategic uncertainty is included in the model

## Version 0.3.0 (2023-05-31)

* Adjustment to changes in `EnergyModelsBase` v0.4.0 related to extra input data.

## Version 0.2.1 (2023-05-15)

* Adjustment to changes in `EnergyModelsBase` v0.3.3 related to the calls for the constraint functions.

## Version 0.2.0 (2023-02-03)

### Adjustmends to updates in EnergyModelsBase

Adjustment to version 0.3.0, namely:

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

Updated Readme

## Version 0.1.0 (2022)

Initial version
