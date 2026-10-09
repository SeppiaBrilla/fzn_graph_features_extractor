using Pkg

@info "Activating project environment..."
Pkg.activate(".")

@info "Force precompilation..."
Pkg.precompile()

using PackageCompiler

@info "Starting compilation process..."
build_dir = "out"

try
    create_app(
        ".",
        build_dir,
        force=true,
        incremental=false,
        filter_stdlibs=false,
        precompile_execution_file="precompile_script.jl"
    )
    @info "Success! Executable generated at: ./$build_dir/bin/PbToGraph"
catch e
    @error "Compilation failed" exception = (e, catch_backtrace())
    exit(1)
end
