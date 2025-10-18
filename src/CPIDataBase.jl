"""
    CPIDataBase

Librería base para tipos y funcionalidad básica para manejo de los datos
desagregados del IPC a nivel de república. 
"""
module CPIDataBase

using Dates
using DataFrames
using PrettyTables
import Printf
import Statistics

# Exportar tipos
export IndexCPIBase, VarCPIBase, FullCPIBase
export CountryStructure, UniformCountryStructure, MixedCountryStructure

# Exportar funciones
export capitalize, varinterm, varinteran,
    capitalize!, varinterm!, varinteran!,
    items, periods, infl_periods, index_dates, infl_dates,
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
#   Inflation Splice Functions
#   ------------------------------------------------------------------------
include("inflation/InflationSpliceFunction.jl")

export InflationSpliceFunction, InflationSplice, InflationSpliceUnweighted,
    ramp_down, ramp_up, splice_length, splice_functions, splice_dates, components


##  ------------------------------------------------------------------------
#   Funcionalidades de árboles de cómputo del IPC
#   ------------------------------------------------------------------------
using AbstractTrees
import AbstractTrees: children, printnode
# Tipos básicos, un gasto básico y una estructura de grupo
export Item, Group
# Funciones para construir a partir de estructura de códigos
export get_cpi_tree, cpi_tree_nodes
# Operaciones básicas:
# find_tree : Encontrar un nodo en el árbol con un código especificado
# compute_index : Computar el índice de cualquier nodo en el árbol con la fórmula del IPC
# compute_index! : Similar a compute_index pero utiliza una caché de diccionario
export find_tree, compute_index, compute_index!
export children, print_tree  # reexport from AbstractTrees

# Estructura envolvente CPITree de FullCPIBase y estructura anidada Group
export CPITree

include("tree/CPItree.jl")


##  ------------------------------------------------------------------------
#   Submódulo de pruebas
#   ------------------------------------------------------------------------
# Submódulo con funciones relacionadas con los tipos de este paquete para
# realizar pruebas en paquetes que extiendan la funcionalidad. Este módulo
# no se exporta por defecto, requiere carga explícita (e.g using
# CPIDataBase.TestHelpers)
module TestHelpers
    using Dates, ..CPIDataBase

    export getrandomweights, getbasedates
    export getzerobase, getrandombase
    export getzerocountryst, getrandomcountryst

    include("helpers/test_helpers.jl")
end

end
