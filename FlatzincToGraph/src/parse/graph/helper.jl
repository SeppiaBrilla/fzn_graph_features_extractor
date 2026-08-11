module GraphHelper

using ..GraphType
using ..Parameters
using ..Variables
using ..Helper

function reset_counter()
    task_local_storage(:task_counter, 0)
    task_local_storage(:task_prefix, UInt64(0))
end

function get_next_global_id()
    tls = task_local_storage()
    counter = get(tls, :task_counter, 0) + 1
    tls[:task_counter] = counter
    prefix = get(tls, :task_prefix, UInt64(0))
    return prefix + counter
end

function normalize_list(val)
    if val isa Parameter
        val = val.value
    end
    if val isa AbstractVector
        return val
    end
    return [val]
end

function list_to_node(graph::Graph, components::Vector{Any}, type::Symbol=:int)::Node
    arr_label = "array_" * string(get_next_global_id())
    arr_node = Node(arr_label, :array_node, arr_label, hash(arr_label))
    add_node(graph, arr_node)
    for comp in components
        node = get_node_for_val(graph, comp, type)
        add_edge(graph, node.id, arr_node.id, Edge(:0))
    end
    return arr_node
end
list_to_node(graph::Graph, components::Vector{Any}, type::String) = list_to_node(graph, components, Symbol(type))

function get_type(value::String)
    return Symbol(Helper.get_type(value))
end

function get_type(value::Variable)::Symbol
    return Symbol(value.type)
end

function get_type(value::Parameter)::Symbol
    return Symbol(value.type.type.type)
end

# Helper to get variable node or literal node
function variable_or_literal(el::String, vars::Dict{String,Variable}, type::Symbol)::Node
    val = get(vars, el, nothing)
    if !isnothing(val)
        id = hash(val.name)
        return Node(val.name, Symbol(val.type), "$id: $(val.name) -- var_node -- $(val.type) -- $(val.domain_size)", id)
    end
    id = hash(el)
    return Node(el, type, "$id: $el -- literal_node -- $type -- $el", id)
end
variable_or_literal(el::String, vars::Dict{String,Variable}, type::String) = variable_or_literal(el, vars, Symbol(type))

# Helper to get parameter node or literal node
function parameter_or_literal(el::String, parameters::Dict{String,Parameter}, type::Symbol)::Node
    val = get(parameters, el, nothing)
    if !isnothing(val)
        id = hash(val.name)
        value = val.type.is_array ? "array of $(val.type.type.type)" : val.value
        return Node(val.name, Symbol(val.type.type.type), "$id: $(val.name) -- parameter_node -- $(val.type.type.type) -- $(value)", id)
    end
    id = hash(el)
    return Node(el, type, "$id: $el -- literal_node -- $type -- $el", id)
end
parameter_or_literal(el::String, parameters::Dict{String,Parameter}, type::String) = parameter_or_literal(el, parameters, Symbol(type))

# Resolve a single string component to a Variable, Parameter, or String literal
function resolve_component(comp::String, parameters::Dict{String,Parameter}, vars::Dict{String,Variable})
    var_val = get(vars, comp, nothing)
    if !isnothing(var_val)
        return var_val
    end
    param_val = get(parameters, comp, nothing)
    if !isnothing(param_val)
        return param_val
    end
    return comp
end

function resolve_component(comp::Vector{String}, parameters::Dict{String,Parameter}, vars::Dict{String,Variable})
    return [resolve_component(item, parameters, vars) for item in comp]
end

# Get or create node from a resolved component
function get_node_for_val(graph::Graph, val::Variable)::Node
    id = hash(val.name)
    node = get(graph.node_dict, id, nothing)
    if !isnothing(node)
        return node
    end
    node = Node(val.name, Symbol(val.type), "$id: $(val.name) -- var_node -- $(val.type) -- $(val.domain_size)", id)
    #add_node(graph, node)
    return node
end

function get_node_for_val(graph::Graph, val::Parameter)::Node
    id = hash(val.name)
    node = get(graph.node_dict, id, nothing)
    if !isnothing(node)
        return node
    end
    value = val.type.is_array ? "array of $(val.type.type.type)" : val.value
    node = Node(val.name, Symbol(val.type.type.type), "$id: $(val.name) -- parameter_node -- $(val.type.type.type) -- $(value)", id)
    add_node(graph, node)
    return node
end

function get_node_for_val(graph::Graph, val::Variable, type::Symbol)::Node
    return get_node_for_val(graph, val)
end
get_node_for_val(graph::Graph, val::Variable, type::String)::Node = get_node_for_val(graph, val, Symbol(type))

function get_node_for_val(graph::Graph, val::Parameter, type::Symbol)::Node
    if !val.type.is_array && val.type.type.type == "int" && val.value isa AbstractString
        return get_node_for_val(graph, string(val.value), type)
    end
    return get_node_for_val(graph, val)
end
get_node_for_val(graph::Graph, val::Parameter, type::String)::Node = get_node_for_val(graph, val, Symbol(type))

function get_node_for_val(graph::Graph, el::String, type::Symbol=:int)::Node
    id = hash(el)
    node = get(graph.node_dict, id, nothing)
    if !isnothing(node)
        return node
    end
    node = Node(el, type, "$id: $el -- literal_node -- $type -- $el", id)
    add_node(graph, node)
    return node
end
get_node_for_val(graph::Graph, el::String, type::String)::Node = get_node_for_val(graph, el, Symbol(type))

function build_generic_value(idx::UInt64, label::String, type::Union{Symbol,String})::String
    return "$idx: $label -- $type"
end

function flatten(list::Vector{Union{Vector{T},T}})::Vector{T} where T
    new_list = T[]
    for l in list
        if l isa Vector
            append!(new_list, l)
        else
            push!(new_list, l)
        end
    end
    return new_list
end

export variable_or_literal, parameter_or_literal, resolve_component, get_node_for_val, list_to_node, get_type, normalize_list, build_generic_value, flatten, reset_counter, get_next_global_id

end
