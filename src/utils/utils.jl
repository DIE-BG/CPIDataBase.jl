# utils.jl - Funciones de utilidad 

"""
    getdates(startdate::Date, periods::Int)
Obtiene un rango de fechas a partir de una fecha inicial `startdate` y la
cantidad de períodos de una matriz de variaciones intermensuales 
"""
function getdates(startdate::Date, periods::Int)
    startdate:Month(1):(startdate + Month(periods - 1))
end

"""
    getdates(startdate::Date, vmat::AbstractMatrix)
Obtiene un rango de fechas a partir de una fecha inicial `startdate` y la
cantidad de períodos en la matriz de variaciones intermensuales `vmat`.
"""
function getdates(startdate::Date, vmat::AbstractMatrix)
   T = size(vmat, 1)
   getdates(startdate, T)
end 

"""
    _apply_to_columns(f, input_mat::AbstractMatrix, output_mat::AbstractMatrix, base_index)

Helper function to apply a column-wise operation `f` to a matrix. This reduces
code duplication across capitalize, varinterm, and varinteran functions.

The function `f` should have the signature: `f(output_col, input_col, base_idx)`.
"""
function _apply_to_columns(f, input_mat::AbstractMatrix, output_mat::AbstractMatrix, base_index::Real)
    c = size(input_mat, 2)
    for j in 1:c
        input_col = @view input_mat[:, j]
        output_col = @view output_mat[:, j]
        f(output_col, input_col, base_index)
    end
end

function _apply_to_columns(f, input_mat::AbstractMatrix, output_mat::AbstractMatrix, base_index::AbstractVector)
    c = size(input_mat, 2)
    for j in 1:c
        input_col = @view input_mat[:, j]
        output_col = @view output_mat[:, j]
        f(output_col, input_col, base_index[j])
    end
end