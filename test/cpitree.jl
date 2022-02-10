# Tests for tree structures

@testset "Tree structures" begin 

    ## Build a test FullCPIBase
    varbase = getzerobase(
        T_type = Float32, 
        G = 10, 
        T_periods = 10, 
        startdate = Date(2001, 1)
    )

    # Codes with characters hierarchy defined by sequence (3, 4, 5, 7) 
    # Try several combinations
    codes = [
        "_011101", # One division, single subgroup, single item
        "_011201", # More items per subgroup
        "_011202",
        "_021101", # Higher groups with only one Item
        "_022101",
        "_031101", # One division with single Item 
        "_041101", # One division, one agrupation, several sub-agrupations and items
        "_041201",
        "_041202",
        "_041301",
    ]

    # Map some individual names for the Item objects
    names = string.('A':'J')

    # Create some group_codes
    group_codes = [
        "_01",
        "_02",
        "_03",
        "_04",
        "_011",
        "_021",
        "_022",
        "_031",
        "_041",
        "_0111",
        "_0112",
        "_0211",
        "_0221",
        "_0311",
        "_0411",
        "_0412",
        "_0413",
    ]

    # Map generic group codes according to length
    group_names = map(group_codes) do code 
        l = length(code)
        l == 3 && return "Div." * code
        l == 4 && return "Agr." * code
        l == 5 && return "Subgr." * code
        return "Gen." * code
    end

    base = FullCPIBase(
        capitalize(varbase.v), 
        varbase.v, 
        varbase.w, 
        varbase.dates, 
        varbase.baseindex, 
        codes, 
        names
    )


    ## Build items and groups manually
    all_items = [Item(base.codes[i], base.names[i], base.w[i]) for i in 1:10]
    group = Group("_0", "Single group", all_items)
    @info "Test building items and groups manually" 
    print_tree(group)

    @test length(children(group)) == 10
    @test abs(sum(c.weight for c in children(group)) - 100) <= 1e-2


    ## Try recursively building the tree
    @info "Test recursively building the CPI tree"
    cpi_test_tree = get_cpi_tree(
        full_base = base, 
        group_names = group_names, 
        group_codes = group_codes, 
        characters = (3, 4, 5, 7)
    )
    print_tree(cpi_test_tree)

    @test cpi_test_tree["_0"] === cpi_test_tree # returns the same structure
    @test cpi_test_tree["_01"] isa Group
    @test length(children(cpi_test_tree)) == 4
    @test abs(cpi_test_tree.weight - 100) < 1e-2

    ## Add more tests to check the computations of compute_index
    # to do


    ## Add tests to check compute_index!
end