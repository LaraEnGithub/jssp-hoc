"""
    energy(t, T) -> Float64

Energy at iteration `t` of `T`.
"""
function energy(t::Int, T::Int)
    return 2.05 - 2 * exp(-5 * (T - t) / T) # values used in the original paper
end

"""
    keep_in_bounds!(x, rng)

Draws again uniformly in [0, 1] every key of `x` that is outside [0, 1].
"""
function keep_in_bounds!(x::Vector{Float64}, rng::AbstractRNG)
    for d in eachindex(x)
        if !(0 <= x[d] <= 1)
            x[d] = rand(rng)
        end
    end
    return x
end

"""
    update_directions!(dir, leader, f_leader, f)

Moves each key of the leader a little in its direction. The direction is kept only
if the cost gets strictly better; otherwise it is flipped. `f` gives the cost of a
vector of keys.
"""
function update_directions!(dir::Vector{Int}, leader::Vector{Float64}, f_leader::Float64, f)
    y = copy(leader)
    for d in eachindex(leader)
        y[d] = clamp(leader[d] + dir[d] * 0.005, 0.0, 1.0)
        if f(y) >= f_leader
            dir[d] = -dir[d]
        end
        y[d] = leader[d]
    end
    return dir
end

"""
    move_leader!(new, leader, dir, sigma, rng)

Writes into `new` the new position of the leader: each key takes a normal step of
size `sigma` in its direction.
"""
function move_leader!(new::Vector{Float64}, leader::Vector{Float64}, dir::Vector{Int}, sigma::Float64, rng::AbstractRNG)
    for d in eachindex(leader)
        new[d] = leader[d] + dir[d] * abs(sigma * randn(rng))
    end
    return new
end

"""
    move_space!(new, x, leader, rng)

Writes into `new` the new position of a projectile that is not the leader: each key
jumps toward the leader's key, a random distance whose mean is the distance between them.
"""
function move_space!(new::Vector{Float64}, x::Vector{Float64}, leader::Vector{Float64}, rng::AbstractRNG)
    for d in eachindex(x)
        new[d] = x[d] + (leader[d] - x[d]) * randexp(rng)
    end
    return new
end

"""
    lsa(inst; decode, n_projectiles, max_iterations, seed, probe_directions,
        kappa, max_channel_time, channel_noise, fork_probability, sweep) -> (op_chain, Evaluation)

Runs the lightning search algorithm on `inst` and returns the best operation chain found.
`decode` turns a vector of keys into an operation chain. If `sweep` is true the result is
improved with `local_sweep`. `channel_noise` is the probability that each key of the channel
copy is drawn again. If `probe_directions` is false the leader's directions are random.
"""
function lsa(inst::Instance; decode = HybridDecoder(0.0), n_projectiles::Int = 50,
             max_iterations::Int = 2000, seed::Int = 67, probe_directions::Bool = false,
             kappa::Union{Float64,Nothing} = nothing, max_channel_time::Int = 10, fork_probability::Float64 = 0.01,
             channel_noise::Float64 = 0.2, sweep::Bool = true)
    rng = Xoshiro(seed)
    kappa = something(kappa, 4 / inst.n_ops)
    ws = Workspace(inst)
    decode! = inplace_decoder(decode)
    f(x) = evaluate!(ws, inst, decode!(ws, inst, x)).f

    X = [rand(rng, inst.n_ops) for _ in 1:n_projectiles]   # projectiles
    F = [f(x) for x in X]                                   # their costs
    dir = rand(rng, [-1, 1], inst.n_ops)
    channel_time = 0
    leader = Vector{Float64}(undef, inst.n_ops)
    x_new = Vector{Float64}(undef, inst.n_ops)

    for t in 1:max_iterations
        # every max_channel_time iterations the worst projectile is replaced by a copy of the best
        channel_time += 1
        if channel_time >= max_channel_time
            worst, best = argmax(F), argmin(F)
            copyto!(X[worst], X[best])
            F[worst] = F[best]
            if channel_noise > 0
                for d in eachindex(X[worst])
                    rand(rng) < channel_noise && (X[worst][d] = rand(rng))
                end
                F[worst] = f(X[worst])
            end
            channel_time = 0
        end

        l = argmin(F)
        copyto!(leader, X[l])
        if probe_directions
            update_directions!(dir, leader, F[l], f)
        else
            rand!(rng, dir, [-1, 1])
        end
        sigma = energy(t, max_iterations) * kappa

        for i in eachindex(X)
            if X[i] == leader
                move_leader!(x_new, leader, dir, sigma, rng)
            else
                move_space!(x_new, X[i], leader, rng)
            end
            keep_in_bounds!(x_new, rng)
            f_new = f(x_new)
            if f_new < F[i]
                copyto!(X[i], x_new)
                F[i] = f_new
                # forking: sometimes also try the opposite position
                if rand(rng) < fork_probability
                    x_opp = 1 .- x_new
                    f_opp = f(x_opp)
                    if f_opp < F[i]
                        copyto!(X[i], x_opp)
                        F[i] = f_opp
                    end
                end
            end
        end
    end

    best = argmin(F)
    chain = decode(inst, X[best])
    return sweep ? local_sweep(inst, chain) : (chain, evaluate(inst, chain))
end
