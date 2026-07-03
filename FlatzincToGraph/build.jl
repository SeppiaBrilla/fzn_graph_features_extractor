using Pkg

@info "Activating project environment..."
Pkg.activate(".")

# 1. Enforce that all necessary dependencies are present
required_deps = ["PackageCompiler", "Parsers", "UUIDs"]

@info "Checking and installing dependencies..."
for dep in required_deps
    if !haskey(Pkg.project().dependencies, dep)
        @info "Adding missing dependency: $dep"
        Pkg.add(dep)
    end
end

# 2. Force precompilation AFTER dependencies are guaranteed to be there
@info "Clearing cache and forcing recompilation of source files..."
Pkg.precompile()

# 3. Import PackageCompiler after ensuring it is installed
using PackageCompiler

@info "Starting compilation process..."
build_dir = "out"

try
    create_app(
        ".",
        build_dir,
        force=true,
        incremental=false, # Compiles a fully independent system image
        filter_stdlibs=false # Ensures core stdlibs like UUIDs are kept intact
    )
    @info "Success! Executable generated at: ./$build_dir/bin/FlatzincToGraph"
catch e
    @error "Compilation failed" exception = (e, catch_backtrace())
    exit(1)
end

