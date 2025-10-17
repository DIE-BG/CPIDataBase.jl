struct InflationSpliceUnweighted <: InflationFunction
    f::Vector{<:InflationFunction}
    name::Union{Nothing, AbstractString}
    tag::Union{Nothing, AbstractString}

    function InflationSpliceUnweighted(
            f::Vector{<:InflationFunction},
            name::Union{Nothing, AbstractString} = nothing,
            tag::Union{Nothing, AbstractString} = nothing
        )
        return new(f, name, tag)
    end
end


function InflationSpliceUnweighted(
        f::Vector{<:InflationFunction};
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )
    return InflationSpliceUnweighted(f, name, tag)
end


function InflationSpliceUnweighted(
        f::Vararg{<:InflationFunction};
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )
    return InflationSpliceUnweighted(collect(f); name, tag)
end

function (sfn::InflationSpliceUnweighted)(base::VarCPIBase)
    return @error "InflationSpliceUnweighted only works over CountryStructure objects."
end

"""
    InflationSplice <: InflationFunction

Inflation Function for splicing the results of several inflation functions over
transition date intervals.

f_ramp_down: Vector of InflationFunction to be used before the transition dates
f_ramp_up: Vector of InflationFunction to be used after the transition dates
dates: Vector of Tuple{Date, Date} indicating the transition intervals
name: Optional name for the InflationSplice function
tag: Optional tag for the InflationSplice function
"""
struct InflationSplice <: InflationFunction
    f_ramp_down::Vector{<:InflationFunction}
    f_ramp_up::Vector{<:InflationFunction}
    dates::Vector{Tuple{Date, Date}}
    name::Union{Nothing, AbstractString}
    tag::Union{Nothing, AbstractString}

    function InflationSplice(
            f_ramp_down::Vector{<:InflationFunction},
            f_ramp_up::Vector{<:InflationFunction},
            dates::Vector{Tuple{Date, Date}},
            name::Union{Nothing, AbstractString} = nothing,
            tag::Union{Nothing, AbstractString} = nothing
        )

        _validate_dates(dates)

        length(f_ramp_down) == length(f_ramp_up) ||
            throw(ArgumentError("The vectors f_ramp_down and f_ramp_up must have the same length."))

        length(dates) == length(f_ramp_down) && length(dates) == length(f_ramp_up) ||
            throw(ArgumentError("The number of date intervals must match the number of functions in f_ramp_down and f_ramp_up."))


        return new(f_ramp_down, f_ramp_up, dates, name, tag)
    end
end


function InflationSplice(
        f::Vector{<:InflationFunction};
        dates::Union{Nothing, Vector{Tuple{Date, Date}}} = nothing,
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )
    return InflationSplice(f[1:(end - 1)], f[2:end], dates, name, tag)
end


function InflationSplice(
        f::Vararg{<:InflationFunction};
        dates::Union{Nothing, Vector{Tuple{Date, Date}}} = nothing,
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )
    return InflationSplice(collect(f); dates, name, tag)
end


"""
    (inflfn::InflationSplice)(base::VarCPIBase)


Evaluate the InflationSplice function on a given VarCPIBase `base`, returning the corresponding CPIVarInterm.
"""
function (sfn::InflationSplice)(base::VarCPIBase)

    v = zeros(eltype(base), periods(base))

    for (f, g, d) in zip(sfn.f_ramp_down, sfn.f_ramp_up, sfn.dates)

        f_w = ramp_down(eltype(base), base.dates, d...)
        g_w = ramp_up(eltype(base), base.dates, d...)

        v = v .+ (f(base) .* f_w) .+ (g(base) .* g_w)
    end

    return v
end


"""
    measure_name(inflfn::InflationSplice)
Return the name of all the InflationFunction components of the InflationSplice,
concatenated with "--" as separator, unless a specific name is provided.
"""
function measure_name(inflfn::InflationSplice)
    s_ramp_down = string((measure_name.(inflfn.f_ramp_down) .* "--")...)
    s_last = string(measure_name.(inflfn.f_ramp_up[end]))
    return string(s_ramp_down, s_last)
end


"""
    measure_tag(inflfn::InflationSplice)
Return the tag of all the InflationFunction components of the InflationSplice,
concatenated with "--" as separator, unless a specific name is provided.
"""
function measure_tag(inflfn::InflationSplice)
    s_ramp_down = string((measure_tag.(inflfn.f_ramp_down) .* "--")...)
    s_last = string(measure_tag.(inflfn.f_ramp_up[end]))
    return string(s_ramp_down, s_last)
end

# Helper functions
"""
    _validate_dates(dates::Vector{Tuple{Date, Date}})

This helper function validates that the input vector of date tuples meets the following criteria:
1) Within each tuple: ini < fin
2) Between consecutive tuples: fin[i] < ini[i+1]  (ascending temporal order and no overlap)
"""
function _validate_dates(dates::Vector{Tuple{Date, Date}})
    # inside each tuple: tuple[1] < tuple[2]
    @inbounds for (ini, fin) in dates
        ini < fin || throw(ArgumentError("Each tuple must satisfy tuple[1] < tuple[2]; received ($ini, $fin)."))
    end

    # Between consecutive tuples: tuple[i][2] < tuple[i+1][1]  (ascending temporal order and no overlap)
    @inbounds for i in firstindex(dates):(lastindex(dates) - 1)
        dates[i][2] < dates[i + 1][1] ||
            throw(
            ArgumentError(
                "Overlapping or unordered intervals between $i and $(i + 1): " *
                    "$(dates[i][2]) vs $(dates[i + 1][1])."
            )
        )
    end
    return nothing
end

"""
    ramp_up(::Type{R}, X::AbstractRange{<:T}, a::T, b::T) where {R <: AbstractFloat, T <: Integer}

Generates a "ramp up" weight vector over the range X, transitioning from 1 to 0
between points a and b. Only weights for the X range are outputted.
"""
function ramp_up(::Type{R}, X::AbstractRange{<:T}, a::T, b::T) where {R <: AbstractFloat, T <: Integer}

    # Starting point of the ramp
    A = min(a, b)
    # Ending point of the ramp
    B = max(a, b)

    # preallocate the output weight vector given the input range X
    ramp_weights = Vector{R}(undef, length(X))

    # walking through all elements in the range X
    for (i, x) in enumerate(X)

        # for all the values prior the starting point of the ramp, the weight is 1
        if x <= A
            ramp_weights[i] = 0

            # for all the values within the ramp, the weight decreases linearly from 1 to 0
        elseif A < x <= B
            ramp_weights[i] = (x - A) / (B - A)

            # for all the values after the ending point of the ramp, the weight is 0
        else
            ramp_weights[i] = 1
        end
    end
    return ramp_weights
end


"""
    ramp_up(::Type{R}, X::StepRange{Date, T}, a::Date, b::Date) where {T <: Period, R <: AbstractFloat}

Generates a "ramp up" weight vector over the date range X, transitioning from 1 to 0
between dates a and b. Only weights for the X range are outputted.
"""
function ramp_up(::Type{R}, X::StepRange{Date, T}, a::Date, b::Date) where {T <: Period, R <: AbstractFloat}
    # constructing a int range from the date range
    X_extended = min(a, b, X[1]):X.step:max(a, b, X[end])
    X_int = findfirst(X_extended .== X[1]):findfirst(X_extended .== X[end])
    a_int = findfirst(X_extended .== a)
    b_int = findfirst(X_extended .== b)
    return ramp_up(R, X_int, a_int, b_int)
end


"""
    ramp_down(::Type{R}, X::AbstractRange{<:T}, a::T, b::T) where {R <: AbstractFloat, T <: Integer}
Generates a "ramp down" weight vector over the range X, transitioning from 0 to 1
between points a and b. 

only weights for the X range are outputted.
"""
function ramp_down(::Type{R}, X::AbstractRange{<:T}, a::T, b::T) where {R <: AbstractFloat, T <: Integer}
    return 1 .- ramp_up(R, X, a, b)
end


"""
    ramp_down(::Type{R}, X::StepRange{Date, T}, a::Date, b::Date) where {T <: Period, R <: AbstractFloat}
Generates a "ramp down" weight vector over the date range X, transitioning from 0 to 1
between dates a and b. 

only weights for the X range are outputted.
"""
function ramp_down(::Type{R}, X::StepRange{Date, T}, a::Date, b::Date) where {T <: Period, R <: AbstractFloat}
    return 1 .- ramp_up(R, X, a, b)
end

#=
"""
    (inflfn::InflationSplice)(cs::CountryStructure, ::CPIVarInterm)

Evaluate the InflationSplice function on a given CountryStructure `cs`, 
returning the corresponding CPIVarInterm.

If no transition dates are specified, the function concatenates the intermediate
monthly variations from each inflation function directly, assuming that each
function corresponds to a different base in the CountryStructure.

If transition dates are provided, it creates "ramp down" and "ramp up" weights 
to smoothly transition between the results of the different inflation functions
over the specified date intervals.
"""

function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIVarInterm)
    f = inflfn.f
    dates = inflfn.dates

    # In the case that no transition period is designated, the monthly variations are concatenated directly
    if isnothing(dates)

        @assert length(f) >= length(cs.base) "if no transition dates are given, the number of functions must match the number of bases"

        L = cumsum([periods(x) for x in cs.base])
        LL = hcat(vcat([1], L[1:(end - 1)] .+ 1), L)
        W = map(x -> x(cs, CPIVarInterm()), f)
        OUT = vcat([W[i][LL[i, 1]:LL[i, 2]] for i in 1:length(L)]...)

        # In the case that a transition period is desired, on and off "ramps" are created
    else
        X = index_dates(cs)
        F = ramp_down(eltype(cs), X, dates[1]...)
        G = ramp_up(eltype(cs), X, dates[1]...)
        OUT = (f[1](cs, CPIVarInterm())) .* F .+ (f[2](cs, CPIVarInterm())) .* G

        if length(dates) >= 2
            for i in 2:length(dates)
                F = CPIDataBase.ramp_down(eltype(cs), X, dates[i]...)
                G = CPIDataBase.ramp_up(eltype(cs), X, dates[i]...)
                OUT = OUT .* F
                OUT = OUT + f[i + 1](cs, CPIVarInterm()) .* G
            end
        end
    end
    return convert(Array{eltype(cs)}, OUT)
end


"""
    (inflfn::InflationSplice)(cs::CountryStructure)
Evaluate the InflationSplice function on a given CountryStructure `cs`.
"""
function (inflfn::InflationSplice)(cs::CountryStructure)
    cpi_index = inflfn(cs, CPIIndex())
    return varinteran(cpi_index)
end


"""
    (inflfn::InflationSplice)(cs::CountryStructure, ::CPIIndex)
Evaluate the InflationSplice function on a given CountryStructure `cs` and 
returning the corresponding CPIIndex.
"""
function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIIndex)
    v_interm = inflfn(cs, CPIVarInterm())
    capitalize!(v_interm, 100)
    return v_interm
end


"""
    (inflfn::InflationSplice)(cs::CountryStructure, ::CPIVarInterm, date::Date)

Evaluate the InflationSplice function on a given CountryStructure `cs`, 
returning the corresponding CPIVarInterm.

If no transition dates are specified, the function concatenates the intermediate
monthly variations from each inflation function directly, assuming that each
function corresponds to a different base in the CountryStructure.

If transition dates are provided, it creates "ramp down" and "ramp up" weights 
to smoothly transition between the results of the different inflation functions
over the specified date intervals.
"""
function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIVarInterm, date::Date)
    f = inflfn.f
    dates = inflfn.dates

    # In the case that no transition period is designated, the monthly variations are concatenated directly
    if isnothing(dates)

        @assert length(f) >= length(cs.base) "if no transition dates are given, the number of functions must match the number of bases"

        L = cumsum([periods(x) for x in cs.base])
        LL = hcat(vcat([1], L[1:(end - 1)] .+ 1), L)
        W = map(x -> x(cs, CPIVarInterm(), date), f)
        OUT = vcat([W[i][LL[i, 1]:LL[i, 2]] for i in 1:length(L)]...)

        # In the case that a transition period is desired, on and off "ramps" are created
    else
        X = index_dates(cs)
        F = ramp_down(eltype(cs), X, dates[1]...)
        G = ramp_up(eltype(cs), X, dates[1]...)
        OUT = (f[1](cs, CPIVarInterm(), date)) .* F .+ (f[2](cs, CPIVarInterm(), date)) .* G

        if length(dates) >= 2
            for i in 2:length(dates)
                F = ramp_down(eltype(cs), X, dates[i]...)
                G = ramp_up(eltype(cs), X, dates[i]...)
                OUT = OUT .* F
                OUT = OUT + f[i + 1](cs, CPIVarInterm(), date) .* G
            end
        end
    end
    return convert(Array{eltype(cs)}, OUT)
end


"""
    (inflfn::InflationSplice)(cs::CountryStructure, date::Date)
Evaluate the InflationSplice function on a given CountryStructure `cs`,
starting from a specific date.
"""
function (inflfn::InflationSplice)(cs::CountryStructure, date::Date)
    cpi_index = inflfn(cs, CPIIndex(), date)
    return varinteran(cpi_index)
end


"""
    (inflfn::InflationSplice)(cs::CountryStructure, ::CPIIndex)
Evaluate the InflationSplice function on a given CountryStructure `cs`,
starting from a specific date and returning the corresponding CPIIndex.
"""
function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIIndex, date::Date)
    v_interm = inflfn(cs, CPIVarInterm(), date::Date)
    capitalize!(v_interm, 100)
    return v_interm
end




"""
    splice_length(inflfn::InflationFunction)
Return the number of inflation functions in the InflationSplice.
If the input is not an InflationSplice, return 1.
"""
function splice_length(inflfn::InflationFunction)
    if !(inflfn isa InflationSplice)
        return 1
    else
        return length(inflfn.f)
    end
end


"""
    splice_inflfns(inflfn::InflationFunction)
Return the vector of inflation functions in the InflationSplice.
If the input is not an InflationSplice, return the input itself.
"""
function splice_inflfns(inflfn::InflationFunction)
    if !(inflfn isa InflationSplice)
        return inflfn
    else
        return inflfn.f
    end
end


"""
    splice_dates(inflfn::InflationFunction)
Return the vector of transition date tuples in the InflationSplice.
If the input is not an InflationSplice, return NaN.
"""
function splice_dates(inflfn::InflationFunction)
    if !(inflfn isa InflationSplice)
        return NaN
    end
    return inflfn.dates
end


"""
    components(inflfn::InflationSplice)
Return a DataFrame with the components of the InflationSplice, including
the measure names and weights of each inflation function, as well as the
transition dates if specified.
"""
function components(inflfn::InflationSplice)
    if isnothing(inflfn.dates)
        if inflfn.f isa Vector{CombinationFunction{A, B}} where {A} where {B}
            components = [
                DataFrame(
                        measure = measure_name.(x.ensemble),
                        weights = x.weights
                    )
                    for x in inflfn.f
            ]
        else
            components = DataFrame(
                measure = measure_name.(inflfn.f)
            )
        end
    else
        components = DataFrame(
            measure = measure_name.(inflfn.f),
            dates = [NaN, inflfn.dates...]
        )
    end
    return components
end
=#
