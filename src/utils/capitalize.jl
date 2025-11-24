# capitalize.jl - basic operations to chain price change arrays. Operaciones
# básicas para encadenar variaciones intermensuales en índices de precios.

"""
    capitalize(v::AbstractVector, base_index::Real = 100)
    capitalize(vmat::AbstractMatrix, base_index::Real = 100)
    capitalize(vmat::AbstractMatrix, base_index::AbstractVector)

Función para encadenar un vector o matriz con variaciones intermensuales de
índices de precios `v` o `vmat` para conformar un índice de precios cuyo valor
base sea `base_index`.
"""
function capitalize end

"""
    capitalize!(idx:: AbstractVector, v::AbstractVector, base_index::Real)
    capitalize!(vmat::AbstractMatrix, base_index = 100)

Función para encadenar un vector o matriz con variaciones intermensuales de
índices de precios `v` o `vmat` para conformar un índice de precios cuyo valor
base sea `base_index` y sea almacenado en `idx` o en la propia matriz `vmat`.
"""
function capitalize! end


function capitalize(v::AbstractVector, base_index::Real = 100)
    idx = similar(v)
    capitalize!(idx, v, base_index)
    idx
end

function capitalize(vmat::AbstractMatrix, base_index::Real = 100)
    idxmat = similar(vmat)
    _apply_to_columns(capitalize!, vmat, idxmat, base_index)
    idxmat
end

function capitalize(vmat::AbstractMatrix, base_index::AbstractVector)
    idxmat = similar(vmat)
    _apply_to_columns(capitalize!, vmat, idxmat, base_index)
    idxmat
end

## Version in-place

function capitalize!(idx:: AbstractVector, v::AbstractVector, base_index::Real)
    l = length(v)
    idx[1] = base_index * (1 + v[1]/100)
    for i in 2:l
        @inbounds idx[i] = idx[i-1] * (1 + v[i]/100)
    end
end

capitalize!(v::AbstractVector, base_index::Real) = capitalize!(v, v, base_index)

function capitalize!(vmat::AbstractMatrix, base_index = 100)
    r = size(vmat, 1)
    @views @. vmat[1, :] = base_index * (1 + vmat[1, :]/100)
    for i in 2:r
        @views @. vmat[i, :] = vmat[i-1, :] * (1 + vmat[i, :]/100)
    end
end


## Versiones para tipos contenedores

function _offset_back(dates)
    start = first(dates) - Month(1)
    start:Month(1):last(dates)
end

"""
    capitalize(base::VarCPIBase)

Esto devuelve una nueva instancia (copia) de tipo `IndexCPIBase` de un objeto
`VarCPIBase`.
"""
function capitalize(base::VarCPIBase)
    IndexCPIBase(base)
end


## Otras versiones (descontinuado)

#=
"""
    capitalize_addbase(vmat::AbstractMatrix, base_index = 100) 

Function to chain a matrix of price changes with an index starting with `base_index`. This function adds the base index as the first row of the returned matrix.
"""
=#
function capitalize_addbase(vmat::AbstractMatrix, base_index = 100)
    r, c = size(vmat)
    idxmat = zeros(eltype(vmat), r+1, c)
    idxmat[1, :] .= base_index
    for i in 1:r
        @views @. idxmat[i+1, :] = idxmat[i, :] * (1 + vmat[i, :]/100)
    end
    idxmat
end