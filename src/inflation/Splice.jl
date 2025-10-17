"""
    InflationSplice <: InflationFunction

    InflationSplice(
        inflfns... ; 
        dates = [(date1, date2),(date3, date4),...] = nothing, 
        name::Union{Nothing, String} = nothing,
        tag::Union{Nothing, String} = nothing
    )

Inflation Function for splicing the results of several inflation functions over
transition date intervals.
"""
struct InflationSplice <: InflationFunction
    f::Vector{<:InflationFunction}
    dates::Union{Nothing, Vector{Tuple{Date, Date}}}
    name::Union{Nothing, AbstractString}
    tag::Union{Nothing, AbstractString}

    function InflationSplice(
            f::Vector{<:InflationFunction};
            dates::Union{Nothing, Vector{Tuple{Date, Date}}} = nothing,
            name::Union{Nothing, AbstractString} = nothing,
            tag::Union{Nothing, AbstractString} = nothing
        )

        # Asserting some properties of the input arguments if dates are given
        if !isnothing(dates)
            _validate_size(f, dates)
            _validate_dates(dates)
        end

        return new(f, dates, name, tag)
    end
end

function _validate_size(f::Vector{<:InflationFunction}, dates::Vector{Tuple{Date, Date}})
    f_size = length(f)
    dates_size = length(dates)

    if f_size != dates_size + 1
        throw(ArgumentError("There must be one more function than date intervals."))
    end

    return nothing
end


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


function InflationSplice(
        f::Vararg{<:InflationFunction};
        dates::Union{Nothing, Vector{Tuple{Date, Date}}} = nothing,
        name::Union{Nothing, AbstractString} = nothing,
        tag::Union{Nothing, AbstractString} = nothing
    )

    return InflationSplice(collect(f); dates = dates, name = name, tag = tag)
end

# Helper functions


"""
    (inflfn::InflationSplice)(base::VarCPIBase)


Evaluate the InflationSplice function on a given VarCPIBase `base`, returning the corresponding CPIVarInterm.

Only those transition dates completely overlapped within the date range of `base` are considered.
"""
function (inflfn::InflationSplice)(base::VarCPIBase)
    @assert !isnothing(inflfn.dates) "InflationSplice requires transition dates when applied to a single VarCPIBase."

    #check the ranges in inflfn.dates denoted as rng = (ini, fin) are inside
    # the range of base.dates. full overlap is required
    _check_overlap(rng) = (base.dates[1] <= rng[1] <= base.dates[end]) &&
        (base.dates[1] <= rng[2] <= base.dates[end])

    # get the index of the ranges in inflfn.dates that fully overlap with base.dates
    _mask_dates = findall(_check_overlap, inflfn.dates)

    @assert !isempty(_mask_dates) "No transition date intervals overlap with the date range of the provided VarCPIBase."

    # applying the splice in the first overlaped interval

    F = ramp_down(
        eltype(base), base.dates, inflfn.dates[_mask_dates[1]]...
    )

    G = ramp_up(
        eltype(base), base.dates, inflfn.dates[_mask_dates[1]]...
    )

    OUT = (inflfn.f[_mask_dates[1]](base)) .* F
    OUT = OUT .+ (inflfn.f[_mask_dates[1] + 1](base)) .* G

    # applying the splice in the remaining overlaped intervals (if any)
    if length(_mask_dates) >= 2
        for j in _mask_dates[2:end]
            F = ramp_down(eltype(base), base.dates, inflfn.dates[j]...)
            G = ramp_up(eltype(base), base.dates, inflfn.dates[j]...)
            OUT = OUT .* F
            OUT = OUT + (inflfn.f[j + 1](base) .* G)
        end
    end

    # returning the spliced intermediate monthly variation
    return convert(Array{eltype(base)}, OUT)
end

"""
    ramp_up(X::AbstractRange{<:Real}, a::Real, b::Real)

Generates a "ramp down" weight vector over the range X, transitioning from 1 to 0
between points a and b. For values in X less than or equal to a, the weight
is 1; for values greater than or equal to b, the weight is 0; and for values
within the interval (a, b), the weight decreases linearly from 1 to 0.
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
    ramp_up(X::StepRange{Date, T}, a::Date, b::Date) where {T <: Period}

Generates a "ramp down" weight vector over the date range X, transitioning from 1 to 0
between dates a and b. For dates in X less than or equal to a, the weight
is 1; for dates greater than or equal to b, the weight is 0; and for dates
within the interval (a, b), the weight decreases linearly from 1 to 0.
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
    ramp_down(X::AbstractRange{<:Real}, a::Real, b::Real)
Generates a "ramp down" weight vector over the range X, transitioning from 0 to 1
between points a and b. 

only weights for the X range are outputted.
"""
function ramp_down(::Type{R}, X::AbstractRange{<:T}, a::T, b::T) where {R <: AbstractFloat, T <: Integer}
    return 1 .- ramp_up(R, X, a, b)
end


"""
    ramp_down(X::StepRange{Date, T}, a::Date, b::Date) where {T <: Period}
Generates a "ramp down" weight vector over the date range X, transitioning from 0 to 1
between dates a and b. 

only weights for the X range are outputted.
"""
function ramp_down(::Type{R}, X::StepRange{Date, T}, a::Date, b::Date) where {T <: Period, R <: AbstractFloat}
    return 1 .- ramp_up(R, X, a, b)
end


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
    measure_name(inflfn::InflationSplice)
Return the name of all the InflationFunction components of the InflationSplice,
concatenated with "--" as separator, unless a specific name is provided.
"""
function measure_name(inflfn::InflationSplice)
    isnothing(inflfn.name) || return inflfn.name
    return string((measure_name.(inflfn.f) .* "--")...)[1:(end - 4)]
end


"""
    measure_tag(inflfn::InflationSplice)
Return the tag of all the InflationFunction components of the InflationSplice,
concatenated with "--" as separator, unless a specific name is provided.
"""
function measure_tag(inflfn::InflationSplice)
    isnothing(inflfn.tag) || return inflfn.tag
    return string((measure_tag.(inflfn.f) .* "--")...)[1:(end - 4)]
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
