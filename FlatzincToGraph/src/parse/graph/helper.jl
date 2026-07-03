module GraphHelper

using ..GraphType
using ..Parameters
using ..Variables
using ..Helper
using UUIDs

function normalize_list(val)
    if val isa Parameter
        val = val.value
    end
    if val isa AbstractVector
        return val
    end
    return [val]
end

function list_to_node(graph::Graph, components::Vector{Any}, type::String="int")::Node
    arr_label = "array_" * string(UUIDs.uuid4())
    arr_node = Node(arr_label, "array_node", arr_label, hash(arr_label))
    add_node(graph, arr_node)
    for comp in components
        node = get_node_for_val(graph, comp, type)
        add_edge(graph, node.id, arr_node.id, Edge("0"))
    end
    return arr_node
end


function get_type(value::String)
    return Helper.get_type(value)
end

function get_type(value::Variable)::String
    return value.type
end

function get_type(value::Parameter)::String
    return value.type.type.type
end

# Helper to get variable node or literal node
function variable_or_literal(el::String, vars::IdDict{String,Variable}, type::String)::Node
    val = get(vars, intern(el), nothing)
    if !isnothing(val)
        id = hash(val.name)
        return Node(val.name, val.type, "$id: $(val.name) -- var_node -- $(val.type) -- $(val.domain_size)", id)
    end
    id = hash(el)
    return Node(el, type, "$id: $el -- literal_node -- $type -- $el", id)
end

# Helper to get parameter node or literal node
function parameter_or_literal(el::String, parameters::IdDict{String,Parameter}, type::String)::Node
    val = get(parameters, intern(el), nothing)
    if !isnothing(val)
        id = hash(val.name)
        value = val.type.is_array ? "array of $(val.type.type.type)" : val.value
        return Node(val.name, val.type.type.type, "$id: $(val.name) -- parameter_node -- $(val.type.type.type) -- $(value)", id)
    end
    id = hash(el)
    return Node(el, type, "$id: $el -- literal_node -- $type -- $el", id)
end

# Resolve a single string component to a Variable, Parameter, or String literal
function resolve_component(comp::String, parameters::IdDict{String,Parameter}, vars::IdDict{String,Variable})
    comp_interned = intern(comp)
    var_val = get(vars, comp_interned, nothing)
    if !isnothing(var_val)
        return var_val
    end
    param_val = get(parameters, comp_interned, nothing)
    if !isnothing(param_val)
        return param_val
    end
    return comp
end

function resolve_component(comp::Vector{String}, parameters::IdDict{String,Parameter}, vars::IdDict{String,Variable})
    return [resolve_component(item, parameters, vars) for item in comp]
end

# Get or create node from a resolved component
function get_node_for_val(graph::Graph, val::Variable)::Node
    id = hash(val.name)
    node = get(graph.node_dict, id, nothing)
    if !isnothing(node)
        return node
    end
    node = Node(val.name, val.type, "$id: $(val.name) -- var_node -- $(val.type) -- $(val.domain_size)", id)
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
    node = Node(val.name, val.type.type.type, "$id: $(val.name) -- parameter_node -- $(val.type.type.type) -- $(value)", id)
    add_node(graph, node)
    return node
end

function get_node_for_val(graph::Graph, val::Variable, type::String)::Node
    return get_node_for_val(graph, val)
end

function get_node_for_val(graph::Graph, val::Parameter, type::String)::Node
    if !val.type.is_array && val.type.type.type == "int" && val.value isa AbstractString
        return get_node_for_val(graph, string(val.value), type)
    end
    return get_node_for_val(graph, val)
end

function get_node_for_val(graph::Graph, el::String, type::String="int")::Node
    id = hash(el)
    node = get(graph.node_dict, id, nothing)
    if !isnothing(node)
        return node
    end
    node = Node(el, type, "$id: $el -- literal_node -- $type -- $el", id)
    add_node(graph, node)
    return node
end

function build_generic_value(idx::UInt64, label::String, type::String)::String
    return "$idx: $label -- $type"
end

function flatten(list::Vector{Union{Vector{T},T}})::Vector{T} where T
    new_list = T[]
    for l in list
        if l isa Vector
            new_list = [new_list; l]
        else
            push!(new_list, l)
        end
    end
    return new_list
end

export variable_or_literal, parameter_or_literal, resolve_component, get_node_for_val, list_to_node, get_type, normalize_list, build_generic_value, flatten

end
