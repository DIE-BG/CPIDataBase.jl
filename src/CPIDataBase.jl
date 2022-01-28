"""
    CPIDataBase

Librería base para tipos y funcionalidad básica para manejo de los datos
desagregados del IPC a nivel de república. 
"""
module CPIDataBase

    using Dates
    using CSV, DataFrames
    using JLD2

    # Exportar tipos
    export IndexCPIBase, VarCPIBase, FullCPIBase
    export CountryStructure, UniformCountryStructure, MixedCountryStructure

    # Exportar funciones
    export capitalize, varinterm, varinteran, 
        capitalize!, varinterm!, varinteran!, 
        periods, infl_periods, infl_dates,
        getunionalltype

    # Exportar tipos para implementar nuevas funciones de inflación
    export InflationFunction, EnsembleInflationFunction
    export EnsembleFunction, CombinationFunction
    export InflationEnsemble, InflationCombination # alias de los 2 anteriores
    export components # componentes de una InflationCombination
    export num_measures, weights, measure_name, measure_tag, params

    # Exportar tipos necesarios para especificar tipos de los resultados 
    export CPIIndex, CPIVarInterm

    # Función básica de inflación 
    export InflationTotalCPI

    # Definición de tipos para bases del IPC
    include("CPIBase.jl")
    include("CountryStructure.jl")

    # Operaciones básicas
    include("utils/capitalize.jl")
    include("utils/varinterm.jl")
    include("utils/varinteran.jl")

    # Estructura básica para medidas de inflación 
    include("inflation/InflationFunction.jl")
    include("inflation/EnsembleFunction.jl")
    include("inflation/CombinationFunction.jl")

    # Medida de inflación básica 
    include("inflation/InflationTotalCPI.jl")

    # Funciones de utilidad
    export getdates
    include("utils/utils.jl")

    
    ##  ------------------------------------------------------------------------
    #   Submódulo de pruebas
    #   ------------------------------------------------------------------------
    # Submódulo con funciones relacionadas con los tipos de este paquete para
    # realizar pruebas en paquetes que extiendan la funcionalidad. Este módulo
    # no se exporta por defecto, requiere carga explícita (e.g using
    # CPIDataBase.TestHelpers)
    module TestHelpers
        using Dates, ..CPIDataBase    
        
        export getrandomweights, getbasedates, 
            getzerobase, getzerocountryst

        include("helpers/test_helpers.jl")
    end

    ##  ------------------------------------------------------------------------
    #   Cargar y exportar datos del IPC
    #   ------------------------------------------------------------------------

    export gt00, gt10 # Datos del IPC con precisión de 32 bits
    export gtdata # CountryStructure wrapper

    PROJECT_ROOT = pkgdir(@__MODULE__)
    datadir(file) = joinpath(PROJECT_ROOT, "data", file)
    const maindatafile = datadir("gtdata32.jld2")
    const doubledatafile = datadir("gtdata64.jld2")

    function __init__()
        if !isfile(maindatafile)
            @warn "Archivo principal de datos no encontrado. Construya el paquete para generar los archivos de datos necesarios. Puede utilizar `import Pkg; Pkg.build(\"CPIDataBase\")`"
        else
            load_data()
        end
    end

    """
        load_data(; full_precision = false)

    Carga los datos del archivo principal de datos `HEMI.maindatafile` del IPC
    con precisión de 32 bits. 
    - La opción `full_precision` permite cargar datos con precisión de 64 bits.
    - Archivo principal: `HEMI.maindatafile = joinpath(pkgdir(@__MODULE__), "data", "gtdata32.jld2")`.
    """
    function load_data(; full_precision::Bool = false) 
        datafile = full_precision ? doubledatafile : maindatafile 

        @info "Cargando datos de Guatemala..."
        global gt00, gt10, gtdata = load(datafile, "gt00", "gt10", "gtdata")

        # Exportar datos del módulo 
        @info "Archivo de datos cargado" data=datafile gtdata
    end

end
