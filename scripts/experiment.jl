# Usage:
#   julia --project scripts/experiment.jl instances/JSSP_40_40.txt [--seeds k] > results/seeds.csv
#
# Runs the LSA with seeds 1..k (10 by default) and writes one CSV row per seed.

using LSAJSSP

"""
    parse_options(args) -> (path, seeds) or nothing

Reads the instance path and the number of seeds (10 if `--seeds` is not given).
Returns `nothing` if the arguments are not valid.
"""
function parse_options(args::Vector{String})
    path, seeds = nothing, 10
    k = 1
    while k <= length(args)
        if args[k] == "--seeds" && k < length(args)
            number = tryparse(Int, args[k + 1])
            (number === nothing || number < 1) && return nothing
            seeds = number
            k += 2
        elseif !startswith(args[k], "--") && path === nothing
            path = args[k]
            k += 1
        else
            return nothing
        end
    end
    path === nothing && return nothing
    return path, seeds
end

function main(args)
    options = parse_options(args)
    if options === nothing
        println(stderr, "usage: julia --project scripts/experiment.jl <instance.txt> [--seeds k]")
        exit(1)
    end
    path, seeds = options
    n, t = 50, 500

    inst = read_instance(path)
    # a tiny run first, so that compiling does not count in the time of seed 1
    lsa(inst; decode = decode_repetition, n_projectiles = 2, max_iterations = 2, probe_directions = false)

    println("# $(inst.name) seeds=$seeds n=$n t=$t decoder=repetition probe=false")
    println("seed,makespan,cycles,cost,seconds")
    for seed in 1:seeds
        seconds = @elapsed x, e = lsa(inst; decode = decode_repetition, n_projectiles = n,
                                      max_iterations = t, seed = seed, probe_directions = false)
        println("$seed,$(e.makespan),$(e.cycle_nodes),$(e.f),$(round(seconds, digits = 3))")
        flush(stdout)
        println(stderr, "$seed/$seeds   makespan $(e.makespan)   $(round(seconds, digits = 1)) s")
    end
end

main(ARGS)
