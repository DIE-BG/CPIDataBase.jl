# ABSTRACT INFLATION SPLICE TYPE

"""
    InflationSpliceFunction <: InflationFunction

Abstract type for inflation functions that splice the results of several inflation
functions over transition date intervals of `VarCPIBase` in a `CountryStructure`.
"""
abstract type InflationSpliceFunction <: InflationFunction end


"""
    splice_length(inflfn::InflationSpliceFunction)

Return the number of inflation functions in the `InflationSpliceFunction`.
"""
function splice_length(inflfn::InflationSpliceFunction)
    return @error "Extend this methods for other InflationSpliceFunction types."
end


"""
    splice_functions(inflfn::InflationSpliceFunction)

Return the vector of inflation functions in `the InflationSpliceFunction`.
"""
function splice_functions(inflfn::InflationSpliceFunction)
    return @error "Extend this methods for other InflationSpliceFunction types."
end


"""
    splice_dates(inflfn::InflationSpliceFunction)

Return the vector of transition date tuples in the `InflationSpliceFunction`.
"""
function splice_dates(inflfn::InflationSpliceFunction)
    return @error "Extend this methods for other InflationSpliceFunction types."
end


"""
    components(inflfn::InflationSpliceFunction)

Return a `DataFrame` with the components of the `InflationSpliceFunction`, including
the measure names and weights of each inflation function, as well as the
transition dates if specified.
"""
function components(inflfn::InflationSpliceFunction)
    return @error "Extend this methods for other InflationSpliceFunction types."
end


# INFLATION SPLICE --------------------------------------------------------

"""
    InflationSplice <: InflationSpliceFunction

Inflation Function for splicing the results of several inflation functions over
transition date intervals.

# Arguments
- `f_ramp_down::Vector{<:InflationFunction}`: Inflation function for the beginning of the transition period.
- `f_ramp_up::Vector{<:InflationFunction}`: Inflation function for the end of the transition period.
- `dates::Vector{Tuple{Date, Date}}`: Limits of the transition period.
- `name::Union{Nothing, AbstractString}`: Custom name for the inflation splice function.
- `tag::Union{Nothing, AbstractString}`: Custom short name for the inflation splice function.
"""
struct InflationSplice <: InflationSpliceFunction
    f_ramp_down::Vector{<:InflationFunction}
    f_ramp_up::Vector{<:InflationFunction}
    dates::Vector{Tuple{Date, Date}}
    name::Union{Nothing, AbstractString}
    tag::Union{Nothing, AbstractString}


    """
        InflationSplice(
            f::Vector{<:InflationFunction};
            dates::Union{Nothing, Vector{Tuple{Date, Date}}} = nothing,
            name::Union{Nothing, AbstractString} = nothing,
            tag::Union{Nothing, AbstractString} = nothing
        )
    
    Instantiates an `InflationSplice` function.
    
    # Arguments
    - `f::Vector{<:InflationFunction}`: Inflation function for each transition period.
    - `dates::Vector{Tuple{Date, Date}}`: Transition periods.
    - `name::Union{Nothing, AbstractString}=nothing`: Custom name for the inflation splice.
    - `tag::Union{Nothing, AbstractString}=nothing`: Custom short name for the inflation splice.
    """
    function InflationSplice(
            f::Vector{<:InflationFunction};
            dates::Vector{Tuple{Date, Date}},
            name::Union{Nothing, AbstractString} = nothing,
            tag::Union{Nothing, AbstractString} = nothing
        )

        f_ramp_down = f[1:(end - 1)]

        f_ramp_up = f[2:end]

        _validate_dates(dates)

        length(f_ramp_down) == length(f_ramp_up) ||
            throw(ArgumentError("The vectors f_ramp_down and f_ramp_up must have the same length."))

        length(dates) == length(f_ramp_down) && length(dates) == length(f_ramp_up) ||
            throw(ArgumentError("The number of date intervals must match the number of functions in f_ramp_down and f_ramp_up."))

        return new(f_ramp_down, f_ramp_up, dates, name, tag)
    end
end


"""
    InflationSplice(
        f::Vararg{<:InflationFunction};
        dates::Union{Nothing, Vector{Tuple{Date, Date}}},
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )

Create an `InflationSplice` function from a variable number of InflationFunction `f`, using the provided
transition date intervals `dates`. The number of functions in `f` must be one greater than
the length of `dates`.

# Arguments
- `f::{<:InflationFunction}`: Inflation functions for each transition period.
- `dates::Vector{Tuple{Date, Date}}`: Transition periods.
- `name::Union{Nothing, AbstractString}=nothing`: Custom name for the inflation splice.
- `tag::Union{Nothing, AbstractString}=nothing`: Custom short name for the inflation splice.
"""
function InflationSplice(
        f::Vararg{<:InflationFunction};
        dates::Vector{Tuple{Date, Date}},
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )
    return InflationSplice(collect(f); dates, name, tag)
end


"""
    (inflfn::InflationSplice)(base::VarCPIBase)

Evaluate the InflationSplice function on a given `VarCPIBase` base, returning the corresponding `::CPIVarInterm`.
"""
function (sfn::InflationSplice)(base::VarCPIBase)

    # Ordering the functions in a single vector for easier handling.
    inflfn = [sfn.f_ramp_down..., sfn.f_ramp_up[end]]

    # Getting the effective weights for each function in the splice. Te goal is to
    # have a weight matrix of size (periods(base), length(inflfn)), where
    # each row should sum to 1. and each column corresponds to the weight of
    # each function in the splice.
    effective_weights = _get_splice_weights(eltype(base), sfn, base.dates)

    # Preallocate output vector of m-o-m inflation
    v = zeros(eltype(base), periods(base))

    # Computing the weighted sum of the inflation functions over the base,
    # using the effective weights computed before.
    for (i, f) in enumerate(inflfn)
        v = v .+ (effective_weights[:, i] .* f(base))
    end

    return v
end


function measure_name(inflfn::InflationSplice)
    s_ramp_down = string((measure_name.(inflfn.f_ramp_down) .* "--")...)
    s_last = string(measure_name.(inflfn.f_ramp_up[end]))
    return string(s_ramp_down, s_last)
end


function measure_tag(inflfn::InflationSplice)
    s_ramp_down = string((measure_tag.(inflfn.f_ramp_down) .* "--")...)
    s_last = string(measure_tag.(inflfn.f_ramp_up[end]))
    return string(s_ramp_down, s_last)
end


function splice_length(inflfn::InflationSplice)
    return length(inflfn.dates)
end


function splice_functions(inflfn::InflationSplice)
    return [inflfn.f_ramp_down..., inflfn.f_ramp_up[end]]
end


function splice_dates(inflfn::InflationSplice)
    return inflfn.dates
end


function components(inflfn::InflationSplice)
    components = DataFrame(
        measure = measure_name.([inflfn.f_ramp_down..., inflfn.f_ramp_up[end]]),
        dates = [NaN, inflfn.dates...]
    )
    return components
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


"""
    _get_splice_weights(
        R::Type{<:AbstractFloat},
        sfn::InflationSplice,
        dates::StepRange{Date, T}
    ) where {T <: Period}

Helper function to compute the effective weights for each inflation function
in the InflationSplice over the given date range.

The output is a matrix of size (length(dates), number of functions in the splice),
where each row sums to 1, meaning, only one or two functions are active at each date,
with weights summing to 1.
"""
function _get_splice_weights(
        R::Type{<:AbstractFloat},
        sfn::InflationSplice,
        dates::StepRange{Date, T}
    ) where {T <: Period}

    # Number of transition periods
    Ntrans = length(sfn.dates)
    # Number of inflation functions to combine
    Nfn = Ntrans + 1

    # Number of periods in the range
    Nperiods = length(dates)

    # Preallocate matrix to store the weights for each function
    effective_weights = Matrix{R}(undef, Nperiods, Nfn)

    # Constructing the ramp up and ramp down weight vectors for each transition period
    ramp_weights = [ hcat(ramp_down(R, dates, d...), ramp_up(R, dates, d...)) for d in sfn.dates ]

    # Computing the effective weights for each function in the splice.
    # The first function is always ramped down.
    effective_weights[:, 1] = ramp_weights[1][:, 1]
    # The last function is always ramped up.
    effective_weights[:, end] = ramp_weights[end][:, 2]

    # If only one transition period, then we are done.
    if Ntrans == 1
        return effective_weights
    end

    # If we have more than transition period, then we need to compute the weights
    # for the intermediate functions.

    # In between, each function's weight is given by the ramp up and ramp down
    # of the adjacent transition periods. Bacause the ramps sum to 1, we subtract 1.0
    # to avoid double counting in non transition periods.
    for i in 2:length(ramp_weights)
        effective_weights[:, i] = ramp_weights[i - 1][:, 2] + ramp_weights[i][:, 1] .- 1.0
    end

    return effective_weights
end


# INFLATION SPLICE UNWEIGHTED ---------------------------------------------

"""
    InflationSpliceUnweighted <: InflationSpliceFunction

Inflation Function for splicing the results of several inflation functions over
the different VarCPIBase in a CountryStructure, without transition periods, just
stacking the results of each function over each base.
"""
struct InflationSpliceUnweighted <: InflationSpliceFunction
    f::Vector{<:InflationFunction}
    name::Union{Nothing, AbstractString}
    tag::Union{Nothing, AbstractString}

    function InflationSpliceUnweighted(
            f::Vector{<:InflationFunction},
            name::Union{Nothing, AbstractString},
            tag::Union{Nothing, AbstractString}
        )
        return new(f, name, tag)
    end
end


"""
    InflationSpliceUnweighted(
        f::Vector{<:InflationFunction};
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )

Create an InflationSpliceUnweighted function from a vector of InflationFunction `f`.
"""
function InflationSpliceUnweighted(
        f::Vector{<:InflationFunction};
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )
    return InflationSpliceUnweighted(f, name, tag)
end


"""
    InflationSpliceUnweighted(
        f::Vararg{<:InflationFunction};
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )

Create an InflationSpliceUnweighted function from a variable number of InflationFunction `f`.
"""
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


function (inflfn::InflationSpliceUnweighted)(cs::CountryStructure, ::CPIVarInterm, date::Date)

    @assert length(inflfn.f) >= length(cs.base) "The number of functions must match the number of bases"

    length(inflfn.f) > length(cs.base) && @warn "The number of functions is greater than the number of bases; extra functions will be ignored."

    # Getting the number of periods in each base inside the CountryStructure
    L = cumsum([periods(x) for x in cs.base])

    # Matrix with the start and end indices for each base inside the CountryStructure
    # each row is a base
    LL = hcat(vcat([1], L[1:(end - 1)] .+ 1), L)

    # Evaluating each inflation function over the corresponding base
    W = map(f -> f(cs, CPIVarInterm(), date), inflfn.f)
    OUT = vcat([W[i][LL[i, 1]:LL[i, 2]] for i in 1:length(L)]...)

    return convert(Array{eltype(cs)}, OUT)
end


function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIIndex, date::Date)
    v_interm = inflfn(cs, CPIVarInterm(), date::Date)
    capitalize!(v_interm, 100)
    return v_interm
end


function (inflfn::InflationSplice)(cs::CountryStructure, date::Date)
    cpi_index = inflfn(cs, CPIIndex(), date)
    return varinteran(cpi_index)
end


function (inflfn::InflationSpliceUnweighted)(cs::CountryStructure, ::CPIVarInterm)

    @assert length(inflfn.f) >= length(cs.base) "The number of functions must match the number of bases"

    length(inflfn.f) > length(cs.base) && @warn "The number of functions is greater than the number of bases; extra functions will be ignored."

    # Getting the number of periods in each base inside the CountryStructure
    L = cumsum([periods(x) for x in cs.base])

    # Matrix with the start and end indices for each base inside the CountryStructure
    # each row is a base
    LL = hcat(vcat([1], L[1:(end - 1)] .+ 1), L)

    # Evaluating each inflation function over the corresponding base
    W = map(f -> f(cs, CPIVarInterm()), inflfn.f)
    OUT = vcat([W[i][LL[i, 1]:LL[i, 2]] for i in 1:length(L)]...)

    return convert(Array{eltype(cs)}, OUT)
end


function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIIndex)
    v_interm = inflfn(cs, CPIVarInterm())
    capitalize!(v_interm, 100)
    return v_interm
end


function (inflfn::InflationSplice)(cs::CountryStructure)
    cpi_index = inflfn(cs, CPIIndex())
    return varinteran(cpi_index)
end


function measure_name(inflfn::InflationSpliceUnweighted)
    s_1 = string((measure_name.(inflfn.f[1:(end - 1)]) .* "--")...)
    s_2 = string(measure_name.(inflfn.f[end]))
    return string(s_1, s_2)
end


function measure_tag(inflfn::InflationSpliceUnweighted)
    s_1 = string((measure_tag.(inflfn.f[1:(end - 1)]) .* "--")...)
    s_2 = string(measure_tag.(inflfn.f[end]))
    return string(s_1, s_2)
end


function splice_length(inflfn::InflationSpliceUnweighted)
    return length(inflfn.f)
end


function splice_functions(inflfn::InflationSpliceUnweighted)
    return inflfn.f
end


function splice_dates(inflfn::InflationSpliceUnweighted)
    return @error "InflationSpliceUnweighted does not have transition dates."
end


function components(inflfn::InflationSpliceUnweighted)
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
    return components
end
