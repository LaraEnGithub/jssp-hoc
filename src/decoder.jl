"""
    decode_operations(inst, x) -> Vector{Int}

Turns a vector of keys, one per operation, into an operation chain.
si Solutions may be infeasible.
"""
function decode_operations(inst::Instance, x::Vector{Float64})
    return sortperm(x)
end

"""
    decode_repetition(inst, x) -> Vector{Int}

Turns a vector of keys into an operation chain that always respects the order of
each job. 
The solution is always feasible.
"""
function decode_repetition(inst::Instance, x::Vector{Float64})
    seen = zeros(Int, inst.n)   # operations of each job already placed
    chain = Int[]
    for s in sortperm(x)
        i = inst.job[s]
        seen[i] += 1
        push!(chain, (i - 1) * inst.m + seen[i])
    end
    return chain
end
