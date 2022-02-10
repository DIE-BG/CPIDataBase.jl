using CPIDataBase, Dates
using CPIDataBase.TestHelpers
using DataFrames
using Test

# Creation of types
include("create_types.jl")

# Test some VarCPIBase and CountryStructure operations
include("operations.jl")

# Inflation tests with MixedCountryStructure
include("inflation.jl")

# Trees creation and operations 
include("cpitree.jl")


# # @testset "Inflation values and dates with disjoint VarCPIBase objects" begin 

#     base1 = getrandombase(Float32, 218, 120, Date(2001,1))
#     base2 = getrandombase(Float32, 279, 120, Date(2011,4), rand(100:0.25:105, 279))
#     cst = MixedCountryStructure(base1, base2)
# # end
