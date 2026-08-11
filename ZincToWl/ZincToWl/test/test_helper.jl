using Test
using ZincToWl.Helper

@testset "Helper Unit Tests" begin
    @testset "Typer & Global Node Checks" begin
        @test typer(:int) === :literal_node
        @test typer(:bool) === :literal_node
        @test typer(:par_node) === :literal_node
        @test typer(:var_node) === :var_node

        @test is_global(:all_different_node) == true
        @test is_global(:cumulatives_node) == true
        @test is_global(:custom_node) == false

        @test is_cut_node(:all_different_node) == true
        @test is_cut_node(:lin_eq_node) == true
        @test is_cut_node(:var_node) == false
    end

    @testset "Edge & Tailored Hashing" begin
        @test fast_edge_hash(Symbol("0")) == HASH_EDGE_0
        @test fast_edge_hash(Symbol("1")) == HASH_EDGE_1
        @test fast_edge_hash(Symbol("2")) == HASH_EDGE_2


        h1 = tailored_hash(UInt64(10), UInt64[1, 2, 3])
        h2 = tailored_hash(UInt64(10), UInt64[1, 2, 3])
        h3 = tailored_hash(UInt64(10), UInt64[3, 2, 1])
        @test h1 == h2
        @test h1 != h3
    end

    @testset "Color Persistence (load_colors & save_colors)" begin
        colors = Dict{UInt64,UInt64}(
            UInt64(1) => UInt64(100),
            UInt64(2) => UInt64(200)
        )
        mktempdir() do tmpdir
            bin_path = joinpath(tmpdir, "colors.bin")
            save_colors(bin_path, colors)
            @test isfile(bin_path)

            loaded = load_colors(bin_path)
            @test loaded[UInt64(1)] == UInt64(100)
            @test loaded[UInt64(2)] == UInt64(200)

            empty_colors = load_colors(joinpath(tmpdir, "non_existent.bin"))
            @test isempty(empty_colors)
        end
    end
end
