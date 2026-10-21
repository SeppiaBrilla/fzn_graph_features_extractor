using Test
using ZincToWl
using FlatzincToGraph

const WT = ZincToWl.WlTrace

# Build a small graph covering: var nodes, literals, operator nodes, a cut
# (global) node, and multiple edge labels.
function make_test_graph()
    g = Graph()
    # variables
    add_node(g, Node("x", :var_node, hash("x"), :int, 10))
    add_node(g, Node("y", :var_node, hash("y"), :int, 10))
    add_node(g, Node("z", :var_node, hash("z"), :bool, 2))
    # literals
    add_node(g, Node("1", :int, hash("lit1")))
    add_node(g, Node("2", :int, hash("lit2")))
    # operator node (non-cut)
    add_node(g, Node("+", :mult_node, hash("op+")))
    # cut/global node
    add_node(g, Node("alldiff", :all_different_node, hash("ad")))
    # solve node
    add_node(g, Node("Minimise(x)", :minimise_node, hash("min")))
    # edges
    add_edge(g, hash("x"), hash("op+"), Edge(Symbol(0)))
    add_edge(g, hash("y"), hash("op+"), Edge(Symbol(0)))
    add_edge(g, hash("op+"), hash("ad"), Edge(Symbol(1)))
    add_edge(g, hash("z"), hash("ad"), Edge(Symbol(0)))
    add_edge(g, hash("lit1"), hash("ad"), Edge(Symbol(2)))
    add_edge(g, hash("x"), hash("min"), Edge(Symbol(0)))
    return g
end

@testset "WlTrace" begin
    g = make_test_graph()

    @testset "method validation" begin
        @test_throws ErrorException WT.TraceState("nope", 1)
        @test_throws ErrorException WT.TraceState("wl-nc", -1)
        @test WT.TraceState("wl-nc", 1) isa WT.TraceState
    end

    @testset "trace matches original kernels (training mode)" begin
        for (method, kernel) in [
            ("wl", ZincToWl.StandardWl.wl_directed_last),
            ("wl-n", ZincToWl.NodeWl.wl_node_directed_last),
            ("wl-e", ZincToWl.EdgeWl.wl_edge_directed_last),
            ("wl-ne", ZincToWl.NodeEdgeWl.wl_node_edge_directed_last),
            ("wl-nc", ZincToWl.WlNodeCut.wl_node_cut_directed_last),
            ("wl-nec", ZincToWl.WlNodeEdgeCut.wl_node_edge_cut_directed_last),
        ]
            for k in 0:3
                st = WT.TraceState(method, k)
                levels = WT.trace!(st, g, 1)
                @test length(levels) == k + 1

                colors = Dict{UInt64,UInt64}()
                orig = kernel(g, colors, k, true, 1)
                @test levels[end] == orig

                # every color the kernel registered must be traced too
                # (with k = 0 the original kernels never register anything,
                # while the trace records the initialization colors)
                if !isempty(colors)
                    @test issubset(Set(collect(keys(colors))), Set(collect(keys(st.colors))))
                end
            end
        end
    end

    @testset "corpus accumulation and derivation records" begin
        st = WT.TraceState("wl-nc", 1)
        WT.trace!(st, g, 1)
        n_after_first = length(st.colors)
        WT.trace!(st, g, 2)   # same graph again: no new colors
        @test length(st.colors) == n_after_first
        @test Set(collect(keys(st.colors))) == Set(h for h in keys(st.colors))

        # every refined color must record its self parent and neighbors
        for (_, c) in st.colors
            if c.kind == :refined
                @test c.first_level == 1
                @test c.self_parent in keys(st.colors)
                for (_, nb, _, _) in c.nbs
                    @test nb in keys(st.colors)
                end
            else
                @test c.first_level == 0
                @test !isempty(c.sig)
            end
        end

        # type roots: var_node, literal_node, minimise_node and the cut node
        kinds = Dict{Symbol,Int}()
        for (_, c) in st.colors
            kinds[c.kind] = get(kinds, c.kind, 0) + 1
        end
        @test get(kinds, :type, 0) >= 3   # var_node, literal_node, minimise_node
        @test get(kinds, :cut, 0) >= 1    # all_different_node with its from-types sig

        # cut node color depends on the neighbor types signature
        cut = only([c for (_, c) in st.colors if c.kind == :cut])
        @test occursin("all_different_node", cut.sig)
        @test occursin("var_node", cut.sig)    # z feeds the cut node
        @test occursin("literal_node", cut.sig) # lit1 feeds the cut node

        # histograms: level totals
        @test sum(c.hist[1] for (_, c) in st.colors) == length(g.nodes) * 2  # two runs
    end
end
