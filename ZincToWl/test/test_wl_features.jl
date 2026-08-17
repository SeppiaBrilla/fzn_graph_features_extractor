using Test
using FlatzincToGraph
using ZincToWl.Helper
using ZincToWl.StandardWl
using ZincToWl.NodeWl
using ZincToWl.EdgeWl
using ZincToWl.NodeEdgeWl
using ZincToWl.WlNodeCut
using ZincToWl.WlNodeEdgeCut

function create_symmetric_graph()
    g = Graph()
    id1 = hash("x1")
    id2 = hash("x2")
    id3 = hash("x3")
    id4 = hash("x4")
    add_node(g, Node("x1", :var_node, "$id1: x1 -- var_node", id1))
    add_node(g, Node("x2", :var_node, "$id2: x2 -- var_node", id2))
    add_node(g, Node("x3", :var_node, "$id3: x3 -- var_node", id3))
    add_node(g, Node("x4", :var_node, "$id4: x4 -- var_node", id4))

    # 2-cycle between x1 (idx 1) and x2 (idx 2)
    add_edge(g, id1, id2, Edge(Symbol("0")))
    add_edge(g, id2, id1, Edge(Symbol("0")))

    # Direct edge x3 (idx 3) -> x4 (idx 4)
    add_edge(g, id3, id4, Edge(Symbol("0")))
    return g
end

function create_typed_graph()
    g = Graph()
    id1 = hash("var_x")
    id2 = hash("lit_10")
    add_node(g, Node("var_x", :var_node, "$id1: var_x -- var_node", id1))
    add_node(g, Node("lit_10", :literal_node, "$id2: lit_10 -- literal_node", id2))

    # 2-cycle between var node (idx 1) and literal node (idx 2)
    add_edge(g, id1, id2, Edge(Symbol("0")))
    add_edge(g, id2, id1, Edge(Symbol("0")))
    return g
end

function create_large_ring_graph(n::Int=1024)
    g = Graph()
    ids = [hash("node_$i") for i in 1:n]
    for i in 1:n
        add_node(g, Node("node_$i", :var_node, "$(ids[i]): node_$i -- var_node", ids[i]))
    end
    for i in 1:n
        next_i = (i % n) + 1
        add_edge(g, ids[i], ids[next_i], Edge(Symbol("0")))
    end
    return g
end

@testset "Weisfeiler-Lehman Feature Algorithms Unit Tests" begin

    @testset "1. Easily Inferrable Graph Colors & Symmetry Verification" begin
        g_sym = create_symmetric_graph()
        colors = Dict{UInt64,UInt64}()

        c_std = wl_directed_last(g_sym, colors, 2, true, 1)
        # Node 1 (x1) and Node 2 (x2) form a symmetric 2-cycle
        @test c_std[1] == c_std[2]
        # Node 3 (x3, 0 in-neighbors) is distinct from Node 4 (x4, 1 in-neighbor from x3)
        @test c_std[3] != c_std[4]
        # Node 3 is distinct from Node 1
        @test c_std[3] != c_std[1]
        # Node 4 (in-neighbor has 0 in-neighbors) is distinct from Node 1 (in-neighbor has 1 in-neighbor) after 2 iterations
        @test c_std[4] != c_std[1]

        # Typed graph testing (NodeWl incorporates node types into initial colors)
        g_typed = create_typed_graph()
        colors_node = Dict{UInt64,UInt64}()
        c_node = wl_node_directed_last(g_typed, colors_node, 2, true, 1)
        # Node 1 (:var_node) and Node 2 (:literal_node) must have DIFFERENT colors despite symmetric 2-cycle topology
        @test c_node[1] != c_node[2]
    end

    @testset "2. Large Graph (1024 nodes) - Uniformity & Sequential vs Parallel Equivalence" begin
        g_ring = create_large_ring_graph(1024)
        @test length(g_ring.nodes) == 1024

        # Standard WL
        dict1 = Dict{UInt64,UInt64}()
        dict2 = Dict{UInt64,UInt64}()
        c_seq = wl_directed_last(g_ring, dict1, 3, true, 1)
        c_par = wl_directed_last(g_ring, dict2, 3, true, 4)
        # Inferred property: 1024 uniform ring nodes must all receive the EXACT SAME color
        @test length(unique(c_seq)) == 1
        # Sequential vs Parallel exact equivalence
        @test c_seq == c_par

        # Node WL
        dict1_n = Dict{UInt64,UInt64}()
        dict2_n = Dict{UInt64,UInt64}()
        cn_seq = wl_node_directed_last(g_ring, dict1_n, 3, true, 1)
        cn_par = wl_node_directed_last(g_ring, dict2_n, 3, true, 4)
        @test length(unique(cn_seq)) == 1
        @test cn_seq == cn_par

        # Edge WL
        dict1_e = Dict{UInt64,UInt64}()
        dict2_e = Dict{UInt64,UInt64}()
        ce_seq = wl_edge_directed_last(g_ring, dict1_e, 3, true, 1)
        ce_par = wl_edge_directed_last(g_ring, dict2_e, 3, true, 4)
        @test length(unique(ce_seq)) == 1
        @test ce_seq == ce_par

        # Node-Edge WL
        dict1_ne = Dict{UInt64,UInt64}()
        dict2_ne = Dict{UInt64,UInt64}()
        cne_seq = wl_node_edge_directed_last(g_ring, dict1_ne, 3, true, 1)
        cne_par = wl_node_edge_directed_last(g_ring, dict2_ne, 3, true, 4)
        @test length(unique(cne_seq)) == 1
        @test cne_seq == cne_par

        # Node Cut WL
        dict1_nc = Dict{UInt64,UInt64}()
        dict2_nc = Dict{UInt64,UInt64}()
        cnc_seq = wl_node_cut_directed_last(g_ring, dict1_nc, 3, true, 1)
        cnc_par = wl_node_cut_directed_last(g_ring, dict2_nc, 3, true, 4)
        info_seq = extract_extra_info(g_ring)
        info_par = extract_extra_info(g_ring)
        @test cnc_seq == cnc_par
        @test info_seq["n_nodes"] == info_par["n_nodes"]

        # Node-Edge Cut WL
        dict1_nec = Dict{UInt64,UInt64}()
        dict2_nec = Dict{UInt64,UInt64}()
        cnec_seq = wl_node_edge_cut_directed_last(g_ring, dict1_nec, 3, true, 1)
        cnec_par = wl_node_edge_cut_directed_last(g_ring, dict2_nec, 3, true, 4)
        info_seq2 = extract_extra_info(g_ring)
        info_par2 = extract_extra_info(g_ring)
        @test cnec_seq == cnec_par
        @test info_seq2["n_nodes"] == info_par2["n_nodes"]
    end

    @testset "3. Real Model FlatZinc Feature Extraction Tests" begin
        fzn_path = joinpath(@__DIR__, "../../FlatzincToGraph/test/fixtures/simple_bool_sat.fzn")
        g_fzn = flatzinc_to_graph(fzn_path, 1)
        @test length(g_fzn.nodes) > 0

        colors = Dict{UInt64,UInt64}()
        node_colors = wl_directed_last(g_fzn, colors, 2, true, 1)
        @test length(node_colors) == length(g_fzn.nodes)
        @test !isempty(colors)

        # Inference mode check
        node_colors_test = wl_directed_last(g_fzn, colors, 2, false, 1)
        @test length(node_colors_test) == length(g_fzn.nodes)
    end

    @testset "4. Extra Tabular Features Validation" begin
        fzn_path_knapsack = joinpath(@__DIR__, "../../FlatzincToGraph/test/fixtures/knapsack_int_opt.fzn")
        g_knapsack = flatzinc_to_graph(fzn_path_knapsack, 1)
        
        info = extract_extra_info(g_knapsack)
        
        # In knapsack, all 4 vars (item1, item2, item3, total_value) are ints (0..1 and 0..12 bounds -> ints)
        @test info["d_ratio_int_vars"] == 1.0
        @test info["d_ratio_bool_vars"] == 0.0
        
        # Objective is total_value. It should have a degree > 0 since it is constrained in int_lin_eq.
        # It has domain 0..12 so size is 13.
        @test info["o_deg_cons"] > 0.0
        @test info["o_dom_deg"] > 0.0
        @test info["v_sum_domdeg_vars"] > 0.0
    end
end
