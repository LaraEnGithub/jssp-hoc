# Usage:
#   julia --project scripts/evaluate.jl instances/example_3x3.txt

using LSAJSSP

"""
    format_machine_chain(inst, mchain) -> String

Writes a machine chain as a list of lists, one machine per line. Operation j of
job i is written O(i,j).
"""
function format_machine_chain(inst::Instance, mchain::Vector{Vector{Int}})
    op_name(u) = "O($(inst.job[u]),$(inst.pos[u]))"
    lines = ["(" * join(op_name.(ops), ", ") * ")" for ops in mchain]
    return "[" * join(lines, ",\n ") * "]"
end

function main(args)
    if length(args) != 1
        println(stderr, "usage: julia --project scripts/evaluate.jl <instance.txt>")
        exit(1)
    end

    inst = read_instance(args[1])
    op_chain = collect(1:inst.n_ops)
    e = evaluate(inst, op_chain)

    println("Instance:  ", inst.name, " (", inst.n, " jobs, ", inst.m, " machines)")
    println("Bounds:    ", inst.lower_bound, " to ", inst.upper_bound)
    println("Makespan:  ", e.makespan)
    println("Cost f(X): ", e.f)
    if e.cycle_nodes == 0
        println("Feasible:  yes")
    else
        println("Feasible:  no (", e.cycle_nodes, " operations in cycles)")
    end

    println("Machine chain:")
    println(format_machine_chain(inst, machine_chain(inst, op_chain)))
end

main(ARGS)
