using CPIDataBase, Dates
using CPIDataBase.TestHelpers
using DataFrames
using Test


@testset "$(T) for the output of ramp_up and ramp_down" for T in (Float16, Float32, Float64)
    up = ramp_up(T, 1:10, 1, 10)
    down = ramp_down(T, 1:10, 1, 10)

    @test isa(up, Vector{T}) && length(up) == 10
    @test isa(down, Vector{T}) && length(down) == 10
end

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
