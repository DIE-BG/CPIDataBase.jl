using CPIDataBase, Dates
using CPIDataBase.TestHelpers
using DataFrames
using Test

# Creation of types
include("create_types.jl")

# InflationCombination
include("InflationCombination.jl")

# Test some VarCPIBase and CountryStructure operations
include("operations.jl")

# Inflation tests with MixedCountryStructure
include("inflation.jl")

# Trees creation and operations 
include("cpitree.jl")