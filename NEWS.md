Release Notes
=============

Version 0.5.1 (2024-02-16)
--------------------------
 * Introduced a new type `SimpleElectrolyzer` to implement stack degradation and minimum operational point without the penalty of the bilinear term.
 * Add `EnergyModelsInvestments` as weak dependency to avoid cration of unnecessary variables for the reformulation of the bilinear terms.
 * Introduced utilities that can be used for the bilinear reformulation.

Version 0.5.0 (2024-02-14)
--------------------------
 * Adjusted to changes introduced throuch EnergyModelsBase version 0.6.
 * Representative periods in `TimeStruct` are now included for the calculation of the efficiency penalty.

Version 0.4.0 (2023-06-02)
--------------------------
### Switch to TimeStruct.jl
 * Switched the time structure representation to [TimeStruct.jl](https://gitlab.sintef.no/julia-one-sintef/timestruct.jl)
 * TimeStruct.jl is implemented with only the basis features that were available in TimesStructures.jl. This implies that neither operational nor strategic uncertainty is included in the model

Version 0.3.0 (2023-05-31)
--------------------------
 * Adjustment to changes in `EnergyModelsBase` v0.4.0 related to extra input data

Version 0.2.1 (2023-05-15)
--------------------------
 * Adjustment to changes in `EnergyModelsBase` v0.3.3 related to the calls for the constraint functions

Version 0.2.0 (2023-02-03)
--------------------------
### Adjustmends to updates in EnergyModelsBase
Adjustment to version 0.3.0, namely:
* The removal of emissions from `Node` type definition that do not require them. In this case, this is the type `Electrolyzer` and all tests
* Adjustment of the changes in the call of `variables_node`
* Utlization of the new function calls for constraint generations
* Removal of the type `GlobalData` and replacement with fields in the type `OperationalModel` in all tests

Version 0.1.3 (2023-01-13)
--------------------------
### Bug fixes
* Fixed a bug, that required stack replacement in all years after the initial stack replacement

Version 0.1.2 (2023-01-10)
--------------------------
### Bug fixes
* Fixed a bug that forces the electrolyser to operate when the parameter Minimum_load was not equal to 0

Version 0.1.1 (2022-12-12)
--------------------------
Updated Readme

Version 0.1.0 (2022)
--------------------------
Initial version