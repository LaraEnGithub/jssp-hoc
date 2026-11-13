# Usage:
#   julia --project -t auto scripts/experiment.jl instances/JSSP_40_40.txt [--seeds k] > results/seeds.csv
#
# Runs the LSA once per seed, in parallel

using LSAJSSP
using Random

const DECODERS = Dict("repetition" => decode_repetition, "active" => decode_active, "operations" => decode_operations)

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
    n, t, kappa, channel, fork, decoder, noise, keys = 50, 2000, nothing, 10, 0.01, HybridDecoder(0.0), 0.2, false
    patience, kick, crossover, every = 100, 20, 0.15, 1
    k = 1
    while k <= length(args)
        flag = args[k]
        if flag in ("--seeds", "--random", "--n", "--t", "--channel", "--patience", "--kick", "--every") && k < length(args)
            number = tryparse(Int, args[k + 1])
            (number === nothing || number < 1) && return nothing
            if flag in ("--seeds", "--random")
                seeds === nothing || return nothing
                seeds = flag == "--seeds" ? collect(1:number) : random_seeds(number)
            end
            flag == "--n" && (n = number)
            flag == "--t" && (t = number)
            flag == "--channel" && (channel = number)
            flag == "--patience" && (patience = number)
            flag == "--kick" && (kick = number)
            flag == "--every" && (every = number)
            k += 2
        elseif flag == "--seed-list" && k < length(args)
            seeds === nothing || return nothing
            seeds = parse_seed_list(args[k + 1])
            seeds === nothing && return nothing
            k += 2
        elseif flag == "--decoder" && k < length(args)
            haskey(DECODERS, args[k + 1]) || return nothing
            decoder = DECODERS[args[k + 1]]
            k += 2
        elseif flag == "--keys"
            keys = true
            k += 1
        elseif flag == "--channel-noise" && k < length(args)
            number = tryparse(Float64, args[k + 1])
            (number === nothing || !(0 <= number <= 1)) && return nothing
            noise = number
            k += 2
        elseif flag == "--delay" && k < length(args)
            number = tryparse(Float64, args[k + 1])
            (number === nothing || !(0 <= number <= 1)) && return nothing
            decoder = HybridDecoder(number)
            k += 2
        elseif flag == "--crossover" && k < length(args)
            number = tryparse(Float64, args[k + 1])
            (number === nothing || number <= 0) && return nothing
            crossover = number
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
    return (path = path, seeds = something(seeds, collect(1:10)), n = n, t = t, kappa = kappa, channel = channel, fork = fork, decoder = decoder, noise = noise, keys = keys,
            patience = patience, kick = kick, crossover = crossover, every = every)
end

function main(args)
    options = parse_options(args)
    if options === nothing
        println(stderr, "usage: julia --project -t auto scripts/experiment.jl <instance.txt> ",
                "[--seeds k | --random k | --seed-list a,b,c] ",
                "[--n N] [--t T] [--kappa κ] [--channel c] [--fork p] [--decoder repetition|active|operations] [--delay δ] [--channel-noise p] [--keys] [--patience p] [--kick s] [--crossover β] [--every X]")
        exit(1)
    end

    inst = read_instance(options.path)
    # a tiny run first, so that compiling does not count in the time of seed 1
    lsa(inst; decode = options.decoder, n_projectiles = 2, max_iterations = 2, probe_directions = false)
    dlsa(inst; n_projectiles = 2, max_iterations = 2)

    runs = length(options.seeds)
    Threads.nthreads() == 1 && println(stderr, "warning: one thread; start Julia with -t auto to run in parallel")

    keys_only = options.keys ? " kappa=$(something(options.kappa, 4 / inst.n_ops)) decoder=$(options.decoder) probe=false" : ""
    println("# $(inst.name) algorithm=$(options.keys ? "lsa" : "dlsa") runs=$runs threads=$(Threads.nthreads()) n=$(options.n) t=$(options.t) ",
            "channel=$(options.channel) fork=$(options.fork) channel_noise=$(options.noise)",
            options.keys ? keys_only : " patience=$(options.patience) kick=$(options.kick) crossover=$(options.crossover)")
    println("# seed_list=", join(options.seeds, ","))
    println("seed,makespan,cycles,cost,seconds,makespan_lsa")

    output = ReentrantLock()
    finished, best = Ref(0), Ref((typemax(Int), Inf, 0))
    start = time()
    Threads.@threads :dynamic for seed in options.seeds
        seconds = @elapsed begin
            chain, e0 = if options.keys
                lsa(inst; decode = options.decoder, probe_directions = false,
                    n_projectiles = options.n, max_iterations = options.t, seed = seed,
                    kappa = options.kappa, max_channel_time = options.channel,
                    fork_probability = options.fork, channel_noise = options.noise, sweep = false)
            else
                dlsa(inst; n_projectiles = options.n, max_iterations = options.t, seed = seed,
                     max_channel_time = options.channel, channel_noise = options.noise,
                     fork_probability = options.fork, patience = options.patience,
                     kick_swaps = options.kick, crossover = options.crossover)
            end
            chain, e = local_sweep(inst, chain)
        end
        lock(output) do
            println("$seed,$(e.makespan),$(e.cycle_nodes),$(e.f),$(round(seconds, digits = 3)),$(e0.makespan)")
            flush(stdout)
            finished[] += 1
            e.makespan < best[][1] && (best[] = (e.makespan, e.f, seed))
            if finished[] % options.every == 0 || finished[] == runs
                m, f, s = best[]
                println(stderr, "$(finished[])/$runs   best makespan $m (cost $(round(f, digits = 5)), seed $s)   ",
                        "$(round((time() - start) / 60, digits = 1)) min")
            end
        end
    end
end

main(ARGS)
