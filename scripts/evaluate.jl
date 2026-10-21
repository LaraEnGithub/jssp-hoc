# Usage (from the project folder):
#   julia --project scripts/evaluate.jl instances/example_3x3.txt
#
# Evaluates the operation chain that processes the jobs one after another
# (every operation of job 1, then every operation of job 2, ...).

using LSAJSSP

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
end

main(ARGS)
