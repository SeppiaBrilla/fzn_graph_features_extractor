using Pkg
Pkg.activate(".")
include("src/parse/flatzinc_to_graph.jl")
using .FlatzincToGraphParser

# Warm up / compile
flatzinc_to_graph("../.cache/model.fzn")

# Measure
println("Running optimized execution...")
@time g = flatzinc_to_graph("../.cache/model.fzn")
println("Nodes: ", length(g.nodes))
println("Edges: ", length(g.edges))
