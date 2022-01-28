# varinterm.jl - basic operations to compute price change arrays. Operaciones
# básicas para computar vectores o matrices de variaciones intermensuales de
# índices de precios

"""
    varinterm(idx::AbstractVecOrMat, base_index = 100)

Función para computar un vector o una matriz de variaciones intermensuales de los
índices de precios en `idx`, utilizando como índice base `base_index` en la
primera observación. 

Ver también: [`varinterm!`](@ref)
"""
function varinterm end

"""
    varinterm!([v::AbstractVecOrMat, ] idx::AbstractVecOrMat, base_index = 100)

Función para computar un vector o una matriz de variaciones intermensuales de
los índices de precios en `idx`, utilizando como índice base `base_index` en la
primera observación. Si `idx` es una matriz, `v` es opcional y el cómputo se
realiza sobre la misma matriz. Si `idx` es un vector, es necesario proporcionar
`v` para realizar el cómputo.

Ver también: [`varinterm`](@ref).
"""
function varinterm! end


## Definición de métodos

function varinterm!(v::AbstractVector, idx::AbstractVector, base_index::Real = 100)
    l = length(v)
    for i in l:-1:2
        @inbounds v[i] = 100 * (idx[i] / idx[i-1] - 1)
    end
    v[1] = 100 * (idx[1] / base_index - 1)
end

function varinterm(idx::AbstractVector, base_index::Real = 100)
    v = similar(idx)
    varinterm!(v, idx, base_index)
    v
end

function varinterm(cpimat::AbstractMatrix, base_index::Real = 100)
    c = size(cpimat, 2)
    vmat = similar(cpimat)
    for j in 1:c
        vcol = @view vmat[:, j]
        idxcol = @view cpimat[:, j]
        varinterm!(vcol, idxcol, base_index)
    end
    vmat
end

function varinterm(cpimat::AbstractMatrix, base_index::AbstractVector)
    c = size(cpimat, 2)
    vmat = similar(cpimat)
    for j in 1:c
        vcol = @view vmat[:, j]
        idxcol = @view cpimat[:, j]
        varinterm!(vcol, idxcol, base_index[j])
    end
    vmat
end

function varinterm!(cpimat::AbstractMatrix, base_index::Real = 100)
    c = size(cpimat, 2)
    for j in 1:c
        idxcol = @view cpimat[:, j]
        varinterm!(idxcol, idxcol, base_index)
    end
end


"""
    varinterm(base::IndexCPIBase)

Devuelve una nueva copia de tipo `VarCPIBase` de un `IndexCPIBase`.
"""
function varinterm(base::IndexCPIBase)
    VarCPIBase(base)
end