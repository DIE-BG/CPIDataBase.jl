@testset "Inflation with MixedCountryStructure" begin
    
    GB = 200
    PER = 120
    baseindex = rand(100:0.5:110, GB)
    
    v = rand(PER, GB) .- 0.25
    w = rand(GB)
    w = w / sum(w)

    basedate = Date(2001,1)
    dates = getdates(basedate, PER)

    # Base with different base indexes per product
    vcpi_mixed = VarCPIBase(v, w, dates, baseindex)
    mcs = MixedCountryStructure(vcpi_mixed)

    # Basic inflation function test
    totalfn = InflationTotalCPI() 
    @test totalfn(mcs) isa Vector
    @test infl_periods(mcs) == (PER-11)

    # Mix with base with same base index
    GB = 315
    PER = 120
    baseindex = 100.0

    v2 = rand(PER, GB) .- 0.25
    w2 = rand(GB)
    w2 = w2 / sum(w)

    basedate = Date(2011,1)
    dates2 = getdates(basedate, PER)

    vcpi_uniform = VarCPIBase(v2, w2, dates2, baseindex)
    mcs = MixedCountryStructure(vcpi_mixed, vcpi_uniform)

    @test totalfn(mcs) isa Vector
    @test infl_periods(mcs) == (240-11)

    # Test indexing
    @test mcs[1] == vcpi_mixed
    @test mcs[2] == vcpi_uniform

end