using ZincToWl

fzn_content = """
var 1..10: x;
var 1..10: y;
constraint int_lt(x, y);
solve satisfy;
"""

open("precompile_dummy.fzn", "w") do f
    write(f, fzn_content)
end

empty!(ARGS)
push!(ARGS, "precompile_dummy.fzn")
push!(ARGS, "--method", "wl-nc")
push!(ARGS, "--training", "true")

try
    ZincToWl.main()
catch e
    @warn "Precompilation script had a runtime error" exception=(e, catch_backtrace())
end

rm("precompile_dummy.fzn", force=true)
