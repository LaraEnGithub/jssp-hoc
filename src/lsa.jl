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
    move_leader(leader, dir, sigma, rng) -> Vector{Float64}

New position of the leader: each key takes a normal step of size `sigma` in its direction.
"""
function move_leader(leader::Vector{Float64}, dir::Vector{Int}, sigma::Float64, rng::AbstractRNG)
    return [leader[d] + dir[d] * abs(sigma * randn(rng)) for d in eachindex(leader)]
end

"""
    move_space(x, leader, rng) -> Vector{Float64}

New position of a projectile that is not the leader: each key jumps toward the
leader's key, a random distance whose mean is the distance between them.
"""
function move_space(x::Vector{Float64}, leader::Vector{Float64}, rng::AbstractRNG)
    return [x[d] + (leader[d] - x[d]) * randexp(rng) for d in eachindex(x)]
end

"""
    lsa(inst; decode, n_projectiles, max_iterations, seed, probe_directions,
        kappa, max_channel_time, fork_probability) -> (x, Evaluation)

Runs the lightning search algorithm on `inst`. Returns the best vector of keys found
and its evaluation. `decode` turns a vector of keys into an operation chain.
If `probe_directions` is false, the directions of the leader are drawn at random
each iteration instead of probing every key.
`kappa` scales the step of the leader, every `max_channel_time` iterations the worst
projectile becomes a copy of the best, and `fork_probability` is the chance of also
trying the opposite position after an accepted move.
"""
function lsa(inst::Instance; decode = decode_operations, n_projectiles::Int = 75,
             max_iterations::Int = 1000, seed::Int = 67, probe_directions::Bool = false,
             kappa::Float64 = 0.01, max_channel_time::Int = 10, fork_probability::Float64 = 0.01)
    rng = Xoshiro(seed)
    f(x) = evaluate(inst, decode(inst, x)).f

    X = [rand(rng, inst.n_ops) for _ in 1:n_projectiles]   # projectiles
    F = [f(x) for x in X]                                   # their costs
    dir = rand(rng, [-1, 1], inst.n_ops)
    channel_time = 0

    for t in 1:max_iterations
        # every max_channel_time iterations the worst projectile is replaced by a copy of the best
        channel_time += 1
        if channel_time >= max_channel_time
            worst, best = argmax(F), argmin(F)
            X[worst], F[worst] = copy(X[best]), F[best]
            channel_time = 0
        end

        l = argmin(F)
        leader = copy(X[l])
        if probe_directions
            update_directions!(dir, leader, F[l], f)
        else
            rand!(rng, dir, [-1, 1])
        end
        sigma = energy(t, max_iterations) * kappa

        for i in eachindex(X)
            if X[i] == leader
                x_new = move_leader(leader, dir, sigma, rng)
            else
                x_new = move_space(X[i], leader, rng)
            end
            keep_in_bounds!(x_new, rng)
            f_new = f(x_new)
            if f_new < F[i]
                X[i], F[i] = x_new, f_new
                # forking: sometimes also try the opposite position
                if rand(rng) < fork_probability
                    x_opp = 1 .- x_new
                    f_opp = f(x_opp)
                    if f_opp < F[i]
                        X[i], F[i] = x_opp, f_opp
                    end
                end
            end
        end
    end

    best = argmin(F)
    return X[best], evaluate(inst, decode(inst, X[best]))
end
