using Test
using PbToGraph

@testset "PbToGraph Tests" begin
    fixtures_dir = joinpath(@__DIR__, "fixtures")

    @testset "Linear PB (.opb)" begin
        f = joinpath(fixtures_dir, "linear.opb")
        @test isfile(f)
        g = pb_to_graph(f)
        @test length(g.nodes) > 0
        @test length(g.edges) > 0
        @test haskey(g.node_dict, hash("x1"))
        @test haskey(g.node_dict, hash("x2"))
        @test haskey(g.node_dict, hash("x3"))
        @test haskey(g.node_dict, hash("x4"))
        @test haskey(g.node_dict, hash("Minimise(obj)"))

        # Verify serialization
        mktempdir() do d
            out = joinpath(d, "linear.graph")
            write_graph(g, out)
            @test isfile(out)
            first_line = readline(out)
            @test startswith(first_line, "##")
        end
    end

    @testset "Compressed Linear PB (.opb.xz)" begin
        f = joinpath(fixtures_dir, "linear.opb.xz")
        @test isfile(f)
        g = pb_to_graph(f)
        @test length(g.nodes) > 0
        @test length(g.edges) > 0
        @test haskey(g.node_dict, hash("x1"))
    end

    @testset "Non-Linear PB (.opb)" begin
        f = joinpath(fixtures_dir, "nonlinear.opb")
        @test isfile(f)
        g = pb_to_graph(f)
        @test length(g.nodes) > 0
        @test length(g.edges) > 0
        @test haskey(g.node_dict, hash("x1"))
        @test haskey(g.node_dict, hash("not x1"))
        @test haskey(g.node_dict, hash("not x2"))
    end

    @testset "Weighted Boolean Optimization (.wbo)" begin
        f = joinpath(fixtures_dir, "sample.wbo")
        @test isfile(f)
        g = pb_to_graph(f)
        @test length(g.nodes) > 0
        @test length(g.edges) > 0
        @test haskey(g.node_dict, hash("x1"))
        @test haskey(g.node_dict, hash("x2"))
        @test haskey(g.node_dict, hash("x3"))
        # Soft node should exist
        has_soft = any(n -> n.type === :soft_node, g.nodes)
        @test has_soft
    end

    @testset "Real Benchmark Instance" begin
        bench_f = "/home/alessio/Documents/projects/graph_features/data/selected-PB25/PB24/normalized-PB07/OPT-NLC/submittedPB07/manquinho/mds/normalized-mds_10_4_4.opb.xz"
        if isfile(bench_f)
            g = pb_to_graph(bench_f)
            @test length(g.nodes) > 0
            @test length(g.edges) > 0
        end
    end
end
