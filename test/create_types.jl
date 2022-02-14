@testset "Create types" begin

    GB = 10
    PER = 20
    baseindex = 100.0
    
    v = rand(PER, GB) .- 0.25
    ipc = capitalize(v, baseindex)
    w = rand(GB)

    basedate = Date(2010,12)
    enddate = basedate + Month(PER-1)
    dates = basedate:Month(1):enddate

    ## Create individual types with same arrays: FullCPIBase, VarCPIBase, IndexCPIBase
    fullcpi = FullCPIBase(ipc, v, w, dates, baseindex)
    vcpi = VarCPIBase(v, w, dates, baseindex)
    indexcpi = IndexCPIBase(ipc, w, dates, baseindex)

    # Test they share the same arrays
    @test fullcpi.ipc === indexcpi.ipc
    @test fullcpi.v === vcpi.v
    @test fullcpi.w === vcpi.w === indexcpi.w
    
    # Create copies with constructors from FullCPIBase and test they hold different arrays
    vcpi2 = VarCPIBase(fullcpi)
    indexcpi2 = IndexCPIBase(fullcpi)

    @test vcpi.v == vcpi2.v     # same values in matrix
    @test !(vcpi.v === vcpi2.v) # different reference in memory

    @test indexcpi.ipc == indexcpi2.ipc
    @test !(indexcpi.ipc === indexcpi2.ipc)

    @test vcpi.dates == vcpi2.dates
    @test indexcpi.dates == indexcpi2.dates


    ## Test convert methods with different precision floats
    fullcpi32 = convert(Float32, deepcopy(fullcpi))
    vcpi32 = convert(Float32, deepcopy(vcpi))
    indexcpi32 = convert(Float32, deepcopy(indexcpi))
    
    # as matrixs are different type, == does not apply, check with isapprox
    @test fullcpi32.ipc ≈ fullcpi.ipc   
    @test fullcpi32.v == vcpi32.v

    @test indexcpi32.ipc ≈ indexcpi.ipc
    @test fullcpi32.ipc == indexcpi32.ipc
    
    @test vcpi32.v ≈ vcpi.v
    @test fullcpi32.baseindex == vcpi32.baseindex == indexcpi32.baseindex

    
    ## Create types with different base indexes
    baseindex = rand(100:0.5:110, GB)

    fullcpi_b = FullCPIBase(ipc, v, w, dates, baseindex)
    vcpi_b = VarCPIBase(fullcpi_b)
    indexcpi_b = IndexCPIBase(vcpi_b)

    # Test they hold the same base indexes, but not same arrays
    @test vcpi_b.baseindex == indexcpi_b.baseindex
    @test !(vcpi_b.baseindex === indexcpi_b.baseindex)
    @test length(fullcpi_b.baseindex) > 1
    @test length(vcpi_b.baseindex) > 1
    @test length(indexcpi_b.baseindex) > 1


    ## Create CountryStructure 

    # These hold the same v array values (not same array objects) with different base indexes
    cs = MixedCountryStructure((vcpi, vcpi_b))

    @test cs[1].v == cs[2].v
    @test !(cs[1].v === cs[2].v)
    @test typeof(cs[1].baseindex) != typeof(cs[2].baseindex) # different containers
    @test eltype(cs[1].baseindex) == eltype(cs[2].baseindex) # same types
    @test length(cs[1].baseindex) != length(cs[2].baseindex) # different length

    # Check conversion of precision types
    cs32 = convert(Float32, cs)
    
    @test cs32[1].v ≈ cs[1].v
    @test eltype(cs32[1].baseindex) == Float32

end