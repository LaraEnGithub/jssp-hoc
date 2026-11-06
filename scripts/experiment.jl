# Usage:
#   julia --project -t auto scripts/experiment.jl instances/JSSP_40_40.txt [--seeds k] > results/seeds.csv
#
# Runs the LSA once per seed, in parallel

using LSAJSSP
using Random

function parse_seed_list(text::AbstractString)
    seeds = [tryparse(Int, s) for s in split(text, ",")]
    any(s -> s === nothing || s < 1, seeds) && return nothing
    length(unique(seeds)) == length(seeds) || return nothing
    return Vector{Int}(seeds)
end

function random_seeds(k::Int)
    seeds = Set{Int}()
    while length(seeds) < k
        push!(seeds, rand(RandomDevice(), 1:2^31 - 1))
    end
    return collect(seeds)
end

"""
    parse_options(args) -> NamedTuple or nothing

Reads the instance path and the options. Options that are not given keep their
default value. Returns `nothing` if the arguments are not valid.
"""
function parse_options(args::Vector{String})
    path, seeds = nothing, nothing
    n, t, kappa, channel, fork = 50, 500, 0.01, 10, 0.01
    k = 1
    while k <= length(args)
        flag = args[k]
        if flag in ("--seeds", "--random", "--n", "--t", "--channel") && k < length(args)
            number = tryparse(Int, args[k + 1])
            (number === nothing || number < 1) && return nothing
            if flag in ("--seeds", "--random")
                seeds === nothing || return nothing
                seeds = flag == "--seeds" ? collect(1:number) : random_seeds(number)
            end
            flag == "--n" && (n = number)
            flag == "--t" && (t = number)
            flag == "--channel" && (channel = number)
            k += 2
        elseif flag == "--seed-list" && k < length(args)
            seeds === nothing || return nothing
            seeds = parse_seed_list(args[k + 1])
            seeds === nothing && return nothing
            k += 2
        elseif flag in ("--kappa", "--fork") && k < length(args)
            number = tryparse(Float64, args[k + 1])
            (number === nothing || number < 0) && return nothing
            if flag == "--kappa"
                kappa = number
            elseif number <= 1
                fork = number
            else
                return nothing
            end
            k += 2
        elseif !startswith(flag, "--") && path === nothing
            path = flag
            k += 1
        else
            return nothing
        end
    end
    path === nothing && return nothing
    return (path = path, seeds = something(seeds, collect(1:10)), n = n, t = t, kappa = kappa, channel = channel, fork = fork)
end

function main(args)
    options = parse_options(args)
    if options === nothing
        println(stderr, "usage: julia --project -t auto scripts/experiment.jl <instance.txt> ",
                "[--seeds k | --random k | --seed-list a,b,c] ",
                "[--n N] [--t T] [--kappa κ] [--channel c] [--fork p]")
        exit(1)
    end

    inst = read_instance(options.path)
    # a tiny run first, so that compiling does not count in the time of seed 1
    lsa(inst; decode = decode_repetition, n_projectiles = 2, max_iterations = 2, probe_directions = false)

    runs = length(options.seeds)
    Threads.nthreads() == 1 && println(stderr, "warning: one thread; start Julia with -t auto to run in parallel")

    println("# $(inst.name) runs=$runs threads=$(Threads.nthreads()) n=$(options.n) t=$(options.t) ",
            "kappa=$(options.kappa) channel=$(options.channel) fork=$(options.fork) decoder=repetition probe=false")
    println("# seed_list=", join(options.seeds, ","))
    println("seed,makespan,cycles,cost,seconds")

    output = ReentrantLock()
    done = Threads.Atomic{Int}(0)
    Threads.@threads :dynamic for seed in options.seeds
        seconds = @elapsed x, e = lsa(inst; decode = decode_repetition, probe_directions = false,
                                      n_projectiles = options.n, max_iterations = options.t, seed = seed,
                                      kappa = options.kappa, max_channel_time = options.channel,
                                      fork_probability = options.fork)
        lock(output) do
            println("$seed,$(e.makespan),$(e.cycle_nodes),$(e.f),$(round(seconds, digits = 3))")
            flush(stdout)
            finished = Threads.atomic_add!(done, 1) + 1
            println(stderr, "$finished/$runs   seed $seed   makespan $(e.makespan)   $(round(seconds, digits = 1)) s")
        end
    end
end

main(ARGS)
