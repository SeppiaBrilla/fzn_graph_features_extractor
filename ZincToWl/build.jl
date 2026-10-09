using Pkg

@info "Activating project environment..."
project_dir = @__DIR__
Pkg.activate(project_dir)

# 1. Enforce that all necessary dependencies are present
required_deps = ["PackageCompiler", "ArgParse", "FlatzincToGraph", "PbToGraph", "Serialization", "Sockets"]

@info "Checking dependencies..."
for dep in required_deps
    if !haskey(Pkg.project().dependencies, dep)
        @error "Missing dependency in Project.toml: $dep"
        error("Missing dependency: $dep")
    end
end

# 2. Force precompilation AFTER dependencies are guaranteed to be there
@info "Clearing cache and forcing recompilation of source files..."
Pkg.precompile()

# 3. Import PackageCompiler after ensuring it is installed
using PackageCompiler

@info "Starting compilation process..."
build_dir = joinpath(project_dir, "out")
precompile_file = joinpath(project_dir, "precompile_script.jl")

try
    create_app(
        project_dir,
        build_dir,
        force=true,
        incremental=false, # Compiles a fully independent system image
        filter_stdlibs=false, # Ensures core stdlibs like Sockets, Serialization, UUIDs are kept intact
        precompile_execution_file=precompile_file
    )
    @info "Success! Executable generated at: $build_dir/bin/ZincToWl"
catch e
    @error "Compilation failed" exception = (e, catch_backtrace())
    exit(1)
end
