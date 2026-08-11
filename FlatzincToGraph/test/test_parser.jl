using Test
using FlatzincToGraph

@testset "FlatZinc Parser - 3 Instance Types" begin
    fixtures_dir = joinpath(@__DIR__, "fixtures")

    @testset "1. Boolean SAT Model (simple_bool_sat.fzn)" begin
        fzn_path = joinpath(fixtures_dir, "simple_bool_sat.fzn")
        @test isfile(fzn_path)

        # Test sequential parsing
        g_seq = flatzinc_to_graph(fzn_path, 1)
        @test length(g_seq.nodes) > 0
        @test length(g_seq.edges) > 0
        @test haskey(g_seq.node_dict, hash("x1"))
        @test haskey(g_seq.node_dict, hash("x2"))
        @test haskey(g_seq.node_dict, hash("x3"))

        # Test parallel parsing code path
        g_par = flatzinc_to_graph(fzn_path, 2)
        @test length(g_par.nodes) == length(g_seq.nodes)
        @test length(g_par.edges) == length(g_seq.edges)
    end

    @testset "2. Integer Knapsack Optimization Model (knapsack_int_opt.fzn)" begin
        fzn_path = joinpath(fixtures_dir, "knapsack_int_opt.fzn")
        @test isfile(fzn_path)

        g = flatzinc_to_graph(fzn_path, 1)
        @test length(g.nodes) > 0
        @test length(g.edges) > 0

        # Check variable nodes exist
        @test haskey(g.node_dict, hash("item1"))
        @test haskey(g.node_dict, hash("total_value"))

        # Check maximize node exists
        maximise_id = hash("Maximise(total_value)")
        @test haskey(g.node_dict, maximise_id)


        # Test graph serialization
        mktempdir() do tmp_dir
            out_file = joinpath(tmp_dir, "knapsack.graph")
            write_graph(g, out_file)
            @test isfile(out_file)
            first_line = readline(out_file)
            @test startswith(first_line, "##")
        end
    end

    @testset "3. Graph Coloring and Global Constraint Model (graph_coloring_set.fzn)" begin
        fzn_path = joinpath(fixtures_dir, "graph_coloring_set.fzn")
        @test isfile(fzn_path)

        g = flatzinc_to_graph(fzn_path, 1)
        @test length(g.nodes) > 0
        @test length(g.edges) > 0

        # Verify variables c1, c2, c3
        @test haskey(g.node_dict, hash("c1"))
        @test haskey(g.node_dict, hash("c2"))
        @test haskey(g.node_dict, hash("c3"))
    end
end
