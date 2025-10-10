# types.jl - Type definitions and structure
import Base: show, summary, convert, getindex, eltype

# Tipo abstracto para definir contenedores del IPC
"""
    abstract type AbstractCPIBase{T <: AbstractFloat}

Tipo abstracto para representar conjuntos de colecciones de datos del IPC. 

Vea también: [`FullCPIBase`](@ref), [`VarCPIBase`](@ref) e [`IndexCPIBase`](@ref).
"""
abstract type AbstractCPIBase{T <: AbstractFloat} end

# Tipos para los vectores de fechas
"""
    const DATETYPE = Union{StepRange{Date, Month}, Vector{Date}}
Tipos posibles para el campo de fechas `dates` de un [`AbstractCPIBase`](@ref).
"""
const DATETYPE = Union{StepRange{Date, Month}, Vector{Date}}

# Tipos para los vectores de códigos y nombres
"""
    const DESCTYPE = Union{Vector{String}, Nothing}
Tipos posibles para los nombres en el campo `names` de un [`FullCPIBase`](@ref).
"""
const DESCTYPE = Union{Vector{String}, Nothing}

"""
    const CODETYPE = Union{Vector{String}, Nothing}
Tipos posibles para los códigos en el campo `codes` de un [`FullCPIBase`](@ref).
"""
const CODETYPE = Union{Vector{String}, Nothing}

# El tipo B representa el tipo utilizado para almacenar los índices base. 
# Puede ser un tipo flotante, por ejemplo, Float64 o bien, si los datos 
# disponibles empiezan con índices diferentes a 100, un vector, Vector{Float64}, 
# por ejemplo

"""
    FullCPIBase{T, B} <: AbstractCPIBase{T}

    FullCPIBase(ipc::Matrix{T}, v::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B, codes::CODETYPE, names::DESCTYPE) where {T, B}
    FullCPIBase(df::DataFrame, gb::DataFrame)
    
Contenedor completo para datos desagregados del IPC de un país. Se representa
por:
- Matriz de índices de precios `ipc` que incluye la fila con los índices del
  número base. 
- Matriz de variaciones intermensuales `v`. En las filas contiene los períodos y
  en las columnas contiene los gastos básicos.
- Vector de ponderaciones `w` de los gastos básicos.
- Fechas correspondientes `dates` (por meses).
- Índices base `baseindex`. 
- Códigos y nombres de los gastos básicos en `codes` y `names`.

El tipo `T` representa el tipo de datos para representar los valores de punto
flotante. El tipo `B` representa el tipo del campo `baseindex`; por ejemplo,
`Float32` o `Vector{Float32}`.
"""
Base.@kwdef struct FullCPIBase{T, B} <: AbstractCPIBase{T}
    ipc::Matrix{T}
    v::Matrix{T}
    w::Vector{T}
    dates::DATETYPE
    baseindex::B
    codes::CODETYPE
    names::DESCTYPE

    function FullCPIBase(ipc::Matrix{T}, v::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B, codes::CODETYPE=nothing, names::DESCTYPE=nothing) where {T, B}
        @debug "Sizes:" size(ipc) size(v) length(dates) first(dates) last(dates)
        size(ipc, 2) == size(v, 2) || throw(ArgumentError("número de columnas debe coincidir entre matriz de índices y variaciones"))
        size(ipc, 2) == length(w) || throw(ArgumentError("número de columnas debe coincidir con vector de ponderaciones"))
        size(ipc, 1) == size(v, 1) == length(dates) || throw(ArgumentError("número de filas de `ipc` debe coincidir con vector de fechas"))
        new{T, B}(ipc, v, w, dates, baseindex, codes, names)
    end
end


"""
    IndexCPIBase{T, B} <: AbstractCPIBase{T}
    
    IndexCPIBase(ipc::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B) where {T, B}

Contenedor genérico de índices de precios del IPC de un país. Se representa por:
- Matriz de índices de precios `ipc` que incluye la fila con los índices del númbero base. 
- Vector de ponderaciones `w` de los gastos básicos.
- Fechas correspondientes `dates` (por meses).
- Índices base `baseindex`. 

El tipo `T` representa el tipo de datos para representar los valores de punto
flotante. El tipo `B` representa el tipo del campo `baseindex`; por ejemplo,
`Float32` o `Vector{Float32}`.
"""
Base.@kwdef struct IndexCPIBase{T, B} <: AbstractCPIBase{T}
    ipc::Matrix{T}
    w::Vector{T}
    dates::DATETYPE
    baseindex::B

    function IndexCPIBase(ipc::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B) where {T, B}
        size(ipc, 2) == length(w) || throw(ArgumentError("número de columnas debe coincidir con vector de ponderaciones"))
        size(ipc, 1) == length(dates) || throw(ArgumentError("número de filas debe coincidir con vector de fechas"))
        new{T, B}(ipc, w, dates, baseindex)
    end
end


"""
    VarCPIBase{T, B} <: AbstractCPIBase{T}

    VarCPIBase(v::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B) where {T, B}

Contenedor genérico para de variaciones intermensuales de índices de precios del
IPC de un país. Se representa por:
- Matriz de variaciones intermensuales `v`. En las filas contiene los períodos y
  en las columnas contiene los gastos básicos.
- Vector de ponderaciones `w` de los gastos básicos.
- Fechas correspondientes `dates` (por meses).
- Índices base `baseindex`. 

Este tipo es el utilizado en el contenedor de bases del IPC de un país,
denominado [`CountryStructure`](@ref), ya que con los datos de un
`VarCPIBase` es suficiente para computar cualquier medida de inflación basada en
índices de precios individuales o en un estadístico de resumen de las
variaciones intermensuales (como un percentil, o una media truncada).

El tipo `T` representa el tipo de datos para representar los valores de punto
flotante. El tipo `B` representa el tipo del campo `baseindex`; por ejemplo,
`Float32` o `Vector{Float32}`.

Ver también: [`CountryStructure`](@ref), [`UniformCountryStructure`](@ref),
[`MixedCountryStructure`](@ref)
"""
Base.@kwdef struct VarCPIBase{T, B} <: AbstractCPIBase{T}
    v::Matrix{T}
    w::Vector{T}
    dates::DATETYPE
    baseindex::B

    function VarCPIBase(v::Matrix{T}, w::Vector{T}, dates::DATETYPE, baseindex::B) where {T, B}
        size(v, 2) == length(w) || throw(ArgumentError("número de columnas debe coincidir con vector de ponderaciones"))
        size(v, 1) == length(dates) || throw(ArgumentError("número de filas debe coincidir con vector de fechas"))
        new{T, B}(v, w, dates, baseindex)
    end
end


## Constructores
# Los constructores entre tipos crean copias y asignan nueva memoria

function _getbaseindex(baseindex)
    if length(unique(baseindex)) == 1
        return baseindex[1]
    end
    baseindex
end

"""
    FullCPIBase(df::DataFrame, gb::DataFrame)

Este método constructor devuelve una estructura `FullCPIBase` a partir de los
DataFrames de índices de precios `df` y de descripción de los gastos básicos
`gb`. 
- El DataFrame `df` posee la siguiente estructura: 
    - Contiene en la primera columna las fechas o períodos de los datos. En las
      siguientes columnas, debe contener los códigos de cada una de las
      categorías o gastos básicos de la estructura del IPC, junto con la serie
      de tiempo con los índices de precios individuales. 
    - En las filas del DataFrame contiene los períodos por meses. La primera
      fila del DataFrame se utiliza para obtener el índice base. Si el valor es
      el mismo para todos los gastos básicos, se tomará únicamente este valor
      escalar (por ejemplo 100.0 como un Float64). En algunos casos, es posible
      que no se disponga de la información completa, por lo que los índices base
      podrían ser diferentes entre sí. En este caso, `baseindex` almacenará el
      vector de índices base originales. 
    - Un ejemplo de cómo puede verse este DataFrame es el siguiente: 
```
121×219 DataFrame
 Row │ Date         _011111  _011121  _011131  _011141  _011142  _011151  _011152 ⋯
     │ Date         Float64  Float64  Float64  Float64  Float64  Float64  Float64 ⋯
─────┼─────────────────────────────────────────────────────────────────────────────
   1 │ 2000-12-01   100.0    100.0    100.0    100.0    100.0    100.0    100.0   ⋯
   2 │ 2001-01-01   100.55   103.23   101.66   106.47   100.36   100.0    102.57   
   3 │ 2001-02-01   101.47   104.82   102.73   108.38   101.37   100.0    103.35   
   4 │ 2001-03-01   101.44   107.74   104.9    103.76   101.32   100.0    104.27   
   5 │ 2001-04-01   101.91   107.28   106.19   107.83   101.82   100.0    104.73  ⋯
   6 │ 2001-05-01   102.77   106.12   106.9    109.16   101.81   100.0    105.21   
   7 │ 2001-06-01   103.23   109.04   107.4    112.13   102.72   100.0    105.47   
   8 │ 2001-07-01   104.35   112.72   107.96   117.19   105.09   100.0    105.66   
  ⋮  │     ⋮          ⋮        ⋮        ⋮        ⋮        ⋮        ⋮        ⋮     ⋱
 114 │ 2010-05-01   218.45   501.39   200.28   477.5    179.0    215.0    164.16  ⋯
 115 │ 2010-06-01   219.28   503.35   203.88   476.26   180.94   214.02   164.97   
 116 │ 2010-07-01   219.1    503.78   205.19   478.34   181.78   217.6    165.9    
 117 │ 2010-08-01   218.52   507.45   206.87   486.72   181.51   223.76   166.46   
 118 │ 2010-09-01   218.9    505.8    206.45   501.23   182.04   228.34   166.04  ⋯
 119 │ 2010-10-01   219.51   504.41   205.78   504.4    182.35   221.98   166.3    
 120 │ 2010-11-01   219.11   509.63   205.41   502.88   182.16   217.01   166.34   
 121 │ 2010-12-01   218.79   511.38   205.09   506.04   182.14   218.63   165.99   
                                                   211 columns and 105 rows omitted
```

- El DataFrame `gb` posee la siguiente estructura: 
    - La primera columna contiene los códigos de las columnas del DataFrame
      `df`. 
    - La segunda columna contiene el nombre o la descripción de cada una de las
      categorías en las columnas de `df`. 
    - Y finalmente, la tercer columna, debe contener las ponderaciones asociadas
      a cada una de las categorías o gastos básicos de las columnas de `df`.
    - Los nombres de las columnas no son tomados en cuenta, solamente el orden y
      los tipos.
    - Un ejemplo de cómo puede verse este DataFrame es el siguiente: 
```
218×3 DataFrame
 Row │ Code     GoodOrService                       Weight
     │ String   String                              Float64     
─────┼────────────────────────────────────────────────────────
   1 │ _011111  Arroz                               0.483952
   2 │ _011121  Pan                                 2.82638
   3 │ _011131  Pastas frescas y secas              0.341395
   4 │ _011141  Productos de tortillería            1.69133
  ⋮  │   ⋮                     ⋮                     ⋮
 216 │ _093111  Gastos por seguros                  0.236691
 217 │ _093121  Gastos por servicios funerarios     0.289885
 218 │ _094111  Gastos por servicios diversos pa…   0.151793
                                              211 rows omitted
```
"""
function FullCPIBase(df::DataFrame, gb::DataFrame)
    # Obtener matriz de índices de precios
    ipc_mat = Matrix(df[!, 2:end])
    # Matrices de variaciones intermensuales de índices de precios
    v_mat = 100 .* (ipc_mat[2:end, :] ./ ipc_mat[1:end-1, :] .- 1)
    # Ponderación de gastos básicos o categorías
    w = gb[!, 3]
    # Actualización de fechas
    dates = df[2, 1]:Month(1):df[end, 1] 
    # Revisión de códigos 
    codes_df = names(df)[2:end]
    codes_gb = convert.(String, gb[:, 1])
    (codes_df == codes_gb) || throw(AssertionError("Códigos en las columnas de `df` deben coincidir con códigos en las filas de `gb`"))
    # Nombres
    names_gb = gb[:, 2]
    # Estructura de variaciones intermensuales de base del IPC
    return FullCPIBase(ipc_mat[2:end, :], v_mat, w, dates, _getbaseindex(ipc_mat[1, :]), codes_gb, names_gb)
end


"""
    VarCPIBase(df::DataFrame, gb::DataFrame)

Este constructor devuelve una estructura `VarCPIBase` a partir del DataFrame 
de índices de precios `df`, que contiene en las columnas las categorías o gastos 
básicos del IPC y en las filas los períodos por meses. Las ponderaciones se obtienen 
de la estructura `gb`, en la tercera columna de ponderaciones.

Para conocer la estructura de los DataFrames necesarios, vea también: [`FullCPIBase`](@ref).
"""
function VarCPIBase(df::DataFrame, gb::DataFrame)
    # Obtener estructura completa
    cpi_base = FullCPIBase(df, gb)
    # Estructura de variaciones intermensuales de base del IPC
    VarCPIBase(cpi_base)
end

function VarCPIBase(base::FullCPIBase)
    nbase = deepcopy(base)
    VarCPIBase(nbase.v, nbase.w, nbase.dates, nbase.baseindex)
end

# Obtener VarCPIBase de IndexCPIBase con variaciones intermensuales
VarCPIBase(base::IndexCPIBase) = convert(VarCPIBase, deepcopy(base))

"""
    IndexCPIBase(df::DataFrame, gb::DataFrame)

Este constructor devuelve una estructura `IndexCPIBase` a partir del DataFrame 
de índices de precios `df`, que contiene en las columnas las categorías o gastos 
básicos del IPC y en las filas los períodos por meses. Las ponderaciones se obtienen 
de la estructura `gb`, en la tercera columna de ponderaciones.

Para conocer la estructura de los DataFrames necesarios, vea también: [`FullCPIBase`](@ref).
"""
function IndexCPIBase(df::DataFrame, gb::DataFrame)
    # Obtener estructura completa
    cpi_base = FullCPIBase(df, gb)
    # Estructura de índices de precios de base del IPC
    return IndexCPIBase(cpi_base)
end

function IndexCPIBase(base::FullCPIBase) 
    nbase = deepcopy(base)
    IndexCPIBase(nbase.ipc, nbase.w, nbase.dates, nbase.baseindex)
end

# Obtener IndexCPIBase de VarCPIBase con capitalización intermensual
IndexCPIBase(base::VarCPIBase) = convert(IndexCPIBase, deepcopy(base))

## Conversión

# Estos métodos sí crean copias a través de la función `convert` de los campos
convert(::Type{T}, base::VarCPIBase) where {T <: AbstractFloat} = 
    VarCPIBase(convert.(T, base.v), convert.(T, base.w), base.dates, convert.(T, base.baseindex))
convert(::Type{T}, base::IndexCPIBase) where {T <: AbstractFloat} = 
    IndexCPIBase(convert.(T, base.ipc), convert.(T, base.w), base.dates, convert.(T, base.baseindex))
convert(::Type{T}, base::FullCPIBase) where {T <: AbstractFloat} = 
    FullCPIBase(convert.(T, base.ipc), convert.(T, base.v), convert.(T, base.w), base.dates, convert.(T, base.baseindex), base.codes, base.names)

# OJO: 
# Estos métodos no crean copias, como se indica en la documentación: 
# > If T is a collection type and x a collection, the result of convert(T, x) 
# > may alias all or part of x.
# Al convertir de esta forma se muta la matriz de variaciones intermensuales y se
# devuelve el mismo tipo, pero sin asignar nueva memoria

function convert(::Type{IndexCPIBase}, base::VarCPIBase)
    vmat = base.v
    capitalize!(vmat, base.baseindex)
    IndexCPIBase(vmat, base.w, base.dates, base.baseindex)
end

function convert(::Type{VarCPIBase}, base::IndexCPIBase)
    ipcmat = base.ipc
    varinterm!(ipcmat, base.baseindex)
    VarCPIBase(ipcmat, base.w, base.dates, base.baseindex)
end

# Función de conversión de FullCPIBase -> VarCPIBase, no crea copia de los datos
# subyacentes.  
function convert(::Type{VarCPIBase}, base::FullCPIBase)
    VarCPIBase(base.v, base.w, base.dates, base.baseindex)
end

# Tipo de flotante del contenedor
eltype(::AbstractCPIBase{T}) where {T} = T


## Métodos para mostrar los tipos

function _formatdate(fecha)
    Dates.format(fecha, dateformat"u-yy")
end

function summary(io::IO, base::AbstractCPIBase)
    field = hasproperty(base, :v) ? :v : :ipc
    periods, ngoods = size(getproperty(base, field))
    print(io, typeof(base), ": ", periods, " periods × ", ngoods, " items ")
    datestart, dateend = _formatdate.((first(base.dates), last(base.dates)))
    print(io, datestart, "-", dateend)
    # Summarize values
    datamatrix_ = getfield(base, field)
    mean_ = Statistics.mean(datamatrix_)
    summary_ = Printf.@sprintf("%0.4f", mean_)
    print(io, " mean:" * summary_)
end

function show(io::IO, base::Union{VarCPIBase, IndexCPIBase})
    summary(io, base)
    println(io)
    field = hasproperty(base, :v) ? :v : :ipc
    pretty_table(io, getproperty(base, field); 
        cell_first_line_only = true,
        row_labels = base.dates, 
        row_label_column_title = "Date",
        show_row_number = true, 
        header = (1:length(base.w), base.w), 
        crop = :both,
        vcrop_mode = :middle,
        formatters = ft_printf("%0.4f")
    )
end

function show(io::IO, base::FullCPIBase)
    summary(io, base)
    println(io)
    pretty_table(io, base.ipc; 
        row_labels = base.dates, 
        row_label_column_title = "Date",
        show_row_number = true, 
        crop_subheader = true, 
        header = (base.codes, base.names, base.w), 
        crop = :both,
        vcrop_mode = :middle,
        formatters = ft_printf("%0.2f"),
    )
end

"""
    periods(base::AbstractCPIBase)

Computa el número de períodos (meses) en las base de datos.
"""
function periods(base::AbstractCPIBase)
    field = hasproperty(base, :v) ? :v : :ipc
    periods = size(getproperty(base, field), 1)
    periods
end


"""
    items(base::AbstractCPIBase)

Computa el número de productos en las base de datos.
"""
function items(base::AbstractCPIBase)
    field = hasproperty(base, :v) ? :v : :ipc
    ngoods = size(getproperty(base, field), 2)
    ngoods
end