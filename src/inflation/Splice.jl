
"""
    Splice <: InflationFunction

    Splice( [inflfn1, inflfn2, inflfn3, ...], [(date1, date2),(date3, date4),...], name, tag)

Función de inflación para empalmar dos funciones de inflación.
Las fechas denotan el intervalo de transición
"""
struct Splice<: InflationFunction
    f::Vector
    dates::Vector{Tuple{Date, Date}}
    name::Union{Nothing, String}
    tag::Union{Nothing, String}

    function Splice(f::Vector, dates::Vector{Tuple{Date, Date}}, name=nothing, tag=nothing)
        length(f) == length(dates)+1 || throw(ArgumentError("número de fechas debe ser igual al número de funciones menos 1"))
        new(f, dates, name, tag)
    end
end


# FUNCIONES AUXILIARES

function ramp_down(X::AbstractRange{T}, a::T, b::T) where T 
    A = min(a,b) 
    B = max(a,b)
    [x<A ? 1 : A<=x<=B ? 1 .- (findfirst( X .== x)-findfirst( X .== A))/(findfirst( X .== B)-findfirst( X .== A)) : 0 for x in X]
end

function ramp_up(X::AbstractRange{T}, a::T, b::T) where T 
    1 .- ramp_down(X::AbstractRange{T}, a::T, b::T)
end

"""
    cpi_dates(cs::CountryStructure)

Devuelve las fechas en donde está definido el IPC para un CountryStructure.
Similar a infl_dates(cs::CountryStructure).
"""
function cpi_dates(cst::CountryStructure) 
    first(cst.base).dates[1]:Month(1):last(cst.base).dates[end]
end

function (inflfn::Splice)(cs::CountryStructure, ::CPIVarInterm)
    f = inflfn.f
    dates = inflfn.dates

    X = cpi_dates(cs)
    F = ramp_down(X,dates[1]...)
    G = ramp_up(X,dates[1]...)
    OUT = (f[1](cs, CPIVarInterm())).*F .+ (f[2](cs, CPIVarInterm())) .* G 

    if length(dates)>= 2
        for i in 2:length(dates)
            F = CPIDataBase.ramp_down(X,dates[i]...)
            G = CPIDataBase.ramp_up(X,dates[i]...)
            OUT = OUT .* F 
            OUT = OUT + f[i+1](cs,CPIVarInterm()) .* G
        end
    end
    convert(Array{eltype(cs)}, OUT) 
end

function (inflfn::Splice)(cs::CountryStructure)
    cpi_index = inflfn(cs, CPIIndex())
    varinteran(cpi_index)
end

function (inflfn::Splice)(cs::CountryStructure, ::CPIIndex)
    v_interm = inflfn(cs, CPIVarInterm())
    capitalize!(v_interm, 100) 
    v_interm  
end

function measure_name(inflfn::Splice)
    isnothing(inflfn.name) || return inflfn.name
    string((measure_name.(inflfn.f).*" -> ")...)[1:end-4]
end

function measure_tag(inflfn::Splice)
    isnothing(inflfn.tag) || return inflfn.tag
    string((measure_tag.(inflfn.f).*" -> ")...)[1:end-4]
end

function splice_length(inflfn::InflationFunction)
    if !(inflfn isa Splice)
        return 1
    else 
        return length(inflfn.f)
    end
end

function splice_inflfns(inflfn::InflationFunction)
    if !(inflfn isa Splice)
        return inflfn
    else
        return inflfn.f
    end 
end

function splice_dates(inflfn::InflationFunction)
    if !(inflfn isa Splice)
        return NaN
    end
    return inflfn.dates
end

function components(inflfn::Splice)
    components = DataFrame(
        measure = measure_name.(inflfn.f),
        dates = [NaN, inflfn.dates...]
    )
    components
end