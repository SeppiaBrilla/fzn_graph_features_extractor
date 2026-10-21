using Pkg

@info "Activating project environment..."
project_dir = @__DIR__
Pkg.activate(project_dir)

@info "Force precompilation..."
Pkg.precompile()

using PackageCompiler

@info "Starting compilation process..."
build_dir = joinpath(project_dir, "out")
precompile_file = joinpath(project_dir, "precompile_script.jl")

try
    create_app(
        project_dir,
        build_dir,
        force=true,
        incremental=false,
        filter_stdlibs=false,
        precompile_execution_file=precompile_file
    )
    @info "Success! Executable generated at: $build_dir/bin/SatToGraph"
catch e
    @error "Compilation failed" exception = (e, catch_backtrace())
    exit(1)
end
