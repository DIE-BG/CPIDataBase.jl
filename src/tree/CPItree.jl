## CPItree.jl - Tipos y métodos para operar la estructura jerárquica del IPC

##  ----------------------------------------------------------------------------
#   Main type definitions
#   ----------------------------------------------------------------------------

abstract type AbstractNode{T<:AbstractFloat} end 

struct Item{T} <: AbstractNode{T}
    code::String
    name::String
    weight::T
end

struct Group{S,T} <: AbstractNode{T}
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

# Construye y devuelve una lista de nodos a partir de la lista de códigos
# `codes` u de la especificación jerárquica de caracteres en `characters`. Los
# nombres y las ponderaciones del nivel inferior (nivel de gasto básico) son
# obtenidas de la estructura `full_base`. Se debe proveer el vector de códigos y
# nombres de todas las jerarquías superiores en la estructura de códigos en los
# vectores `group_names` y `group_codes`.
function cpi_tree_nodes(codes::Vector{<:AbstractString}; 
    characters::(NTuple{N, Int} where N), depth::Int=1, chars::Int=characters[depth], prefix::AbstractString="", 
    full_base::FullCPIBase, 
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
            Item(code, full_base.names[icode], full_base.w[icode])
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
            full_base, group_names, group_codes
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

# Función superior para obtener estructura jerárquica del IPC. Devuelve el nodo
# superior del árbol jerárquico. Utiliza la función de más bajo nivel
# `cpi_tree_nodes` para construir los nodos del nivel más alto y hacia abajo en
# la estructura jerárquica. Se debe proveer el vector de códigos y nombres de
# todas las jerarquías superiores en la estructura de códigos en los vectores
# `group_names` y `group_codes`. 
function get_cpi_tree(; 
    full_base::FullCPIBase, 
    group_names::Vector{<:AbstractString}, 
    group_codes::Vector{<:AbstractString}, 
    characters::(NTuple{N, Int} where N),
    upperlevel_code = "_0", 
    upperlevel_name = "IPC")

    length(characters) >= 2 || throw(ArgumentError("`characters` debe ser una tupla con al menos dos valores"))
    for i in 2:length(characters)
        characters[i] > characters[i-1] || throw(ArgumentError("Valores en `characters` deben ser ascendentes hasta el largo de los códigos en full_base"))
    end
    # Get the codes list from the FullCPIBase object
    codes = full_base.codes
    @debug "Codes:" codes

    # Call lower level tree building function
    upper_nodes = cpi_tree_nodes(codes; characters, full_base, group_names, group_codes)
    
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
Base.getindex(tree::Group, code::AbstractString) = find_tree(code, tree)




##  ----------------------------------------------------------------------------
#   Functions to compute any code's price index from the lower level data
#   ----------------------------------------------------------------------------

# Basic case: compute index of an Item, which is stored in the `base` structure
function compute_index(good::Item, base::FullCPIBase)
    i = findfirst(==(good.code), base.codes)
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