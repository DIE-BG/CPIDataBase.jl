using CPIDataGT
using CSV, DataFrames
using AbstractTrees
import AbstractTrees: children, printnode

struct Good
    code::String
    name::String
    weight::Union{Float32, Float64}
end

struct Group{S}
    code::String
    name::String
    weight::Union{Float32, Float64}
    children::Vector{S}

    function Group(code, name, children...)
        sum_weights = sum(child.weight for child in children)
        S = eltype(children)
        new{S}(code, name, sum_weights, S[children...])
    end
    Group(code, name, children::Vector{S}) where {S} = Group(code, name, children...)
end

children(::Good) = ()
children(g::Group) = g.children

printnode(io::IO, g::Good) = print(io, g.code * ": " * g.name * " [" * string(g.weight) * "] ")
printnode(io::IO, g::Group) = print(io, g.code * ": " * g.name * " [" * string(g.weight) * "] ")

function Base.show(io::IO, g::Group)
    println(io, typeof(g)) 
    # Show by default only the first depth level of the tree
    print_tree(io, g, maxdepth=1)
end

g1 = Good(FGT10.codes[1], FGT10.names[1], FGT10.w[1])
g2 = Good(FGT10.codes[2], FGT10.names[2], FGT10.w[2])

gr1 = Group("_01", "Alimentos y bebidas no alcohólicas", [g1, g2])
gr1 = Group("_01", "Alimentos y bebidas no alcohólicas", g1, g2)

print_tree(gr1)

foods = [Good(FGT10.codes[i], FGT10.names[i], FGT10.w[i]) for i in 1:74]
foodiv = Group("_01", "Alimentos y bebidas no alcohólicas", foods)
print_tree(foodiv)


## CPI tree functions 

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
            Good(code, full_base.names[icode], full_base.w[icode])
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
        children = cpi_tree_nodes(codes; characters, depth=depth+1, prefix=prefixcode,
            full_base, group_names, group_codes
        )
        # Get the group name 
        gcode = findfirst(==(prefixcode), group_codes)
        gname = group_names[gcode]
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
    group_names::Vector{<:AbstractString}, group_codes::Vector{<:AbstractString}, 
    characters::(NTuple{N, Int} where N),
    upperlevel_code = "_0", 
    upperlevel_name = "IPC")

    # Get the codes list from the FullCPIBase object
    codes = full_base.codes

    # Call lower level tree building function
    upper_nodes = cpi_tree_nodes(codes; characters, full_base, group_names, group_codes)
    
    # Build upper level tree node
    tree = Group(upperlevel_code, upperlevel_name, upper_nodes)
    tree
end




## Building CPI Base 2010 tree

groups10 = CSV.read(joinpath(pkgdir(CPIDataGT), "data", "Guatemala_IPC_2010_Groups.csv"), DataFrame)

cpi_10_tree = get_cpi_tree(
    full_base = FGT10, 
    group_names = groups10[!, :GroupName], 
    group_codes = groups10[!, :Code],
    characters = (3,4,5,6,8) #(3, 8) #(3,4,5,6,8) 
)

cpi_10_tree
print_tree(cpi_10_tree)

## Building CPI Base 2000 tree
groups00 = CSV.read(joinpath(pkgdir(CPIDataGT), "data", "Guatemala_IPC_2000_Groups.csv"), DataFrame)

cpi_00_tree = get_cpi_tree(
    full_base = FGT00, 
    group_names = groups00[!, :GroupName], 
    group_codes = groups00[!, :Code],
    characters = (3, 7)
)

cpi_00_tree
print_tree(cpi_00_tree)

