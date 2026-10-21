#!/usr/bin/env julia
#
# build_color_tree.jl — build the WL color-derivation visualization
#
# Replays a corpus of graphs (.graph or .fzn) with the ZincToWl training-mode
# WL kernels, records how every color in the color dictionary was derived, and
# emits a self-contained interactive HTML file (and/or a JSON data file).
#
# Usage:
#   julia --project=ZincToWl visualize/build_color_tree.jl <corpus> [out.html]
#         [-m wl-nc] [-k 1] [--colors colors.bin] [--json out.json]
#         [--files-list list.txt] [--limit N] [--title "My title"]
#
# <corpus> can be:
#   - a directory: every *.graph / *.fzn file inside it (recursively),
#     processed in sorted order;
#   - a file with one path per line (--files-list), e.g. the exact training
#     split used to build the colors file;
#   - a single .graph / .fzn file.

using ZincToWl
using FlatzincToGraph
using Serialization
using ArgParse
using Dates

const WT = ZincToWl.WlTrace
const GL = ZincToWl.GraphLoader

# ---------------------------------------------------------------- corpus ----

function collect_corpus(input::String, files_list::Union{Nothing,String})::Vector{String}
    if files_list !== nothing
        isfile(files_list) || error("--files-list $files_list not found")
        lines = readlines(files_list)
        files = String[]
        for l in lines
            l = strip(l)
            isempty(l) && continue
            push!(files, isabspath(l) ? String(l) : abspath(l))
        end
        return files
    end
    if isdir(input)
        files = String[]
        for (root, dirs, fs) in walkdir(input)
            for f in fs
                if endswith(f, ".graph") || endswith(f, ".fzn")
                    push!(files, joinpath(root, f))
                end
            end
        end
        return sort(files)
    end
    isfile(input) || error("input $input not found")
    return [abspath(input)]
end

using PbToGraph
using SatToGraph

function load_graph_file(path::String)
    if endswith(path, ".graph")
        return GL.load_graph(path)
    elseif endswith(path, ".fzn")
        return FlatzincToGraph.flatzinc_to_graph(path, 1)
    elseif endswith(path, ".cnf") || endswith(path, ".cnf.xz")
        return SatToGraph.sat_to_graph(path, 1)
    elseif endswith(path, ".opb") || endswith(path, ".wbo") || endswith(path, ".opb.xz") || endswith(path, ".wbo.xz") || (endswith(path, ".xz") && !endswith(path, ".fzn.xz"))
        return PbToGraph.pb_to_graph(path, 1)
    end
    error("unsupported corpus file type: $path")
end

# ------------------------------------------------------------------ json ----

function jstr(s::AbstractString)
    buf = IOBuffer()
    print(buf, '"')
    for c in s
        if c == '"'
            print(buf, "\\\"")
        elseif c == '\\'
            print(buf, "\\\\")
        elseif c == '\n'
            print(buf, "\\n")
        elseif c == '\r'
            print(buf, "\\r")
        elseif c == '\t'
            print(buf, "\\t")
        elseif c < ' '
            print(buf, "\\u", string(UInt32(c), base=16, pad=4))
        else
            print(buf, c)
        end
    end
    print(buf, '"')
    return String(take!(buf))
end

jnum(x::Integer) = string(x)
jnum(x::AbstractFloat) = isfinite(x) ? string(x) : "null"

function build_json(st::WT.TraceState, seed_keys::Set{UInt64}, files::Vector{String},
    colors_file::Union{Nothing,String}, k::Int, method::String, title::String;
    per_graph_top::Int=12)::String

    buf = IOBuffer()
    n_files = length(files)

    print(buf, "{\n\"meta\": {")
    print(buf, "\"title\": ", jstr(title), ", ")
    print(buf, "\"method\": ", jstr(method), ", ")
    print(buf, "\"iterations\": ", k, ", ")
    print(buf, "\"n_files\": ", n_files, ", ")
    print(buf, "\"n_colors\": ", length(st.colors), ", ")
    print(buf, "\"colors_file\": ", jstr(colors_file === nothing ? "" : colors_file), ", ")
    print(buf, "\"n_seed\": ", length(seed_keys), ", ")
    print(buf, "\"generated\": ", jstr(string(Dates.now())))
    print(buf, "},\n")

    print(buf, "\"files\": [")
    for (i, f) in enumerate(files)
        i > 1 && print(buf, ", ")
        print(buf, jstr(f))
    end
    print(buf, "],\n")

    # discovery timeline: color hashes in the order they were first seen
    print(buf, "\"discovery\": [")
    for (i, h) in enumerate(st.order)
        i > 1 && print(buf, ",")
        print(buf, jstr(string(h)))
    end
    print(buf, "],\n")

    # per-file color-set growth (size of the dictionary after each file)
    # recomputed from first_file of every color
    first_seen = Dict{Int,Int}()
    for (_, c) in st.colors
        first_seen[c.first_file] = get(first_seen, c.first_file, 0) + 1
    end
    print(buf, "\"new_per_file\": [")
    for i in 1:n_files
        i > 1 && print(buf, ",")
        print(buf, string(get(first_seen, i, 0)))
    end
    print(buf, "],\n")

    # colors
    print(buf, "\"colors\": {")
    first = true
    for h in st.order
        c = st.colors[h]
        first || print(buf, ",")
        first = false
        print(buf, "\n\t", jstr(string(h)), ": {")
        print(buf, "\"kind\": ", jstr(string(c.kind)), ", ")
        print(buf, "\"sig\": ", jstr(c.sig), ", ")
        print(buf, "\"first_file\": ", c.first_file, ", ")
        print(buf, "\"first_level\": ", c.first_level, ", ")
        print(buf, "\"seed\": ", (h in seed_keys ? "true" : "false"), ", ")
        print(buf, "\"g_init\": ", c.g_init, ", ")
        print(buf, "\"g_final\": ", c.g_final, ", ")
        print(buf, "\"hist\": [")
        for (i, v) in enumerate(c.hist)
            i > 1 && print(buf, ",")
            print(buf, string(v))
        end
        print(buf, "]")
        if c.kind == :refined
            print(buf, ", \"self\": ", jstr(string(c.self_parent)))
            print(buf, ", \"nbs\": [")
            for (i, (mixed, nb, labels, mult)) in enumerate(c.nbs)
                i > 1 && print(buf, ",")
                print(buf, "[", jstr(string(mixed)), ",", jstr(string(nb)), ",", jstr(labels), ",", string(mult), "]")
            end
            print(buf, "]")
        end
        # top files by final-level usage (compact)
        print(buf, ", \"use\": [")
        if !isempty(c.per_graph)
            top = sort(c.per_graph, by = p -> -p[2])[1:min(per_graph_top, length(c.per_graph))]
            for (i, (fi, cnt)) in enumerate(top)
                i > 1 && print(buf, ",")
                print(buf, "[", fi, ",", cnt, "]")
            end
        end
        print(buf, "]")
        print(buf, "}")
    end
    print(buf, "\n},\n")

    # adjacency between colors (parent color -> child color), derived from the
    # recorded signatures: the self parent plus every distinct neighbor color.
    parent_children = Dict{UInt64,Dict{UInt64,Int}}()
    function add_edge!(p::UInt64, ch::UInt64)
        pc = get!(() -> Dict{UInt64,Int}(), parent_children, p)
        pc[ch] = get(pc, ch, 0) + 1
    end
    for (_, c) in st.colors
        if c.kind == :refined
            add_edge!(c.self_parent, c.h)
            for (_, nb, _, _) in c.nbs
                if nb != c.self_parent
                    add_edge!(nb, c.h)
                end
            end
        elseif c.kind == :cut && !isempty(c.sig)
            # cut-node roots derive from their own type plus the distinct
            # neighbor types recorded in the signature ("gtype,ft1,ft2,...")
            parts = split(c.sig, ",")
            sig_from_types = Set{String}(parts[2:end])
            for (_, other) in st.colors
                if other.kind == :type && string(other.sig) in sig_from_types
                    add_edge!(other.h, c.h)
                end
            end
        end
    end
    print(buf, "\"edges\": [")
    first = true
    for (p, children) in sort(collect(parent_children); by = x -> string(x[1]))
        for (ch, _) in sort(collect(children); by = x -> string(x[1]))
            first || print(buf, ",")
            first = false
            print(buf, "[", jstr(string(p)), ",", jstr(string(ch)), "]")
        end
    end
    print(buf, "]\n}\n")

    return String(take!(buf))
end

# ------------------------------------------------------------------ cli -----

function parse_commandline(args)
    s = ArgParseSettings(description="Build the WL color derivation visualization.")
    @add_arg_table! s begin
        "input"
        help = "Corpus: directory, single file, or used with --files-list."
        required = true
        "output"
        help = "Output HTML file (default: color_tree.html in cwd)."
        required = false
        "--method", "-m"
        help = "WL method (must match how the colors file was trained)."
        arg_type = String
        default = "wl-nc"
        range_tester = x -> x in ["wl", "wl-n", "wl-e", "wl-ne", "wl-nc", "wl-nec"]
        "--wl-iterations", "-k"
        help = "Number of WL iterations."
        arg_type = Int
        default = 1
        "--colors"
        help = "Existing colors.bin to mark known (seed) colors."
        arg_type = String
        default = ""
        "--files-list"
        help = "Text file with one corpus path per line (e.g. the training split)."
        arg_type = String
        "--json"
        help = "Also write the raw JSON data to this file."
        arg_type = String
        "--limit"
        help = "Process at most N corpus files (0 = all)."
        arg_type = Int
        default = 0
        "--title"
        help = "Title shown in the HTML."
        arg_type = String
        default = ""
        "--template"
        help = "HTML template to use (default: template.html next to this script)."
        arg_type = String
    end
    return parse_args(args, s)
end

function main(args)
    parsed = parse_commandline(args)
    input = parsed["input"]
    out_html = parsed["output"]
    method = parsed["method"]
    k = parsed["wl-iterations"]
    colors_path = parsed["colors"]
    files_list = parsed["files-list"]
    json_path = parsed["json"]
    limit = parsed["limit"]
    title = parsed["title"]
    template_path = parsed["template"]

    if isnothing(out_html) || isempty(out_html)
        out_html = "color_tree.html"
    end
    if isnothing(title) || isempty(title)
        title = "WL color derivation — $(method) k=$(k)"
    end
    if isnothing(json_path)
        json_path = ""
    end
    if isnothing(limit)
        limit = 0
    end

    files = collect_corpus(input, files_list)
    if limit > 0
        files = files[1:min(limit, end)]
    end
    isempty(files) && error("empty corpus")
    println("corpus: $(length(files)) files")

    # seed colors (marked as known in the visualization)
    seed_keys = Set{UInt64}()
    if !isempty(colors_path)
        isfile(colors_path) || error("colors file $colors_path not found")
        seed = Serialization.deserialize(colors_path)
        if seed isa Dict
            for kk in keys(seed)
                push!(seed_keys, kk isa UInt64 ? kk : hash(kk))
            end
        end
        println("seed colors: $(length(seed_keys))")
    end

    st = WT.TraceState(method, k)
    t0 = time()
    for (i, f) in enumerate(files)
        g = load_graph_file(f)
        WT.trace!(st, g, i)
        if i % 100 == 0 || i == length(files)
            println("  [$i/$(length(files))] colors so far: $(length(st.colors)) ($(round(time() - t0; digits=1))s)")
        end
    end
    println("replay done: $(length(st.colors)) colors")

    json = build_json(st, seed_keys, files, isempty(colors_path) ? nothing : colors_path,
        k, method, title)

    if !isnothing(json_path) && !isempty(json_path)
        open(json_path, "w") do io
            write(io, json)
        end
        println("json written to $json_path")
    end

    if isnothing(template_path) || isempty(template_path)
        template_path = joinpath(@__DIR__, "template.html")
    end
    isfile(template_path) || error("template not found: $template_path")
    tpl = read(template_path, String)

    # safety: escape "</" so the JSON cannot close the script tag
    json_esc = replace(json, "</" => "<\\/")
    html = replace(tpl, "__COLOR_TREE_DATA__" => json_esc)
    html = replace(html, "__TITLE__" => title)

    open(out_html, "w") do io
        write(io, html)
    end
    println("visualization written to $out_html")
    println("open it with: xdg-open $(abspath(out_html))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
