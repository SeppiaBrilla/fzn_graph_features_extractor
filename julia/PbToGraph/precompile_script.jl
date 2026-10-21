using FlatzincToGraph
using PbToGraph

# Precompile with sample instances
fixtures_dir = joinpath(@__DIR__, "test", "fixtures")
tmp_output = joinpath(@__DIR__, "precompile_out.graph")

try
    rm(tmp_output, force=true)

    files = String[]
    if isdir(fixtures_dir)
        for f in readdir(fixtures_dir)
            if endswith(f, ".opb") || endswith(f, ".wbo") || endswith(f, ".xz")
                push!(files, joinpath(fixtures_dir, f))
            end
        end
    end

    for file in files
        empty!(ARGS)
        push!(ARGS, file)
        push!(ARGS, tmp_output)
        push!(ARGS, "1")

        try
            PbToGraph.run_program(ARGS)
        catch e
            @warn "Precompilation failed for $file" exception=(e, catch_backtrace())
        end
    end
finally
    rm(tmp_output, force=true)
end
