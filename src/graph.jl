"""
    machine_chain(inst, op_chain) -> Vector{Vector{Int}}

Splits an operation chain (a permutation of the operation ids) by machine.
Entry k is the list of operations processed by machine k, in the order they
appear in `op_chain`.
"""
function machine_chain(inst::Instance, op_chain::Vector{Int})
    chain = [Int[] for _ in 1:inst.m]
    for u in op_chain
        push!(chain[inst.machine[u]], u)
    end
    return chain
end
