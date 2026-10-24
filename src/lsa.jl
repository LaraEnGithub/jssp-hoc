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
