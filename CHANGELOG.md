## [Unreleased] 

## [0.6.25] 2025-10
### Changed

- The `Splice` function has been redefined by introducing the abstract type `InflationSpliceFunction` and implementing their concrete behavior in the `InflationSplice` struct. The function now operates directly on a `VarCPIBase`, as all other inflation functions are required to do.

## [0.6.24] 2025-10

### Changed
- Added the mean of all monthly price changes to the `show` method for the `VarCPIBase`, `IndexCPIBase`, and `FullCPIBase` objects to quickly inspect it in the REPL.

## [0.6.23] 2025-10

### Fixed
- Fix broken `show` methods for `VarCPIBase`, `IndexCPIBase`, and `FullCPIBase` caused by API changes in PrettyTables.jl v3 — restores compatibility. (closes [#28](https://github.com/DIE-BG/CPIDataBase.jl/issues/28))
