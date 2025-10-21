using CPIDataBase
using InflationFunctions
using Dates
using Test

@testset "InflationSpliceFunction Tests" begin


    # Testing ramp_up and ramp_down functions for different types of outputs
    @testset "$(T) for the output of ramp_up and ramp_down" for T in (Float16, Float32, Float64)
        up = ramp_up(T, 1:10, 1, 10)
        down = ramp_down(T, 1:10, 1, 10)

        @test isa(up, Vector{T}) && length(up) == 10
        @test isa(down, Vector{T}) && length(down) == 10
    end
    #testing ramp_up and ramp_down for different types of invalid inputs
    @testset "Errors for ramp_up and ramp_down with invalid inputs" begin
        @test_throws MethodError ramp_up(Float32, 1:10, 2.5, 8.9)
        @test_throws MethodError ramp_down(Float32, 1:10, 2.5, 8.9)
        @test_throws MethodError ramp_up(Float32, range(1.0, 10.0, step = 1.0), 2.5, 8.9)
        @test_throws MethodError ramp_down(Float32, range(1.0, 10.0, step = 1.0), 2.5, 8.9)
        @test_throws MethodError ramp_up(Float32, 1:10, 2.5, "a")
        @test_throws MethodError ramp_down(Float32, 1:10, 2.5, "a")
        @test_throws MethodError ramp_up(Float32, 1:10, Date(2000), 5)
        @test_throws MethodError ramp_up(Float32, 1:10, Date(2000), Date(2001))
    end

    # testing ramp_up and ramp_down with Date inputs
    @testset "ramp_up and ramp_down with Date as input" begin
        @test isa(
            ramp_up(Float32, Date(2010, 1):Date(2010, 10), Date(2010, 10), Date(2010, 1)),
            Vector{Float32}
        )
        @test isa(
            ramp_up(Float32, Date(2010, 1):Date(2010, 10), Date(2010, 1), Date(2010, 10)),
            Vector{Float32}
        )
        @test isa(
            ramp_down(Float32, Date(2010, 1):Date(2010, 10), Date(2010, 10), Date(2010, 1)),
            Vector{Float32}
        )
        @test isa(
            ramp_down(Float32, Date(2010, 1):Date(2010, 10), Date(2010, 1), Date(2010, 10)),
            Vector{Float32}
        )
    end

    # Testing the behavior of ramp_up and ramp_down with different input types,
    # comparing the results with manually constructed reference vectors
    @testset "Behavior of ramp_up and ramp_down when inputs are integers" begin
        @test all(
            ramp_up(Float16, 1:10, 1, 10) .== collect(range(Float16(0), Float16(1), length = 10))
        )
        @test all(
            ramp_down(Float16, 1:10, 1, 10) .== Float16(1) .- collect(range(Float16(0), Float16(1), length = 10))
        )

        @test let
            reference = range(Float16(0), Float16(1), length = 10) |> collect
            reference = reference[5:end]
            all(ramp_up(Float16, 5:10, 1, 10) .== reference)
        end

        @test let
            reference = range(Float16(0), Float16(1), length = 10) |> collect
            reference = reference[5:end]
            reference = Float16(1) .- reference
            all(ramp_down(Float16, 5:10, 1, 10) .== reference)
        end

        @test let
            reference = range(Float16(0), Float16(1), length = 10) |> collect
            reference = reference[1:5]
            all(ramp_up(Float16, 1:5, 1, 10) .== reference)
        end

        @test let
            reference = range(Float16(0), Float16(1), length = 10) |> collect
            reference = reference[1:5]
            reference = Float16(1) .- reference
            all(ramp_down(Float16, 1:5, 1, 10) .== reference)
        end
    end

    # Testing the behavior of ramp_up and ramp_down with Date inputs, comparing the results
    # with manually constructed reference vectors
    @testset "Behavior of ramp_up and ramp_down when inputs are Dates" begin

        @test let
            reference = range(0.0, 1.0, length = 10) |> collect
            to_test = ramp_up(
                Float64,
                Date(0, 1, 1):Date(0, 1, 10),
                Date(0, 1, 1), Date(0, 1, 10)
            )

            all(to_test .== reference)
        end

        @test let
            reference = range(0.0, 1.0, length = 10) |> collect
            reference = 1.0 .- reference
            to_test = ramp_down(
                Float64,
                Date(0, 1, 1):Date(0, 1, 10),
                Date(0, 1, 1), Date(0, 1, 10)
            )

            all(to_test .== reference)
        end

        @test let
            reference = range(0.0, 1.0, length = 10) |> collect
            reference = reference[5:end]
            to_test = ramp_up(
                Float64,
                Date(0, 1, 5):Date(0, 1, 10),
                Date(0, 1, 1), Date(0, 1, 10)
            )
            all(to_test .== reference)
        end

        @test let
            reference = range(0.0, 1.0, length = 10) |> collect
            reference = reference[5:end]
            reference = 1.0 .- reference
            to_test = ramp_down(
                Float64,
                Date(0, 1, 5):Date(0, 1, 10),
                Date(0, 1, 1), Date(0, 1, 10)
            )
            all(to_test .== reference)
        end

        @test let
            reference = range(0.0, 1.0, length = 10) |> collect
            reference = reference[1:5]
            to_test = ramp_up(
                Float64,
                Date(0, 1, 1):Date(0, 1, 5),
                Date(0, 1, 1), Date(0, 1, 10)
            )
            all(to_test .== reference)
        end

        @test let
            reference = range(0.0, 1.0, length = 10) |> collect
            reference = reference[1:5]
            reference = 1.0 .- reference
            to_test = ramp_down(
                Float64,
                Date(0, 1, 1):Date(0, 1, 5),
                Date(0, 1, 1), Date(0, 1, 10)
            )
            all(to_test .== reference)
        end
    end


    # Testing the instantiation of an InflationSplice
    @testset "Instantiating a InflationSplice" begin


        #not enough functions
        @test_throws "ArgumentError" InflationSplice(
            inflfn[1:(end - 1)];
            dates = dates, name = "Test Splice", tag = "TS1"
        )
        @test_throws "ArgumentError" InflationSplice(
            inflfn[1:(end - 1)] ...;
            dates = dates, name = "Test Splice", tag = "TS1"
        )

        #to many functions
        @test_throws "ArgumentError" InflationSplice(
            [inflfn..., inflfn[1]];
            dates = dates, name = "Test Splice", tag = "TS1"
        )
        @test_throws "ArgumentError" InflationSplice(
            [inflfn..., inflfn[1]]...;
            dates = dates, name = "Test Splice", tag = "TS1"
        )

        #incorrect order between tuples of dates
        @test_throws "ArgumentError" InflationSplice(
            inflfn;
            dates = [
                (Date(0, 9), Date(0, 12)), #<-- This one should be second
                (Date(0, 1), Date(0, 3)),
            ]
        )

        #incorrect order inside a tuple of dates
        @test_throws "ArgumentError" InflationSplice(
            inflfn;
            dates = [
                (Date(0, 1), Date(0, 3)),
                (Date(0, 12), Date(0, 9)), #<-- This one is incorrect
            ]
        )
    end

    # testing the calculations of an InflationSplice
    @testset "Calculations of an InflationSplice" begin
        # Definition of the testing structures used throughout the tests
        test_base = hcat(
            collect(1.0:10.0),
            collect(10.0:10.0:100.0),
            collect(100.0:100.0:1_000.0)
        )
        test_base = Float16.(test_base)

        test_weights = Float16.(1 / 3 .* ones(3))

        test_dates_1 = Date(0, 1):Month(1):Date(0, 10)
        test_dates_2 = Date(0, 11):Month(1):Date(1, 8)

        test_base1 = VarCPIBase(
            test_base,
            test_weights,
            test_dates_1,
            Float16(100)
        )

        test_base2 = VarCPIBase(
            test_base,
            test_weights,
            test_dates_2,
            Float16(100)
        )

        test_countryStructure = UniformCountryStructure(
            test_base1,
            test_base2
        )

        # inflation functions and dates for testing InflationSplice
        inflfn = [InflationPercentileEq(0.25), InflationPercentileEq(0.5), InflationPercentileEq(0.75)]
        dates = [
            (Date(0, 2), Date(0, 4)),
            (Date(0, 9), Date(0, 12)),
        ]

        # Inflation Splice function instance for testing
        splicefn = InflationSplice(inflfn; dates = dates)

        # The true results calculated manually
        true_result_1 = Float16.([5.5, 11, 23.25, 40, 50, 60, 70, 80, 90, 250])
        true_result_2 = Float16.([40, 110, 165, 220, 275, 330, 385, 440, 495, 550])

        test_1 = splicefn(test_base1)
        test_2 = splicefn(test_base2)
        test_3 = splicefn(test_countryStructure, CPIVarInterm())

        @test all(test_1 .== true_result_1)
        @test all(test_2 .== true_result_2)
        @test all(test_3 .== vcat(true_result_1, true_result_2))
    end


end
