using FlatzincToGraph

precompile_dir = joinpath(@__DIR__, "..", "precompile_files")
tmp_output = joinpath(@__DIR__, "precompile_out.graph")

try
    rm(tmp_output, force=true)

    # Find all .fzn files in precompile_files directory
    files = String[]
    if isdir(precompile_dir)
        for f in readdir(precompile_dir)
            if endswith(f, ".fzn")
                push!(files, joinpath(precompile_dir, f))
            end
        end
    end

    println("Precompiling FlatzincToGraph with $(length(files)) .fzn files...")

    for file in files
        empty!(ARGS)
        push!(ARGS, file)
        push!(ARGS, tmp_output)
        push!(ARGS, "1") # num_cores

        try
            FlatzincToGraph.run_program(ARGS)
        catch e
            @warn "Precompilation execution failed for file: $file" exception=(e, catch_backtrace())
        end
    end
finally
    rm(tmp_output, force=true)
end
