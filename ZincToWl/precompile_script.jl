using ZincToWl

precompile_dir = joinpath(@__DIR__, "..", "precompile_files")
colors_file = joinpath(@__DIR__, "precompile_colors.bin")

try
    rm(colors_file, force=true)

    methods = ["wl", "wl-n", "wl-e", "wl-ne", "wl-nc", "wl-nec"]

    # Find all .fzn and .graph files in precompile_files directory
    files = String[]
    if isdir(precompile_dir)
        for f in readdir(precompile_dir)
            if endswith(f, ".fzn") || endswith(f, ".graph")
                push!(files, joinpath(precompile_dir, f))
            end
        end
    end

    println("Precompiling ZincToWl with $(length(files)) files across $(length(methods)) methods...")

    train_toggle = true

    for file in files
        for m in methods
            empty!(ARGS)
            push!(ARGS, file)
            push!(ARGS, "--method", m)
            push!(ARGS, "--colors", colors_file)
            push!(ARGS, "--training", string(train_toggle))
            push!(ARGS, "--num-cores", "1")
            push!(ARGS, "--wl-iterations", "1")

            try
                ZincToWl.main()
            catch e
                @warn "Precompilation execution failed for file: $file, method: $m, training: $train_toggle" exception=(e, catch_backtrace())
            end

            train_toggle = !train_toggle
        end
    end
finally
    rm(colors_file, force=true)
    rm(joinpath(@__DIR__, "colors.bin"), force=true)
end
