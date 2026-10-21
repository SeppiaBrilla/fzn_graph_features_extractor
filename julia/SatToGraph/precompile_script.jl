using FlatzincToGraph
using SatToGraph

fixtures_dir = joinpath(@__DIR__, "test", "fixtures")
tmp_output = joinpath(@__DIR__, "precompile_out.graph")

try
    rm(tmp_output, force=true)

    files = String[]
    if isdir(fixtures_dir)
        for f in readdir(fixtures_dir)
            if endswith(f, ".cnf") || endswith(f, ".xz")
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
            SatToGraph.run_program(ARGS)
        catch e
            @warn "Precompilation failed for $file" exception=(e, catch_backtrace())
        end
    end
finally
    rm(tmp_output, force=true)
end
