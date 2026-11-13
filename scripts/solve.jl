# Usage:
#   julia --project scripts/solve.jl instances/example_3x3.txt [--seed s] [--solution]

using LSAJSSP

"""
    format_solution(inst, mchain) -> String

Writes a solution in the working format: one line per machine with the operations
as `[job, pos, time]` (0-based).
"""
function format_solution(inst::Instance, mchain::Vector{Vector{Int}})
    op_text(u) = "[$(inst.job[u] - 1), $(inst.pos[u] - 1), $(inst.time[u])], "
    lines = ["[ " * join(op_text.(ops)) * "]" for ops in mchain]
    return join(lines, "\n")
end

"""
    format_summary(inst, e) -> String

Writes the makespan, cycles, bounds and cost of a solution, as at the end of the
working format.
"""
function format_summary(inst::Instance, e::Evaluation)
    lines = ["makespan: $(e.makespan)", "ciclos: $(e.cycle_nodes)",
             "Cota Sup: $(inst.upper_bound)", "Cota Inf: $(inst.lower_bound)", "Costo: $(e.f)"]
    return join(lines, "\n")
end

function main(args)
    print_solution = "--solution" in args
    paths = filter(a -> a != "--solution", args)
    seed = 67
    k = findfirst(==("--seed"), paths)
    if k !== nothing && k < length(paths) && tryparse(Int, paths[k + 1]) !== nothing
        seed = parse(Int, paths[k + 1])
        paths = paths[setdiff(eachindex(paths), k:k + 1)]
    end
    if length(paths) != 1
        println(stderr, "usage: julia --project scripts/solve.jl <instance.txt> [--seed s] [--solution]")
        exit(1)
    end

    inst = read_instance(paths[1])
    chain, _ = dlsa(inst; seed = seed)
    chain, e = local_sweep(inst, chain)
    if print_solution
        println(format_solution(inst, machine_chain(inst, chain)))
    end
    println(format_summary(inst, e))
end

main(ARGS)
