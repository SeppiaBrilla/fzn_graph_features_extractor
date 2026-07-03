import sys, os
from graph_loader import load_original_graph, load_new_graph
import subprocess
EMPTY_INSTANCE = "-empty-"

def make_flat(model:str, instance:str):
    subprocess.run([f"minizinc -c {model} {instance} --solver gecode --no-output-ozn --fzn ./.cache/model.fzn"], shell=True)


def make_graphs(model:str, instance:str):
    make_flat(model, instance)
    subprocess.run(["python ../flatzinc_parser/flatzinc_parser.py ./.cache/model.fzn ./.cache/original.graph"], shell=True)
    subprocess.run(["julia ./FlatzincToGraph/src/FlatzincToGraph.jl ./.cache/model.fzn ./.cache/new.graph"], shell=True)

def typer(t:str) -> str:
    if t == "par_node":
        return "literal_node"
    return t

def compare():
    # print("original")
    original = load_original_graph("./.cache/original.graph")
    # print("new")
    new = load_new_graph("./.cache/new.graph")

    print("####################################################")
    if not len(original.nodes) == len(new.nodes):
        print(f"different number of nodes, new: {len(new.nodes)}, original: {len(original.nodes)}")
        original_nodes = {}
        new_nodes = {}
        for node in original.nodes:
            if not node._type in original_nodes:
                original_nodes[node._type] = 0
            original_nodes[node._type] += 1
        for node in new.nodes:
            if not node._type in new_nodes:
                new_nodes[node._type] = 0
            new_nodes[node._type] += 1
        for k in new_nodes:
            if new_nodes[k] != original_nodes[k]:
                print(k, new_nodes[k], original_nodes[k])
        raise Exception()

    original_edges = {}
    for (k1, k2), v in original.edges.items():
        e = (typer(original.nodes_dict[k1]._type), typer(original.nodes_dict[k2]._type), v.label)
        if not e in original_edges:
            original_edges[e] = 0
        original_edges[e] += 1
    new_edges = {}
    for (k1, k2), v in new.edges.items():
        e = (typer(new.nodes_dict[k1]._type), typer(new.nodes_dict[k2]._type), v.label)
        if not e in new_edges:
            new_edges[e] = 0
        new_edges[e] += 1

    for e in original_edges:
        assert e in new_edges, e
        assert new_edges[e] == original_edges[e], (e, new_edges[e], original_edges[e])

def extract_instances(folder:str) -> list[tuple[str,str, str]]:
    res = []
    if not os.path.exists(folder): return res
    for p in os.listdir(folder):
        pd = os.path.join(folder, p)
        if not os.path.isdir(pd) or p.startswith("."): continue
        models = []
        insts = []
        for r, _, fs in os.walk(pd):
            for f in fs:
                path = os.path.join(r, f)
                if f.endswith(".mzn"):
                    models.append(path)
                elif f.endswith(".dzn") or f.endswith(".json"):
                    insts.append(path)
        if len(models) > 1:
            assert len(insts) == 0, "too many models."
            res.extend([(m, EMPTY_INSTANCE, pd) for m in models])
        elif len(models) == 1:
            res.extend([(models[0], i, pd) for i in insts])
    return res

def main():
    if len(sys.argv) == 3 or not os.path.isdir(sys.argv[1]):
        make_graphs(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "")
        compare()
        return
    instances = extract_instances(sys.argv[1])
    for (model, instance, _) in instances:
        print("running:\n\t", model, "\n\t", instance)
        make_graphs(model, instance if instance != EMPTY_INSTANCE else "")
        compare()

main()
