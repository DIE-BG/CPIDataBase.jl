using CPIDataBase, Dates
using CPIDataBase.TestHelpers
using DataFrames
using Test

# Guatemalan CPI datasets for tests with actual data. After load_data(), you can
# access actual VarCPIBase and CountryStructure objects such as FGT10, GTDATA24
using CPIDataGT
CPIDataGT.load_data()

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

# InflationSplice tests 
# to-do