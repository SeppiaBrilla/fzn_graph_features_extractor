using Test
using SatToGraph

@testset "SatToGraph Tests" begin
    fixtures_dir = joinpath(@__DIR__, "fixtures")

    @testset "Simple CNF (.cnf)" begin
        f = joinpath(fixtures_dir, "simple.cnf")
        @test isfile(f)
        g = sat_to_graph(f)
        @test length(g.nodes) > 0
        @test length(g.edges) > 0
        @test haskey(g.node_dict, hash("x1"))
        @test haskey(g.node_dict, hash("x2"))
        @test haskey(g.node_dict, hash("x3"))
        @test haskey(g.node_dict, hash("x4"))
        @test haskey(g.node_dict, hash("not x1"))
        @test haskey(g.node_dict, hash("not x2"))
        @test haskey(g.node_dict, hash("not x3"))

        # Check multi_or_node and or_node exist
        has_multi_or = any(n -> n.type === :multi_or_node, g.nodes)
        @test has_multi_or

        # Test graph serialization
        mktempdir() do d
            out = joinpath(d, "simple.graph")
            write_graph(g, out)
            @test isfile(out)
            first_line = readline(out)
            @test startswith(first_line, "##")
        end
    end

    @testset "Compressed CNF (.cnf.xz)" begin
        f = joinpath(fixtures_dir, "simple.cnf.xz")
        @test isfile(f)
        g = sat_to_graph(f)
        @test length(g.nodes) > 0
        @test length(g.edges) > 0
        @test haskey(g.node_dict, hash("x1"))
    end

    @testset "Real SAT Benchmark Instance" begin
        bench_f = "../graph_features/data/sat/cnf/011984fd82d62d609e776fbf5de75440-arles_thres20_p10_r7533.cnf.xz"
        if isfile(bench_f)
            g = sat_to_graph(bench_f)
            @test length(g.nodes) > 0
            @test length(g.edges) > 0
        end
    end
end
