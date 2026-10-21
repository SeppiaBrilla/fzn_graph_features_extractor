using Test
using FlatzincToGraph
using ZincToWl.GraphLoader

@testset "GraphLoader Unit Tests" begin
    g_orig = Graph()
    id1 = hash("x")
    id2 = hash("y")
    add_node(g_orig, Node("x", :var_node, "$id1: x -- var_node -- int -- 10", id1))
    add_node(g_orig, Node("y", :var_node, "$id2: y -- var_node -- int -- 10", id2))
    add_edge(g_orig, id1, id2, Edge(Symbol("0")))

    mktempdir() do tmpdir
        graph_path = joinpath(tmpdir, "test_graph.graph")
        write_graph(g_orig, graph_path)
        @test isfile(graph_path)

        g_loaded = load_graph(graph_path)
        @test length(g_loaded.nodes) == 2
        @test length(g_loaded.edges) == 1
        @test haskey(g_loaded.node_dict, id1)
        @test haskey(g_loaded.node_dict, id2)
    end
end
