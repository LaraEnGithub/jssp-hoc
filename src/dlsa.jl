function critical_path!(path::Vector{Int}, ws::Workspace, inst::Instance, mprev::Vector{Int},
                        makespan::Int, rng::AbstractRNG)
    len = 0
    u = findfirst(==(makespan), ws.finish)
    while u != 0
        path[len += 1] = u
        pm = mprev[u]
        pj = inst.pos[u] > 1 ? u - 1 : 0
        on_machine = pm != 0 && ws.finish[pm] + inst.time[u] == ws.finish[u]
        on_job = pj != 0 && ws.finish[pj] + inst.time[u] == ws.finish[u]
        u = on_machine && (!on_job || rand(rng, Bool)) ? pm : on_job ? pj : 0
    end
    reverse!(path, 1, len)
    return len
end

"""
    n5_pairs!(pairs, inst, mnext, path, len) -> count

First operation of the swaps allowed by the N5 neighborhood on a critical path.
"""
function n5_pairs!(pairs::Vector{Int}, inst::Instance, mnext::Vector{Int}, path::Vector{Int}, len::Int)
    count = 0
    a = 1
    while a < len
        b = a
        while b < len && mnext[path[b]] == path[b + 1]
            b += 1
        end
        if b > a
            a > 1 && (pairs[count += 1] = path[a])
            b < len && !(a > 1 && b - 1 == a) && (pairs[count += 1] = path[b - 1])
        end
        a = b + 1
    end
    return count
end

function swap!(mnext::Vector{Int}, mprev::Vector{Int}, u::Int)
    v = mnext[u]
    p, w = mprev[u], mnext[v]
    p != 0 && (mnext[p] = v)
    mnext[v], mnext[u] = u, w
    mprev[v], mprev[u] = p, v
    w != 0 && (mprev[w] = u)
end

unswap!(mnext::Vector{Int}, mprev::Vector{Int}, v::Int) = swap!(mnext, mprev, v)

function leader_move!(new::Vector{Int}, ws::Workspace, inst::Instance, chain::Vector{Int}, moves::Int,
                      explore::Bool, pairs::Vector{Int}, path::Vector{Int}, rng::AbstractRNG)
    mnext = machine_next!(ws, inst, chain)
    mprev = ws.mprev
    fill!(mprev, 0)
    for u in 1:inst.n_ops
        mnext[u] != 0 && (mprev[mnext[u]] = u)
    end
    makespan, _ = makespan_and_cycles!(ws, inst, mnext)
    for _ in 1:moves
        count = n5_pairs!(pairs, inst, mnext, path, critical_path!(path, ws, inst, mprev, makespan, rng))
        count == 0 && break
        if explore
            u = pairs[rand(rng, 1:count)]
        else
            u, best, ties = 0, typemax(Int), 0
            for c in 1:count
                v = mnext[pairs[c]]
                swap!(mnext, mprev, pairs[c])
                m, cycles = makespan_and_cycles!(ws, inst, mnext)
                unswap!(mnext, mprev, v)
                cycles > 0 && continue
                if m < best
                    u, best, ties = pairs[c], m, 1
                elseif m == best && rand(rng) < 1 / (ties += 1)
                    u = pairs[c]
                end
            end
            u == 0 && break
        end
        swap!(mnext, mprev, u)
        makespan, _ = makespan_and_cycles!(ws, inst, mnext)
    end
    return copyto!(new, operation_chain!(ws, inst, mnext))
end

job_sequence!(seq::Vector{Int}, inst::Instance, chain::Vector{Int}) = map!(u -> inst.job[u], seq, chain)

function chain_from_jobs!(chain::Vector{Int}, seen::Vector{Int}, inst::Instance, seq::Vector{Int})
    fill!(seen, 0)
    for k in eachindex(seq)
        i = seq[k]
        seen[i] += 1
        chain[k] = (i - 1) * inst.m + seen[i]
    end
    return chain
end

# POX crossover: each job is taken from the leader with probability `take`
function toward_leader!(new::Vector{Int}, ws::Workspace, inst::Instance, chain::Vector{Int}, leader::Vector{Int},
                        take::Float64, seq::Vector{Int}, seq_leader::Vector{Int}, child::Vector{Int}, rng::AbstractRNG)
    keep = ws.job_ready
    for i in 1:inst.n
        keep[i] = rand(rng) >= take
    end
    job_sequence!(seq, inst, chain)
    job_sequence!(seq_leader, inst, leader)
    j = 1
    for k in eachindex(seq)
        if keep[seq[k]] == 1
            child[k] = seq[k]
        else
            while keep[seq_leader[j]] == 1
                j += 1
            end
            child[k] = seq_leader[j]
            j += 1
        end
    end
    return chain_from_jobs!(new, ws.seen, inst, child)
end

"""
    dlsa(inst; n_projectiles, max_iterations, seed, max_channel_time, channel_noise,
         fork_probability, patience, kick_swaps, crossover) -> (op_chain, Evaluation)

Lightning search over operation chains instead of random keys.
"""
function dlsa(inst::Instance; n_projectiles::Int = 50, max_iterations::Int = 2000, seed::Int = 67,
              max_channel_time::Int = 10, channel_noise::Float64 = 0.2, fork_probability::Float64 = 0.01,
              patience::Int = 100, kick_swaps::Int = 20, crossover::Float64 = 0.15)
    rng = Xoshiro(seed)
    ws = Workspace(inst)
    D = inst.n_ops
    decode! = inplace_decoder(HybridDecoder(0.0))
    makespan(chain) = evaluate!(ws, inst, chain).makespan

    X = [copy(decode!(ws, inst, rand(rng, D))) for _ in 1:n_projectiles]
    F = [makespan(x) for x in X]
    best = minimum(F)
    best_chain = copy(X[argmin(F)])
    stalled = 0
    channel_time = 0
    leader, new, alt, keys = zeros(Int, D), zeros(Int, D), zeros(Int, D), zeros(D)
    seq, seq_leader, child, pairs, path = (zeros(Int, D) for _ in 1:5)

    for t in 1:max_iterations
        channel_time += 1
        if channel_time >= max_channel_time
            worst, b = argmax(F), argmin(F)
            job_sequence!(seq, inst, X[b])
            slots = [k for k in 1:D if rand(rng) < channel_noise]
            seq[slots] = seq[shuffle(rng, slots)]
            chain_from_jobs!(X[worst], ws.seen, inst, seq)
            F[worst] = makespan(X[worst])
            channel_time = 0
        end

        l = argmin(F)
        copyto!(leader, X[l])
        explore = rand(rng) < energy(t, max_iterations) / energy(1, max_iterations)
        for i in eachindex(X)
            if i == l
                leader_move!(new, ws, inst, X[i], 1, explore, pairs, path, rng)
            else
                toward_leader!(new, ws, inst, X[i], leader, min(0.9, crossover * randexp(rng)), seq, seq_leader, child, rng)
                for k in 1:D
                    keys[new[k]] = k / D
                end
                copyto!(new, decode!(ws, inst, keys))
                new == leader && continue
            end
            m = makespan(new)
            if m <= F[i]
                copyto!(X[i], new)
                F[i] = m
                if rand(rng) < fork_probability
                    job_sequence!(seq, inst, new)
                    a, z = minmax(rand(rng, 1:D), rand(rng, 1:D))
                    reverse!(seq, a, z)
                    chain_from_jobs!(alt, ws.seen, inst, seq)
                    m = makespan(alt)
                    m <= F[i] && alt != leader && (copyto!(X[i], alt); F[i] = m)
                end
            end
        end

        if minimum(F) < best
            best = minimum(F)
            copyto!(best_chain, X[argmin(F)])
            stalled = 0
        elseif (stalled += 1) >= patience
            l = argmin(F)
            leader_move!(X[l], ws, inst, copy(X[l]), kick_swaps, true, pairs, path, rng)
            F[l] = makespan(X[l])
            stalled = 0
        end
    end

    return best_chain, evaluate(inst, best_chain)
end
