using CPIDataBase, Dates
using CPIDataBase.TestHelpers
using DataFrames
using Test

countrydata = getrandomcountryst()
infl_cpi = InflationTotalCPI()(countrydata)

@testset "InflationCombination" begin
    
    @testset "Pruebas sin name y sin tag" begin
        combfn = InflationCombination(
            InflationTotalCPI(), 
            InflationTotalCPI(), 
            Float32[0.5, 0.5]
        )

        @test contains(lowercase(measure_name(combfn)), "promedio")
        @test measure_tag(combfn) == "COMBFN"
        @test all(combfn(countrydata) .≈ infl_cpi)
    end

    @testset "Pruebas con name y no tag" begin 
        combfn = InflationCombination(
            InflationTotalCPI(), 
            InflationTotalCPI(), 
            Float32[0.5, 0.5], 
            "Promedio InflationTotalCPI"
            )

        @test contains(measure_name(combfn), "InflationTotalCPI")
        @test measure_tag(combfn) == "COMBFN"
        @test all(combfn(countrydata) .≈ infl_cpi)
    end

    @testset "Pruebas con name y tag" begin
        combfn = InflationCombination(
            InflationTotalCPI(), 
            InflationTotalCPI(), 
            Float32[0.5, 0.5], 
            "Promedio InflationTotalCPI",
            "COMBFNTOTAL"
        )

        @test contains(measure_name(combfn), "InflationTotalCPI")
        @test measure_tag(combfn) == "COMBFNTOTAL"
        @test all(combfn(countrydata) .≈ infl_cpi)
    end

    @testset "Pruebas con ponderadores con suma = 1.5" begin
        combfn = InflationCombination(
            InflationTotalCPI(), 
            InflationTotalCPI(), 
            Float32[1, 0.5], 
            "Promedio InflationTotalCPI mayor que 1",
            "COMBFNTOTAL1"
        )

        # Promedio interanual 
        @test all(combfn(countrydata) .≈ 1.5*infl_cpi)
    end

end