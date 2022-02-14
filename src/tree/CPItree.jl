## CPItree.jl - Tipos y métodos para operar la estructura jerárquica del IPC

##  ----------------------------------------------------------------------------
#   Main type definitions
#   ----------------------------------------------------------------------------

"""
    Item{T}(code::String, name::String, weight::T<:AbstractFloat)

Representa un gasto básico en la estructura de nodos del IPC. Es el nivel más
bajo de la estructura. Almacena el código del gasto básico, su nombre o
descripción y su ponderación en el IPC. Los datos de este nodo deben estar
disponibles en algún [`FullCPIBase`](@ref). 

Posee los campos: 
- `code`: que almacena el código del gasto básico como un `String`.
- `name`: que almacena el nombre del gasto básico como un `String`.
- `weight::T`: que almacena la ponderación del gasto básico como un valor
  flotante de tipo `T`.

Aunque este nodo será usualmente creado de manera automática por métodos como
[`CPITree`](@ref), se pueden crear estructuras jerárquicas manualmente. Por
ejemplo, para crear un nodo del nivel inferior: 
```julia-repl
julia> Item("_011101", "Item A", 7.352945f0)
Item{Float32}("_011101", "Item A", 7.352945f0)
```

Ver también: [`Group`](@ref), [`CPITree`](@ref).
"""
struct Item{T}
    code::String
    name::String
    weight::T
end

"""
    Group{S,T}

    Group(code, name, children::Vector{S}) where S
    Group(code, name, children...) 

Representa un nodo de agrupación de cualquier nivel en la estructura de nodos
del IPC. Puede almacenar gastos básicos u otros grupos de mayor jerarquía.
Almacena el código del grupo, su nombre o descripción y su ponderación en el
IPC. 

Posee los campos: 
- `code`: almacena el código del grupo como un `String`.
- `name`: almacena el nombre del grupo como un `String`.
- `weight::T`: almacena la ponderación del grupo como un valor flotante de tipo
  `T`.
- `children::Vector{S}`: almacena el vector de nodos "hijos" de la estructura.
  Por ejemplo, este vector podría ser un vector de elementos `Item` para agrupar
  un conjunto de gastos básicos.

Aunque este nodo será usualmente creado de manera automática por métodos como
[`CPITree`](@ref), se pueden crear estructuras jerárquicas manualmente. Por
ejemplo, para crear un grupo: 
```julia-repl
julia> a = Item("_011201", "Item B", 6.7442417f0)
Item{Float32}("_011201", "Item B", 6.7442417f0)

julia> b = Item("_011202", "Item C", 7.394718f0)
Item{Float32}("_011202", "Item C", 7.394718f0)

julia> g = Group("_0112", "Subgr._0112", a, b)
Group{Item{Float32}, Float32}
_0112: Subgr._0112 [14.13896] 
├─ _011201: Item B [6.7442417]
└─ _011202: Item C [7.394718]
```

Ver también: [`Item`](@ref), [`CPITree`](@ref).
"""
struct Group{S,T}
    code::String
    name::String
    weight::T
    children::Vector{S}

    function Group(code, name, children...)
        sum_weights = sum(child.weight for child in children)
        T = eltype(sum_weights)
        S = eltype(children)
        new{S,T}(code, name, sum_weights, S[children...])
    end
    Group(code, name, children::Vector{S}) where {S} = Group(code, name, children...)
end

# Redefine methods for getting children
children(::Item) = ()
children(g::Group) = g.children

# Redefine how to print a node in the print_tree function 
printnode(io::IO, g::Item) = print(io, g.code * ": " * g.name * " [" * string(g.weight) * "] ")
printnode(io::IO, g::Group) = print(io, g.code * ": " * g.name * " [" * string(g.weight) * "] ")

# How to show a Group
function Base.show(io::IO, g::Group)
    println(io, typeof(g)) 
    print_tree(io, g)
end


##  ----------------------------------------------------------------------------
#   CPI tree functions 
#   ----------------------------------------------------------------------------

"""
    cpi_tree_nodes(codes::Vector{<:AbstractString}; 
        characters::(NTuple{N, Int} where N), depth::Int=1, chars::Int=characters[depth], prefix::AbstractString="", 
        base::FullCPIBase, 
        group_names::Vector{<:AbstractString}, 
        group_codes::Vector{<:AbstractString})

Construye y devuelve una lista de nodos a partir de la lista de códigos `codes`
o de la especificación jerárquica de caracteres en `characters`. Los nombres y
las ponderaciones del nivel inferior (nivel de gasto básico) son
obtenidas de la estructura `base`. Se debe proveer el vector de códigos y
nombres de todas las jerarquías superiores en la estructura de códigos en los
vectores `group_names` y `group_codes`.

Esta función permite crear únicamente la estructura jerárquica de nodos. Para construir de manera automática una estructura del IPC, se recomienda utilizar preferentemente [`CPITree`](@ref).

Vea también: [`CPITree`](@ref).
"""
function cpi_tree_nodes(codes::Vector{<:AbstractString}; 
    characters::(NTuple{N, Int} where N), depth::Int=1, chars::Int=characters[depth], prefix::AbstractString="", 
    base::FullCPIBase, 
    group_names::Vector{<:AbstractString}, 
    group_codes::Vector{<:AbstractString})
    
    # Get available starting codes 
    available = filter(code -> startswith(code, prefix), codes)
    
    # Base case: 
    # If code length is the last available then we reached a leaf node
    if chars == last(characters)
        # With available codes construct leaf CPI nodes
        children = map(available) do code
            # Find the code index 
            icode = findfirst(==(code), codes)
            Item(code, base.names[icode], base.w[icode])
        end
        return children
    end

    # Get possible prefixes values from the available list. Possible prefixes
    # are the ones from the beginning of the string to the number of chars,
    # which depends on the depth we are on.
    possibles = unique(getindex.(available, Ref(1:chars)))

    # For each available code, call the function itself with the next downward hierarchy
    groups = map(possibles) do prefixcode
        # Go get the children in the next downward level
        children = cpi_tree_nodes(codes; 
            characters, depth=depth+1, prefix=prefixcode,
            base, group_names, group_codes
        )
        # Get the group name 
        @debug "Prefix code:" prefixcode
        i = findfirst(==(prefixcode), group_codes)
        if i === nothing 
            @warn "Código de grupo para $(prefixcode) no encontrado en `group_codes`. Utilizando nombre genérico."
            gname = "Group: $prefixcode"
        else
            gname = group_names[i]
        end
        # With the children create a group 
        group = Group(prefixcode, gname, children)
        group
    end

    # Return the group for the upward parents
    return groups
end

"""
    get_cpi_tree(; 
        base::FullCPIBase, 
        group_names::Vector{<:AbstractString}, 
        group_codes::Vector{<:AbstractString}, 
        characters::(NTuple{N, Int} where N),
        upperlevel_code = "_0", 
        upperlevel_name = "IPC")

Función superior para obtener estructura jerárquica del IPC. Devuelve el nodo
superior del árbol jerárquico. Utiliza la función de más bajo nivel
`cpi_tree_nodes` para construir los nodos del nivel más alto y hacia abajo en la
estructura jerárquica. Se debe proveer el vector de códigos y nombres de todas
las jerarquías superiores en la estructura de códigos en los vectores
`group_names` y `group_codes`. 

Esta función permite crear únicamente la estructura jerárquica de nodos. Para construir de manera automática una estructura del IPC, se recomienda utilizar preferentemente [`CPITree`](@ref).

Vea también: [`CPITree`](@ref).
"""
function get_cpi_tree(; 
    base::FullCPIBase, 
    group_names::Vector{<:AbstractString}, 
    group_codes::Vector{<:AbstractString}, 
    characters::(NTuple{N, Int} where N),
    upperlevel_code = "_0", 
    upperlevel_name = "IPC")

    length(characters) >= 2 || throw(ArgumentError("`characters` debe ser una tupla con al menos dos valores"))
    for i in 2:length(characters)
        characters[i] > characters[i-1] || throw(ArgumentError("Valores en `characters` deben ser ascendentes hasta el largo de los códigos en base"))
    end
    # Get the codes list from the FullCPIBase object
    codes = base.codes
    @debug "Codes:" codes

    # Call lower level tree building function
    upper_nodes = cpi_tree_nodes(codes; characters, base, group_names, group_codes)
    
    # Build upper level tree node
    tree = Group(upperlevel_code, upperlevel_name, upper_nodes)
    tree
end


## Build functions to find the inner tree of a given code
function find_tree(code, tree::Item) 
    code == tree.code && return tree 
    nothing
end

function find_tree(code, tree::Group)
    # Most basic case: the code is the same as the tree in which to search 
    code == tree.code && return tree

    # Search in the tree's nodes 
    for child in tree.children
        # If code searched is one of the children, return the child
        code == child.code && return child

        # Look if the code starts the same as the child's code, i.e the code
        # contains the child's code. If so, find in the inner tree and break out
        # of this level's search
        contains(code, child.code) && return find_tree(code, child)
    end

    # Code not found at any level
    nothing
end

# Redefine getindex to search for specific nodes within the tree
Base.getindex(tree::Union{Item, Group}, code::AbstractString) = find_tree(code, tree)




##  ----------------------------------------------------------------------------
#   Functions to compute any code's price index from the lower level data
#   ----------------------------------------------------------------------------

# Basic case: compute index of an Item, which is stored in the `base` structure
function compute_index(good::Item, base::FullCPIBase)
    i = findfirst(==(good.code), base.codes)
    # Maybe add a warning here if code not found
    base.ipc[:, i]
end

# Recursive function to compute inner price indexes for groups
function compute_index(group, base::FullCPIBase)
    # Get the indexes of the children. At the lowest level the dispatch will
    # select compute_index(::Item, ::FullCPIBase) to return the Goods indices
    ipcs = mapreduce(c -> compute_index(c, base), hcat, group.children)

    # If there exists only one good in the group, that is the group's index
    size(ipcs, 2) == 1 && return ipcs
    
    # Get the weights
    weights = map(c -> c.weight, group.children) 

    # Return normalized sum product 
    ipcs * weights / sum(weights)
end

# Edge case called when searching for a node that doest not exist. For example,
# if called compute_index(tree["_0101101"], base) and node with code "_0101101"
# does not exist, returns nothing and raises a warning
function compute_index(::Nothing, ::FullCPIBase)
    @warn "Nodo no disponible en la estructura"
    nothing 
end


##  ----------------------------------------------------------------------------
#   In-place functions to compute any code's price index from the lower level data
#   ----------------------------------------------------------------------------

function compute_index!(cache::Dict, good::Item, base::FullCPIBase)
    i = findfirst(==(good.code), base.codes)
    cache[good.code] = base.ipc[:, i] # save a copy in the cache
    cache[good.code]
end

function compute_index!(cache::Dict, group::Group, base::FullCPIBase)
    # If code is available in cache, just return it
    group.code in keys(cache) && return cache[group.code]

    # Else, compute the index and store it 
    # Get the indexes of the children. At the lowest level the dispatch will
    # select compute_index(::Item, ::FullCPIBase) to return the Goods indices
    ipcs = mapreduce(c -> compute_index!(cache, c, base), hcat, group.children)

    # If there exists only one good in the group, that is the group's index
    if size(ipcs, 2) == 1 
        cache[group.code] = ipcs 
        return ipcs
    end
    
    # Get the weights
    weights = map(c -> c.weight, group.children) 

    # Store normalized sum product 
    cache[group.code] = ipcs * weights / sum(weights)
    cache[group.code]
end

function compute_index!(::Dict, ::Nothing, ::FullCPIBase)
    @warn "Nodo no disponible en la estructura"
    nothing 
end


##  ----------------------------------------------------------------------------
#   CPITree: estructura contenedora del árbol jerárquico y los datos necesarios
#   para computar cualquier nodo en la estructura del IPC.
#   ----------------------------------------------------------------------------

"""
    CPITree

    CPITree(base::FullCPIBase, tree::Union{Group, Item}, group_names::Vector{String}, group_codes::Vector{String})
    CPITree(; base::FullCPIBase, groupsdf::DataFrame, characters::(NTuple{N, Int} where N), upperlevel_code = "_0", upperlevel_name = "IPC")

Contenedor envolvente de un árbol jerárquico del IPC y los datos necesarios de
los gastos básicos para computar cualquier jerarquía dentro del árbol. Permite
visualizar y explorar la composición del IPC de un país, así como computar los
índices de precios de las diferentes jerarquías de la estructura del IPC. Está
compuesto por: 
- Un objeto `base`, de tipo [`FullCPIBase`](@ref), el cual almacena las series
  de tiempo de los índices de los gastos básicos. 
- Un objeto `tree` que contiene la estructura de nodos del IPC.
- El vector de nombres `group_names` de los grupos del árbol `tree`.
- El vector de códigos `group_codes` de los grupos del árbol `tree`.

El constructor simple requiere una estructura jerárquica de nodos como la
devuelta por [`get_cpi_tree`](@ref). Al utilizar el constructor con `groupsdf` y
`characters`, se construye automáticamente un `CPITree` utilizando los códigos
como indicadores de la estructura jerárquica. Los códigos de los gastos básicos
contenidos en `base` describen cómo se agrupan las jerarquías. Por ejemplo, el
siguiente `FullCPIBase` contiene 10 gastos básicos: 
```julia-repl
julia> base
FullCPIBase{Float32, Float32}: 36 períodos × 10 gastos básicos Jan-01-Dec-03
┌─────┬─────────┬─────────────┬─────────┐
│ Row │ Code    │ Description │ Weight  │
├─────┼─────────┼─────────────┼─────────┤
│   1 │ _011101 │ Item A      │ 7.35294 │
│   2 │ _011201 │ Item B      │ 6.74424 │
│   3 │ _011202 │ Item C      │ 7.39472 │
│   4 │ _021101 │ Item D      │ 1.10364 │
│   5 │ _022101 │ Item E      │ 1.94941 │
│   6 │ _031101 │ Item F      │ 11.6854 │
│   7 │ _041101 │ Item G      │ 16.104  │
│   8 │ _041201 │ Item H      │ 11.3672 │
│   9 │ _041202 │ Item I      │ 17.4574 │
│  10 │ _041301 │ Item J      │ 18.8411 │
└─────┴─────────┴─────────────┴─────────┘
┌─────┬────────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┬─────────┐
│ Row │      Dates │ _011101 │ _011201 │ _011202 │ _021101 │ _022101 │ _031101 │ _041101 │ _041201 │ _041202 │ _041301 │
│     │            │ 7.35294 │ 6.74424 │ 7.39472 │ 1.10364 │ 1.94941 │ 11.6854 │  16.104 │ 11.3672 │ 17.4574 │ 18.8411 │
├─────┼────────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
│   1 │ 2001-01-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  101.13 │  100.00 │  100.00 │  100.51 │  100.00 │
│   2 │ 2001-02-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  102.28 │  100.00 │  100.00 │  101.02 │  100.00 │
│   3 │ 2001-03-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  103.44 │  100.00 │  100.00 │  101.53 │  100.00 │
│   4 │ 2001-04-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  104.61 │  100.00 │  100.00 │  102.05 │  100.00 │
│   5 │ 2001-05-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  105.79 │  100.00 │  100.00 │  102.56 │  100.00 │
│  ⋮  │     ⋮      │    ⋮    │    ⋮    │    ⋮    │    ⋮    │    ⋮    │    ⋮    │    ⋮    │    ⋮    │    ⋮    │    ⋮    │
│  33 │ 2003-09-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  145.02 │  100.00 │  100.00 │  118.19 │  100.00 │
│  34 │ 2003-10-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  146.66 │  100.00 │  100.00 │  118.79 │  100.00 │
│  35 │ 2003-11-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  148.32 │  100.00 │  100.00 │  119.39 │  100.00 │
│  36 │ 2003-12-01 │  100.00 │  100.00 │  100.00 │  100.00 │  100.00 │  150.00 │  100.00 │  100.00 │  120.00 │  100.00 │
└─────┴────────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
                                                                                                         27 rows omitted
```

En este ejemplo, el argumento debe especificarse como `characters = (3, 4, 5,
7)`, pues los códigos indican las jerarquías en el IPC de manera siguiente: 
- Los primeros 3 caracteres indican la jerarquía de *división de gasto*. 
- El siguiente caracter indica la jerarquía de *agrupación de gasto*. 
- El siguiente caracter indica la jerarquía de *subgrupo de gasto*. 
- Los siguientes 2 caracteres indican el *número de gasto básico dentro de su
  grupo*. 

Por su parte, el DataFrame `groupsdf` debe tener la estructura mínima siguiente: 
- La primera columna debe ser de tipo `String` y contiene los códigos de los
  grupos disponibles en la estructura del IPC. 
- La segunda columna debe ser de tipo `String` y contiene las descripciones o
nombres de los grupos disponibles en la estructura del IPC. Por ejemplo, el
DataFrame `groupsdf` puede verse de esta forma: 
```
17×2 DataFrame
 Row │ code    description 
     │ String  String      
─────┼─────────────────────
   1 │ _01     Div._01
   2 │ _02     Div._02
   3 │ _03     Div._03
   4 │ _04     Div._04
   5 │ _011    Agr._011
   6 │ _021    Agr._021
   7 │ _022    Agr._022
   8 │ _031    Agr._031
   9 │ _041    Agr._041
  10 │ _0111   Subgr._0111
  11 │ _0112   Subgr._0112
  12 │ _0211   Subgr._0211
  13 │ _0221   Subgr._0221
  14 │ _0311   Subgr._0311
  15 │ _0411   Subgr._0411
  16 │ _0412   Subgr._0412
  17 │ _0413   Subgr._0413
```

Por ejemplo, al construir un `CPITree` con la estructura de códigos indicada anteriormente y el DataFrame de ejemplo, el árbol del IPC se puede ver de esta forma: 
```julia-repl
julia> tree = CPITree(; base, groupsdf, characters=(3,4,5,7))
CPITree{Group{Group{Group{Group{Item{Float32}, Float32}, Float32}, Float32}, Float32}} con datos
└─→ FullCPIBase{Float32, Float32}: 36 períodos × 10 gastos básicos Jan-01-Dec-03
_0: IPC [100.0]
├─ _01: Div._01 [21.491905]
│  └─ _011: Agr._011 [21.491905]
│     ├─ _0111: Subgr._0111 [7.352945]
│     │  └─ _011101: Item A [7.352945]
│     └─ _0112: Subgr._0112 [14.13896]
│        ├─ _011201: Item B [6.7442417]
│        └─ _011202: Item C [7.394718]
├─ _02: Div._02 [3.0530455]
│  ├─ _021: Agr._021 [1.1036392]
│  │  └─ _0211: Subgr._0211 [1.1036392]
│  │     └─ _021101: Item D [1.1036392]
│  └─ _022: Agr._022 [1.9494063]
│     └─ _0221: Subgr._0221 [1.9494063]
│        └─ _022101: Item E [1.9494063]
├─ _03: Div._03 [11.68543]
│  └─ _031: Agr._031 [11.68543]
│     └─ _0311: Subgr._0311 [11.68543]
│        └─ _031101: Item F [11.68543]
└─ _04: Div._04 [63.769615]
   └─ _041: Agr._041 [63.769615]
      ├─ _0411: Subgr._0411 [16.103952]
      │  └─ _041101: Item G [16.103952]
      ├─ _0412: Subgr._0412 [28.824577]
      │  ├─ _041201: Item H [11.367162]
      │  └─ _041202: Item I [17.457417]
      └─ _0413: Subgr._0413 [18.841085]
         └─ _041301: Item J [18.841085]
```
"""
struct CPITree{G}
    base::FullCPIBase
    tree::G
    group_names::Vector{String}
    group_codes::Vector{String}
    function CPITree(base::FullCPIBase, tree::Union{Group, Item}, group_names::Vector{String}, group_codes::Vector{String})
        G = typeof(tree)
        new{G}(base, tree, group_names, group_codes)
    end
end

function CPITree(; 
    base::FullCPIBase, 
    groupsdf::DataFrame, 
    characters::(NTuple{N, Int} where N),
    upperlevel_code = "_0", 
    upperlevel_name = "IPC")

    # Obtener códigos y nombres de los grupos en las jerarquías
    group_codes = convert.(String, groupsdf[!, 1])
    group_names = groupsdf[!, 2]

    tree = get_cpi_tree(;
        base, 
        characters,
        group_names, 
        group_codes,
        upperlevel_code, 
        upperlevel_name
    )

    CPITree(base, tree, group_names, group_codes)
end


function Base.show(io::IO, cpitree::CPITree)
    println(io, typeof(cpitree), " con datos")
    println(io, "└─→ ", sprint(summary, cpitree.base)) 
    print_tree(io, cpitree.tree)
end

"""
    Base.getindex(cpitree::CPITree, code::AbstractString)

Este método se utiliza para indexar el árbol jerárquico `cpitree` y obtener una
estructura similar cuyo nodo superior sea el nodo con el código provisto `code`. Por ejemplo, si tenemos el siguiente árbol: 
```julia-repl
julia> tree
CPITree{Group{Group{Group{Group{Item{Float32}, Float32}, Float32}, Float32}, Float32}} con datos
└─→ FullCPIBase{Float32, Float32}: 36 períodos × 10 gastos básicos Jan-01-Dec-03
_0: IPC [100.0]
├─ _01: Div._01 [21.491905]
│  └─ _011: Agr._011 [21.491905]
│     ├─ _0111: Subgr._0111 [7.352945]
│     │  └─ _011101: Item A [7.352945]
│     └─ _0112: Subgr._0112 [14.13896]
│        ├─ _011201: Item B [6.7442417]
│        └─ _011202: Item C [7.394718]
├─ _02: Div._02 [3.0530455]
│  ├─ _021: Agr._021 [1.1036392] 
│  │  └─ _0211: Subgr._0211 [1.1036392]
│  │     └─ _021101: Item D [1.1036392]
│  └─ _022: Agr._022 [1.9494063]
│     └─ _0221: Subgr._0221 [1.9494063]
│        └─ _022101: Item E [1.9494063]
├─ _03: Div._03 [11.68543]
│  └─ _031: Agr._031 [11.68543]
│     └─ _0311: Subgr._0311 [11.68543]
│        └─ _031101: Item F [11.68543]
└─ _04: Div._04 [63.769615]
   └─ _041: Agr._041 [63.769615]
      ├─ _0411: Subgr._0411 [16.103952]
      │  └─ _041101: Item G [16.103952]
      ├─ _0412: Subgr._0412 [28.824577]
      │  ├─ _041201: Item H [11.367162]
      │  └─ _041202: Item I [17.457417]
      └─ _0413: Subgr._0413 [18.841085]
         └─ _041301: Item J [18.841085]
```

Al indexar por un código, como `_041`, obtenemos una estructura similar a partir de ese nodo:
```julia-repl
julia> tree["_041"]
CPITree{Group{Group{Item{Float32}, Float32}, Float32}} con datos
└─→ FullCPIBase{Float32, Float32}: 36 períodos × 10 gastos básicos Jan-01-Dec-03
_041: Agr._041 [63.769615]
├─ _0411: Subgr._0411 [16.103952]
│  └─ _041101: Item G [16.103952] 
├─ _0412: Subgr._0412 [28.824577]
│  ├─ _041201: Item H [11.367162]
│  └─ _041202: Item I [17.457417]
└─ _0413: Subgr._0413 [18.841085]
   └─ _041301: Item J [18.841085]
```
"""
function Base.getindex(cpitree::CPITree, code::AbstractString) 
    node = cpitree.tree[code]
    node === nothing && return nothing
    CPITree(cpitree.base, node, cpitree.group_names, cpitree.group_codes)
end

"""
    compute_index(cpitree::CPITree [, code::AbstractString])

Permite computar el índice de precios de la jerarquía provista en `code`. Si se
omite `code`, se computa la jerarquía padre de la estructura `cpitree`. Si el
nodo no se encuentra en el árbol, devuelve `nothing`.

```julia-repl
julia> tree
CPITree{Group{Group{Group{Group{Item{Float32}, Float32}, Float32}, Float32}, Float32}} con datos
└─→ FullCPIBase{Float32, Float32}: 36 períodos × 10 gastos básicos Jan-01-Dec-03
_0: IPC [100.0]
├─ _01: Div._01 [21.491905]
│  └─ _011: Agr._011 [21.491905]
│     ├─ _0111: Subgr._0111 [7.352945]
│     │  └─ _011101: Item A [7.352945]
│     └─ _0112: Subgr._0112 [14.13896]
│        ├─ _011201: Item B [6.7442417]
│        └─ _011202: Item C [7.394718]
├─ _02: Div._02 [3.0530455]
│  ├─ _021: Agr._021 [1.1036392]
│  │  └─ _0211: Subgr._0211 [1.1036392]
│  │     └─ _021101: Item D [1.1036392]
│  └─ _022: Agr._022 [1.9494063]
│     └─ _0221: Subgr._0221 [1.9494063]
│        └─ _022101: Item E [1.9494063]
├─ _03: Div._03 [11.68543]
│  └─ _031: Agr._031 [11.68543]
│     └─ _0311: Subgr._0311 [11.68543]
│        └─ _031101: Item F [11.68543]
└─ _04: Div._04 [63.769615]
   └─ _041: Agr._041 [63.769615]
      ├─ _0411: Subgr._0411 [16.103952]
      │  └─ _041101: Item G [16.103952]
      ├─ _0412: Subgr._0412 [28.824577]
      │  ├─ _041201: Item H [11.367162]
      │  └─ _041202: Item I [17.457417]
      └─ _0413: Subgr._0413 [18.841085]
         └─ _041301: Item J [18.841085]

julia> compute_index(tree, "_041")
36-element Vector{Float32}:
 100.13899
 100.2787
 100.41912
 100.560234
 100.70207
 100.84464
 100.98792
   ⋮
 104.65377
 104.81638
 104.97984
 105.14412
 105.309235
 105.47519

julia> compute_index(tree["_041"])
36-element Vector{Float32}:
 100.13899
 100.2787
 100.41912
 100.560234
 100.70207
 100.84464
 100.98792
   ⋮
 104.65377
 104.81638
 104.97984
 105.14412
 105.309235
 105.47519

julia> a = tree["_041302"]

julia> a === nothing
true
```
"""
function compute_index(cpitree::CPITree, code::AbstractString)
    node = cpitree.tree[code]
    node === nothing && return nothing 
    compute_index(node, cpitree.base)
end

# When single argument, compute the top level node
function compute_index(cpitree::CPITree)
    node = cpitree.tree
    compute_index(node, cpitree.base)
end


children(cpitree::CPITree) = children(cpitree.tree)

