using Test
using ZincToWl

@testset "ZincToWl Test Suite" begin
    include("test_graph_loader.jl")
    include("test_helper.jl")
    include("test_wl_features.jl")
end
