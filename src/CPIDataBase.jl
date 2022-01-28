"""
    CPIDataBase

Librería base para tipos y funcionalidad básica para manejo de los datos
desagregados del IPC a nivel de república. 
"""
module CPIDataBase

    using Dates
    using CSV, DataFrames

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

        include("test/test_helpers.jl")
    end

    ##  ------------------------------------------------------------------------
    #   Cargar y exportar datos del IPC
    #   ------------------------------------------------------------------------

    export gt00, gt10 # Datos del IPC con precisión de 32 bits
    export dgt00, dgt10 # Datos del IPC con precisión doble de 64 bits
    export gtdata, dgtdata # CountryStructure wrappers

    const PROJECT_ROOT = pkgdir(@__MODULE__)
    datadir(file) = joinpath(PROJECT_ROOT, "data", file)
    @info "Exportando datos del IPC en variables `gt00`, `gt10`, `gtdata`"

    # Base 2000
    gt_base00 = CSV.read(datadir("Guatemala_IPC_2000.csv"), DataFrame, normalizenames=true)
    gt00gb = CSV.read(datadir("Guatemala_GB_2000.csv"), DataFrame, types=[String, String, Float64])

    full_gt00 = FullCPIBase(gt_base00, gt00gb)
    dgt00 = VarCPIBase(full_gt00)
    gt00 = convert(Float32, dgt00)

    # Base 2010
    gt_base10 = CSV.read(datadir("Guatemala_IPC_2010.csv"), DataFrame, normalizenames=true)
    gt10gb = CSV.read(datadir("Guatemala_GB_2010.csv"), DataFrame, types=[String, String, Float64])

    full_gt10 = FullCPIBase(gt_base10, gt10gb)
    dgt10 = VarCPIBase(full_gt10)
    gt10 = convert(Float32, dgt10)

    gtdata = UniformCountryStructure(gt00, gt10)
    dgtdata = UniformCountryStructure(dgt00, dgt10)

    @info "Datos cargados exitosamente" gtdata

end
