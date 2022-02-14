# Tests for tree structures

@testset "Tree structures" begin 

    periods = 36

    ## Build a test FullCPIBase
    varbase = getzerobase(
        T_type = Float32, 
        G = 10, 
        T_periods = periods, 
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
    item_names = "Item " .* string.('A':'J')

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

    # Modify last columns to check for correct upward computations
    v = varbase.v 
    # This should scale 150 to the division level for the last period
    v[:, 6] .= 100*((150.0/100)^(1/periods) - 1)
    # This should scale 120 to the subgroup level for the last period 
    v[:, 9] .= 100*((120.0/100)^(1/periods) - 1)

    base = FullCPIBase(
        capitalize(varbase.v), 
        varbase.v, 
        varbase.w, 
        varbase.dates, 
        varbase.baseindex, 
        codes, 
        item_names
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
        base = base, 
        group_names = group_names, 
        group_codes = group_codes, 
        characters = (3, 4, 5, 7)
    )
    print_tree(cpi_test_tree)

    # Structure tests
    @test cpi_test_tree["_0"] === cpi_test_tree # returns the same structure
    @test cpi_test_tree["_01"] isa Group
    @test length(children(cpi_test_tree)) == 4
    @test abs(cpi_test_tree.weight - 100) < 1e-2

    ## Tests to check the computations of compute_index
    @info "Tests to check the computations of compute_index"
    # Test upper level result 
    @test all(compute_index(cpi_test_tree, base) .!= 100)
    # Test other levels

    # Division with single Item should scale the values from the bottom
    @test all(compute_index(cpi_test_tree["_03"], base) .≈ compute_index(cpi_test_tree["_031101"], base))
    @test last(compute_index(cpi_test_tree["_03"], base)) ≈ 150
    
    # These results should be the same as the bottom ones, as price changes were not modified
    @test all(compute_index(cpi_test_tree["_011"], base) .≈ 100)
    @test all(compute_index(cpi_test_tree["_0111"], base) .≈ 100)
    @test all(compute_index(cpi_test_tree["_0112"], base) .≈ 100)
    @test all(compute_index(cpi_test_tree["_011101"], base) .≈ 100)
    
    # Testing how values scale from Item to Group 
    result = base.ipc[:, 8:9] * base.w[8:9] / sum(base.w[8:9])
    @test all(compute_index(cpi_test_tree["_0412"], base) .≈ result)

    # Testing how values scale from Group to upper Group. The rest of upward
    # categories work in the same way. It is recursive =)
    result = base.ipc[:, 7:end] * base.w[7:end] / sum(base.w[7:end])
    @test all(compute_index(cpi_test_tree["_041"], base) .≈ result)

    # This node does not exist
    @info "Test producing a warning for node not found"
    @test compute_index(cpi_test_tree["_011102"], base) === nothing 

    ## Tests to check compute_index!
    @info "Tests to check compute_index!"
    
    # Create a cache dict
    d = Dict{String, Vector{Float32}}()

    # Compute all the nodes and save them in d 
    idx = compute_index!(d, cpi_test_tree, base)
    # Check for the length of the 
    @test length(d) == length(group_codes) + length(codes) + 1 # Groups + Items + upper level
    # Check that all group names were computed and cached
    @test all(key in keys(d) for key in group_codes)

    @info "Test producing a warning for node not found"
    @test compute_index(cpi_test_tree["_011102"], base) === nothing 

    ## Test CPITree wrapper type
    @info "Tests with CPITree wrapper type"
    cpi_wrapper = CPITree(base, cpi_test_tree, group_names, group_codes)

    # Test indexing the top level code returns the same object
    @test cpi_wrapper["_0"] === cpi_wrapper

    # Test under-the-hood call to compute_index
    @test all(compute_index(cpi_wrapper, "_0") .== compute_index(cpi_test_tree["_0"], base))

    # Test computing an index not available
    @test compute_index(cpi_wrapper, "_011102") === nothing
    # Test indexing returns a proper CPITree
    @test hasproperty(cpi_wrapper["_01"], :group_names)
    @test hasproperty(cpi_wrapper["_01"], :group_codes)
    
    # Compute index with one argument
    @test all(compute_index(cpi_wrapper["_01"]) .== compute_index(cpi_wrapper, "_01"))
end