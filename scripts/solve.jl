# Usage:
#   julia --project scripts/solve.jl instances/example_3x3.txt

using LSAJSSP

"""
    format_solution(inst, mchain, e) -> String

Writes a solution in the working format: one line per machine with the operations
as `[job, pos, time]`
"""
function format_solution(inst::Instance, mchain::Vector{Vector{Int}}, e::Evaluation)
    op_text(u) = "[$(inst.job[u] - 1), $(inst.pos[u] - 1), $(inst.time[u])], "
    lines = ["[ " * join(op_text.(ops)) * "]" for ops in mchain]
    push!(lines, "makespan: $(e.makespan)", "ciclos: $(e.cycle_nodes)",
          "Cota Sup: $(inst.upper_bound)", "Cota Inf: $(inst.lower_bound)", "Costo: $(e.f)")
    return join(lines, "\n")
end

function main(args)
    if length(args) != 1
        println(stderr, "usage: julia --project scripts/solve.jl <instance.txt>")
        exit(1)
    end

    inst = read_instance(args[1])
    decode = decode_repetition
    x, e = lsa(inst; decode = decode, probe_directions = false)
    println(format_solution(inst, machine_chain(inst, decode(inst, x)), e))
end

main(ARGS)
