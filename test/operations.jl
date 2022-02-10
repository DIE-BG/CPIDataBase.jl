@testset "Operations with types" begin 

    using CPIDataBase
    S = 10
    v = zeros(S, S)

    ## Test capitalize
    @test :capitalize in names(CPIDataBase)

    # Test capitalization with default base index
    cap = capitalize(v)
    @test all(cap .== 100)

    # Test capitalization with different base index
    @test all(capitalize(v, 110) .== 110)

    base_idx = rand(100:110, S)
    cap = capitalize(v, base_idx)
    @test all(100 .<= cap[1, :] .<= 110)
    
    # Test capitalize_addbase
    cap = CPIDataBase.capitalize_addbase(v, base_idx)
    @test all(100 .<= cap[1, :] .<= 110)
    @test size(cap, 1) == size(v, 1)+1

    ## Test varinterm 
    # TODO
    
    ## Test varinteran
    # TODO

end
