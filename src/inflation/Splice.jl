"""
    abstract type InflationSpliceFunction <: InflationFunction 

Tipo abstracto para representar las funciones de inflación que operan sobre
[`CountryStructure`](@ref) y [`VarCPIBase`](@ref). 

Permiten computar la medida de ritmo inflacionario interanual, el índice de precios
dado por la metodología y las variaciones intermensuales del índice de precios,
empalmando dos o más funciones de inflación, empalmando sus variaciones intermensuales
de forma gradual a lo largo de un intervalo de fechas. 
"""
abstract type InflationSpliceFunction <: InflationFunction end

"""
    InflationSplice <: InflationSpliceFunction

    InflationSplice(
        inflfns... ; 
        dates = [(date1, date2),(date3, date4),...] = nothing, 
        name::Union{Nothing, String} = nothing,
        tag::Union{Nothing, String} = nothing
    )

Función para empalmar los resultados de varias funciones de inflación a lo largo
de intervalos de fechas de transición.
"""
struct InflationSplice
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

        if dates !== nothing
            length(f) == length(dates) + 1 ||
                throw(ArgumentError("Debe haber una tupla de fechas por cada par de funciones de inflación a empalmar."))

            _validate_dates(dates)
        end

        return new(f, dates, name, tag)
    end

    function InflationSplice(
            f::Vararg{<:InflationFunction};
            dates::Union{Nothing, Vector{NTuple{2, Date}}} = nothing,
            name::Union{Nothing, AbstractString} = nothing,
            tag::Union{Nothing, AbstractString} = nothing
        )

        return InflationSplice(collect(f); dates = dates, name = name, tag = tag)
    end

end


# FUNCIONES AUXILIARES


function _validate_dates(dates::Vector{Tuple{Date, Date}})
    # 1) Dentro de cada tupla: ini < fin
    @inbounds for (ini, fin) in dates
        ini < fin || throw(ArgumentError("Cada tupla debe cumplir ini < fin; recibida ($ini, $fin)."))
    end
    # 2) Entre tuplas consecutivas: fin[i] < ini[i+1]  (orden temporal ascendente y sin solape)
    @inbounds for i in firstindex(dates):(lastindex(dates) - 1)
        dates[i][2] < dates[i + 1][1] ||
            throw(
            ArgumentError(
                "Intervalos solapados o desordenados entre $i y $(i + 1): " *
                    "$(dates[i][2]) vs $(dates[i + 1][1])."
            )
        )
    end
    return nothing
end

function ramp_down(X::AbstractRange{T}, a::T, b::T) where {T}
    A = min(a, b)
    B = max(a, b)
    return [x <= A ? 1 : A < x <= B ? 1 .- (findfirst(X .== x) - findfirst(X .== A)) / (findfirst(X .== B) - findfirst(X .== A)) : 0 for x in X]
end

function ramp_up(X::AbstractRange{T}, a::T, b::T) where {T}
    return 1 .- ramp_down(X::AbstractRange{T}, a::T, b::T)
end

"""
    cpi_dates(cs::CountryStructure)

Devuelve las fechas en donde está definido el IPC para un CountryStructure.
Similar a infl_dates(cs::CountryStructure).
"""
function cpi_dates(cst::CountryStructure)
    return first(cst.base).dates[1]:Month(1):last(cst.base).dates[end]
end

function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIVarInterm)
    f = inflfn.f
    dates = inflfn.dates
    #length(f) == length(cs.base) || throw(ArgumentError("número de funciones a concatenar deber coincidir con número de bases"))

    # EN EL CASO QUE NO SE DESIGNE UN PERIODO DE TRANSICION SE CONCATENAN DIRECTAMENTE LAS VARIACIONES INTERMENSUALES
    if isnothing(dates)
        L = cumsum([periods(x) for x in cs.base])
        LL = hcat(vcat([1], L[1:(end - 1)] .+ 1), L)
        W = map(x -> x(cs, CPIVarInterm()), f)
        OUT = vcat([W[i][LL[i, 1]:LL[i, 2]] for i in 1:length(L)]...)

        # EN EL CASO QUE SE DESEA UNA TRANSICION GRADUAL EN VARIACIONES INTERMENSUALES SE CREAN
        # "RAMPAS" DE "APAGADO" y "ENCENDIDO"
    else
        X = cpi_dates(cs)
        F = ramp_down(X, dates[1]...)
        G = ramp_up(X, dates[1]...)
        OUT = (f[1](cs, CPIVarInterm())) .* F .+ (f[2](cs, CPIVarInterm())) .* G

        if length(dates) >= 2
            for i in 2:length(dates)
                F = CPIDataBase.ramp_down(X, dates[i]...)
                G = CPIDataBase.ramp_up(X, dates[i]...)
                OUT = OUT .* F
                OUT = OUT + f[i + 1](cs, CPIVarInterm()) .* G
            end
        end
    end
    return convert(Array{eltype(cs)}, OUT)
end

function (inflfn::InflationSplice)(cs::CountryStructure)
    cpi_index = inflfn(cs, CPIIndex())
    return varinteran(cpi_index)
end

function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIIndex)
    v_interm = inflfn(cs, CPIVarInterm())
    capitalize!(v_interm, 100)
    return v_interm
end

#### CON FECHA

function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIVarInterm, date::Date)
    f = inflfn.f
    dates = inflfn.dates
    #length(f) == length(cs.base) || throw(ArgumentError("número de funciones a concatenar deber coincidir con número de bases"))

    # EN EL CASO QUE NO SE DESIGNE UN PERIODO DE TRANSICION SE CONCATENAN DIRECTAMENTE LAS VARIACIONES INTERMENSUALES
    if isnothing(dates)
        L = cumsum([periods(x) for x in cs.base])
        LL = hcat(vcat([1], L[1:(end - 1)] .+ 1), L)
        W = map(x -> x(cs, CPIVarInterm(), date), f)
        OUT = vcat([W[i][LL[i, 1]:LL[i, 2]] for i in 1:length(L)]...)

        # EN EL CASO QUE SE DESEA UNA TRANSICION GRADUAL EN VARIACIONES INTERMENSUALES SE CREAN
        # "RAMPAS" DE "APAGADO" y "ENCENDIDO"
    else
        X = cpi_dates(cs)
        F = ramp_down(X, dates[1]...)
        G = ramp_up(X, dates[1]...)
        OUT = (f[1](cs, CPIVarInterm(), date)) .* F .+ (f[2](cs, CPIVarInterm(), date)) .* G

        if length(dates) >= 2
            for i in 2:length(dates)
                F = CPIDataBase.ramp_down(X, dates[i]...)
                G = CPIDataBase.ramp_up(X, dates[i]...)
                OUT = OUT .* F
                OUT = OUT + f[i + 1](cs, CPIVarInterm(), date) .* G
            end
        end
    end
    return convert(Array{eltype(cs)}, OUT)
end

function (inflfn::InflationSplice)(cs::CountryStructure, date::Date)
    cpi_index = inflfn(cs, CPIIndex(), date)
    return varinteran(cpi_index)
end

function (inflfn::InflationSplice)(cs::CountryStructure, ::CPIIndex, date::Date)
    v_interm = inflfn(cs, CPIVarInterm(), date::Date)
    capitalize!(v_interm, 100)
    return v_interm
end

#############################################################################
## FUNCIONES ADICIONALES
##############################################################################

function measure_name(inflfn::InflationSplice)
    isnothing(inflfn.name) || return inflfn.name
    return string((measure_name.(inflfn.f) .* "--")...)[1:(end - 4)]
end

function measure_tag(inflfn::InflationSplice)
    isnothing(inflfn.tag) || return inflfn.tag
    return string((measure_tag.(inflfn.f) .* "--")...)[1:(end - 4)]
end

function splice_length(inflfn::InflationFunction)
    if !(inflfn isa InflationSplice)
        return 1
    else
        return length(inflfn.f)
    end
end

function splice_inflfns(inflfn::InflationFunction)
    if !(inflfn isa InflationSplice)
        return inflfn
    else
        return inflfn.f
    end
end

function splice_dates(inflfn::InflationFunction)
    if !(inflfn isa InflationSplice)
        return NaN
    end
    return inflfn.dates
end

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
            #D = hcat([ hcat([measure_name(y.f[i]) for y in inflfn.f[i].ensemble.functions],inflfn.f[i].weights) for i in 1:length(inflfn.f)]...)
            #cols = vcat([[measure_name(x),measure_tag(x)*"_w"] for x in inflfn.f]...)
            #f(x::CombinationFunction) = DataFrame([measure_name(x, return_array=true),x.weights],[measure_name(x),measure_tag(x)*"_w"])
            #components = hcat(f.(inflfn.f)..., makeunique=true)
            #components = DataFrame(D,cols)
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
