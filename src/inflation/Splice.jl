"""
    Splice <: InflationFunction

    Splice( inflfns... ; dates = [(date1, date2),(date3, date4),...]=nothing, name=nothing, tag=nothing)

Función de inflación para empalmar dos funciones de inflación.
Las fechas denotan el intervalo de transición
"""
struct Splice<: InflationFunction
    f::Vector
    dates::Union{Nothing, Vector{Tuple{Date, Date}}}
    name::Union{Nothing, String}
    tag::Union{Nothing, String}

    function Splice(f::Vector; dates::Union{Nothing,Vector{Tuple{Date, Date}}}=nothing, name=nothing, tag=nothing)
        if !isnothing(dates)
            length(f) == length(dates)+1 || throw(ArgumentError("número de fechas debe ser igual al número de funciones menos 1"))
        end
        new(f, dates, name, tag)
    end

    function Splice(f...; dates::Union{Nothing,Vector{Tuple{Date, Date}}}=nothing, name=nothing, tag=nothing)
        Splice([f...]; dates, name, tag)
    end

end


# FUNCIONES AUXILIARES

function ramp_down(X::AbstractRange{T}, a::T, b::T) where T 
    A = min(a,b) 
    B = max(a,b)
    [x<=A ? 1 : A<x<=B ? 1 .- (findfirst( X .== x)-findfirst( X .== A))/(findfirst( X .== B)-findfirst( X .== A)) : 0 for x in X]
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
    #length(f) == length(cs.base) || throw(ArgumentError("número de funciones a concatenar deber coincidir con número de bases"))

    # EN EL CASO QUE NO SE DESIGNE UN PERIODO DE TRANSICION SE CONCATENAN DIRECTAMENTE LAS VARIACIONES INTERMENSUALES
    if isnothing(dates)
        L = cumsum([periods(x) for x in cs.base])
        LL = hcat(vcat([1],L[1:end-1].+1),L)
        W = map(x->x(cs, CPIVarInterm()),f)
        OUT = vcat([W[i][LL[i,1]:LL[i,2]] for i in 1:length(L)]...)
    
    # EN EL CASO QUE SE DESEA UNA TRANSICION GRADUAL EN VARIACIONES INTERMENSUALES SE CREAN
    # "RAMPAS" DE "APAGADO" y "ENCENDIDO" 
    else
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

#### CON FECHA

function (inflfn::Splice)(cs::CountryStructure, ::CPIVarInterm, date::Date)
    f = inflfn.f
    dates = inflfn.dates
    #length(f) == length(cs.base) || throw(ArgumentError("número de funciones a concatenar deber coincidir con número de bases"))

    # EN EL CASO QUE NO SE DESIGNE UN PERIODO DE TRANSICION SE CONCATENAN DIRECTAMENTE LAS VARIACIONES INTERMENSUALES
    if isnothing(dates)
        L = cumsum([periods(x) for x in cs.base])
        LL = hcat(vcat([1],L[1:end-1].+1),L)
        W = map(x->x(cs, CPIVarInterm(), date),f)
        OUT = vcat([W[i][LL[i,1]:LL[i,2]] for i in 1:length(L)]...)
    
    # EN EL CASO QUE SE DESEA UNA TRANSICION GRADUAL EN VARIACIONES INTERMENSUALES SE CREAN
    # "RAMPAS" DE "APAGADO" y "ENCENDIDO" 
    else
        X = cpi_dates(cs)
        F = ramp_down(X,dates[1]...)
        G = ramp_up(X,dates[1]...)
        OUT = (f[1](cs, CPIVarInterm(), date)).*F .+ (f[2](cs, CPIVarInterm(), date)) .* G 

        if length(dates)>= 2
            for i in 2:length(dates)
                F = CPIDataBase.ramp_down(X,dates[i]...)
                G = CPIDataBase.ramp_up(X,dates[i]...)
                OUT = OUT .* F 
                OUT = OUT + f[i+1](cs,CPIVarInterm(), date) .* G
            end
        end
    end
    convert(Array{eltype(cs)}, OUT) 
end

function (inflfn::Splice)(cs::CountryStructure, date::Date)
    cpi_index = inflfn(cs, CPIIndex(), date)
    varinteran(cpi_index)
end

function (inflfn::Splice)(cs::CountryStructure, ::CPIIndex, date::Date)
    v_interm = inflfn(cs, CPIVarInterm(), date::Date)
    capitalize!(v_interm, 100) 
    v_interm  
end

############################################################################# 
## FUNCIONES ADICIONALES
##############################################################################

function measure_name(inflfn::Splice)
    isnothing(inflfn.name) || return inflfn.name
    string((measure_name.(inflfn.f).*"--")...)[1:end-4]
end

function measure_tag(inflfn::Splice)
    isnothing(inflfn.tag) || return inflfn.tag
    string((measure_tag.(inflfn.f).*"--")...)[1:end-4]
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
    if isnothing(inflfn.dates)
        if inflfn.f isa Vector{CombinationFunction{A,B}} where A where B
            components = [
                DataFrame(
                    measure = measure_name.(x.ensemble),
                    weights = x.weights
                ) 
                for x in inflfn.f]
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
    components
end