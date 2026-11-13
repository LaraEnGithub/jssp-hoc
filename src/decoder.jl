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
    decode_hybrid!(ws, inst, x, delay) -> ws.chain

Hybrid schedule builder (Bierwirth and Mattfeld, 1999). `delay = 1` gives an active
schedule (Giffler-Thompson) and `delay = 0` a non-delay one. Always feasible.
"""
function decode_hybrid!(ws::Workspace, inst::Instance, x::Vector{Float64}, delay::Float64)
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
        first_start = typemax(Int)
        for i in 1:inst.n
            next[i] > inst.m && continue
            u = (i - 1) * inst.m + next[i]
            inst.machine[u] == k && (first_start = min(first_start, max(ws.job_ready[i], ws.mach_ready[k])))
        end

        limit = first_start + delay * (best_end - first_start)
        pick = 0
        for i in 1:inst.n
            next[i] > inst.m && continue
            u = (i - 1) * inst.m + next[i]
            inst.machine[u] == k || continue
            start = max(ws.job_ready[i], ws.mach_ready[k])
            (start == first_start || start < limit) && (pick == 0 || x[u] < x[pick]) && (pick = u)
        end

        i = inst.job[pick]
        ws.job_ready[i] = ws.mach_ready[k] = max(ws.job_ready[i], ws.mach_ready[k]) + inst.time[pick]
        next[i] += 1
        ws.chain[step] = pick
    end
    return ws.chain
end

"""
    HybridDecoder(delay)

`decode_hybrid!` with a fixed `delay`, usable as `decode` in `lsa`.
"""
struct HybridDecoder
    delay::Float64
end

(d::HybridDecoder)(inst::Instance, x::Vector{Float64}) = copy(decode_hybrid!(Workspace(inst), inst, x, d.delay))

decode_active!(ws::Workspace, inst::Instance, x::Vector{Float64}) = decode_hybrid!(ws, inst, x, 1.0)
decode_active(inst::Instance, x::Vector{Float64}) = copy(decode_active!(Workspace(inst), inst, x))

inplace_decoder(::typeof(decode_operations)) = decode_operations!
inplace_decoder(::typeof(decode_repetition)) = decode_repetition!
inplace_decoder(::typeof(decode_active)) = decode_active!
inplace_decoder(d::HybridDecoder) = (ws, inst, x) -> decode_hybrid!(ws, inst, x, d.delay)
