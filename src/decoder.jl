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

inplace_decoder(::typeof(decode_operations)) = decode_operations!
inplace_decoder(::typeof(decode_repetition)) = decode_repetition!
