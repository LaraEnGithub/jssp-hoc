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
