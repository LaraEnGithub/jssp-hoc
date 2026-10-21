"""
    machine_chain(inst, op_chain) -> Vector{Vector{Int}}

Splits an operation chain (a permutation of the operation ids) by machine.
"""
function machine_chain(inst::Instance, op_chain::Vector{Int})
    chain = [Int[] for _ in 1:inst.m]
    for u in op_chain
        push!(chain[inst.machine[u]], u)
    end
    return chain
end

"""
    machine_next(inst, mchain) -> Vector{Int}

For each operation, the operation that follows it on its machine according to
the machine chain `mchain`, or 0 if it is the last one on that machine.

Only consecutive operations of a machine are linked. A link from an operation to a
later, non-consecutive one would add nothing for feasible solutions, because the
path through the operations in between is at least as long.
"""
function machine_next(inst::Instance, mchain::Vector{Vector{Int}})
    next = zeros(Int, inst.n_ops)
    for ops in mchain
        for k in 1:length(ops) - 1
            next[ops[k]] = ops[k + 1]
        end
    end
    return next
end
