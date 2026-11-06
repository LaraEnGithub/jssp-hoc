"""
    decode_operations(inst, x) -> Vector{Int}

Turns a vector of keys, one per operation, into an operation chain.
Solutions may be infeasible.
"""
function decode_operations(inst::Instance, x::Vector{Float64})
    return sortperm(x)
end

"""
    decode_repetition(inst, x) -> Vector{Int}

Turns a vector of keys into an operation chain that always respects the order of
each job. The solution is always feasible.
"""
decode_repetition(inst::Instance, x::Vector{Float64}) = copy(decode_repetition!(Workspace(inst), inst, x))

"""
    decode_operations!(ws, inst, x) -> ws.chain

`decode_operations` without allocating.
"""
decode_operations!(ws::Workspace, inst::Instance, x::Vector{Float64}) = sortperm!(ws.chain, x; scratch = ws.scratch)

"""
    decode_repetition!(ws, inst, x) -> ws.chain

`decode_repetition` without allocating.
"""
function decode_repetition!(ws::Workspace, inst::Instance, x::Vector{Float64})
    sortperm!(ws.order, x; scratch = ws.scratch)
    fill!(ws.seen, 0)
    for k in eachindex(ws.order)
        i = inst.job[ws.order[k]]
        ws.seen[i] += 1
        ws.chain[k] = (i - 1) * inst.m + ws.seen[i]
    end
    return ws.chain
end

"""
    decode_active!(ws, inst, x) -> ws.chain

Builds an active schedule (Giffler-Thompson): at each step it takes the operation that
could finish first, and among the operations that could start on its machine before that
time, the one with the smallest key. The solution is always feasible.
"""
function decode_active!(ws::Workspace, inst::Instance, x::Vector{Float64})
    next = ws.seen
    fill!(next, 1)
    fill!(ws.job_ready, 0)
    fill!(ws.mach_ready, 0)
    for step in 1:inst.n_ops
        best_op, best_end = 0, typemax(Int)
        for i in 1:inst.n
            next[i] > inst.m && continue
            u = (i - 1) * inst.m + next[i]
            finish = max(ws.job_ready[i], ws.mach_ready[inst.machine[u]]) + inst.time[u]
            if finish < best_end
                best_op, best_end = u, finish
            end
        end

        k = inst.machine[best_op]
        pick = best_op
        for i in 1:inst.n
            next[i] > inst.m && continue
            u = (i - 1) * inst.m + next[i]
            inst.machine[u] == k && max(ws.job_ready[i], ws.mach_ready[k]) < best_end && x[u] < x[pick] && (pick = u)
        end

        i = inst.job[pick]
        ws.job_ready[i] = ws.mach_ready[k] = max(ws.job_ready[i], ws.mach_ready[k]) + inst.time[pick]
        next[i] += 1
        ws.chain[step] = pick
    end
    return ws.chain
end

decode_active(inst::Instance, x::Vector{Float64}) = copy(decode_active!(Workspace(inst), inst, x))

inplace_decoder(::typeof(decode_operations)) = decode_operations!
inplace_decoder(::typeof(decode_repetition)) = decode_repetition!
inplace_decoder(::typeof(decode_active)) = decode_active!
