function operation_chain!(ws::Workspace, inst::Instance, mnext::Vector{Int})
    makespan_and_cycles!(ws, inst, mnext)
    return sortperm(ws.finish .- inst.time; alg = MergeSort)
end

"""
    local_sweep(inst, op_chain) -> (op_chain, Evaluation)

Swaps consecutive operations of a machine while the makespan improves.
"""
function local_sweep(inst::Instance, op_chain::Vector{Int})
    ws = Workspace(inst)
    mnext = machine_next!(ws, inst, op_chain)
    best, cycles = makespan_and_cycles!(ws, inst, mnext)
    cycles > 0 && return op_chain, evaluate(inst, op_chain)

    mprev = ws.mprev
    fill!(mprev, 0)
    for u in 1:inst.n_ops
        mnext[u] != 0 && (mprev[mnext[u]] = u)
    end

    improved = true
    while improved
        improved = false
        for u in 1:inst.n_ops
            v = mnext[u]
            (v == 0 || inst.job[u] == inst.job[v]) && continue
            p, w = mprev[u], mnext[v]
            p != 0 && (mnext[p] = v)
            mnext[v], mnext[u] = u, w
            makespan, cycles = makespan_and_cycles!(ws, inst, mnext)
            if cycles == 0 && makespan < best
                best, improved = makespan, true
                mprev[v], mprev[u] = p, v
                w != 0 && (mprev[w] = u)
            else
                p != 0 && (mnext[p] = u)
                mnext[v], mnext[u] = w, v
            end
        end
    end

    chain = operation_chain!(ws, inst, mnext)
    return chain, evaluate(inst, chain)
end
