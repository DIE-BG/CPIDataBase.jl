using CPIDataGT
using AbstractTrees
import AbstractTrees: children, printnode

# Read groups information 
using CSV, DataFrames
groupsdf = CSV.read(joinpath(pkgdir(CPIDataGT), "data", "Guatemala_IPC_2010_Groups.csv"), DataFrame)

const GROUP_CODES = groupsdf[!, :Code]
const GROUP_NAMES = groupsdf[!, :GroupName]

struct Good{T<:AbstractFloat}
    code::String
    name::String
    weight::T
end

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

children(::Good) = ()
children(g::Group) = g.children

printnode(io::IO, g::Good) = print(io, g.code * ": " * g.name * " [" * string(g.weight) * "] ")
printnode(io::IO, g::Group) = print(io, g.code * ": " * g.name * " [" * string(g.weight) * "] ")

function Base.show(io::IO, g::Group)
    println(io, typeof(g)) 
    print_tree(io, g)
end

g1 = Good(FGT10.codes[1], FGT10.names[1], FGT10.w[1])
g2 = Good(FGT10.codes[2], FGT10.names[2], FGT10.w[2])

gr1 = Group("_01", "Alimentos y bebidas no alcohólicas", [g1, g2])
gr1 = Group("_01", "Alimentos y bebidas no alcohólicas", g1, g2)

print_tree(gr1)

foods = [Good(FGT10.codes[i], FGT10.names[i], FGT10.w[i]) for i in 1:74]
foodiv = Group("_01", "Alimentos y bebidas no alcohólicas", foods)
print_tree(foodiv)

## Desarrollar la estructura recursiva
CHARS = Dict(3 => 4, 4 => 5, 5 => 6, 6 => 8, 8 => 8)

function mytree(codes, chars=3, prefix="")
    
    # Get available starting codes 
    available = filter(code -> startswith(code, prefix), codes)
    
    if chars == 8
        # Get available codes from prefix
        # println("GB:", length(available))
        # println(available)
        # Good(FGT10.codes[1], FGT10.names[1], FGT10.w[1])
        children = map(available) do code
            # Find the code index 
            icode = findfirst(==(code), codes)
            Good(code, FGT10.names[icode], FGT10.w[icode])
        end
        # println(children)
        return children
    end

    # Get possible prefixes values
    possibles = unique(getindex.(available, Ref(1:chars)))
    nextchars = CHARS[chars]

    # For each available code, call the function itself with the next
    # groups = []
    # for prefixcode in possibles
    #     # Print the prefix code 
    #     # println(prefixcode)
    #     # And go get the children 
    #     children = mytree(codes, nextchars, prefixcode)
    #     # With the children create a group 
    #     group = Group(prefixcode, "GroupName", children)
    #     # println(group)
    #     push!(groups, group)
    # end

    groups = map(possibles) do prefixcode
        # Go get the children 
        children = mytree(codes, nextchars, prefixcode)
        # Get the group name 
        gcode = findfirst(==(prefixcode), GROUP_CODES)
        gname = GROUP_NAMES[gcode]
        # With the children create a group 
        group = Group(prefixcode, gname, children)
        group
    end

    # Return the group for the upward parents
    return groups
end

cpidivs = mytree(FGT10.codes)
cpi = Group("_0", "IPC", cpidivs)
print_tree(cpi)