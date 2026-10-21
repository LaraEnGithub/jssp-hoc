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

"""
    makespan_and_cycles(inst, mnext) -> (makespan, cycle_nodes)

Runs Kahn's algorithm on the graph where each operation points to the next one of
its job and to the next one on its machine (`mnext`), computing the finish time of
every operation on the way.

`cycle_nodes` is the number of operations that could not be scheduled because they
are in a cycle or wait for one; the solution is feasible exactly when it is 0.
`makespan` is the largest finish time reached. For an infeasible solution it only
counts the operations reached before the deadlock, so it can even be 0.
"""
function makespan_and_cycles(inst::Instance, mnext::Vector{Int})
    # the next operation of the same job, or 0 if u is the last one
    job_next(u) = inst.pos[u] < inst.m ? u + 1 : 0

    degree = zeros(Int, inst.n_ops)
    for u in 1:inst.n_ops
        for v in (job_next(u), mnext[u])
            v != 0 && (degree[v] += 1)
        end
    end

    finish = zeros(Int, inst.n_ops)
    queue = Int[]
    for u in 1:inst.n_ops
        if degree[u] == 0
            push!(queue, u)
            finish[u] = inst.time[u]
        end
    end

    while !isempty(queue)
        u = popfirst!(queue)
        for v in (job_next(u), mnext[u])
            v == 0 && continue
            finish[v] = max(finish[v], finish[u] + inst.time[v])
            degree[v] -= 1
            degree[v] == 0 && push!(queue, v)
        end
    end

    makespan = maximum(finish)
    cycle_nodes = count(d -> d > 0, degree)
    return makespan, cycle_nodes
end
