"""
The result of evaluating a solution.

The solution is feasible exactly when `cycle_nodes` is 0. For an infeasible
solution `makespan` is only partial: it counts the operations reached before
the deadlock.
"""
struct Evaluation
    f::Float64          # cost to minimize
    makespan::Int       # finish time of the last operation
    cycle_nodes::Int    # operations stuck in a cycle or waiting for one
end

"""
    cost(inst, makespan, cycle_nodes) -> Float64

The cost to minimize:

    (makespan - lower_bound) / (upper_bound - lower_bound) + lower_bound * cycle_nodes
"""
function cost(inst::Instance, makespan::Int, cycle_nodes::Int)
    lower, upper = inst.lower_bound, inst.upper_bound
    normalized = upper == lower ? 0.0 : (makespan - lower) / (upper - lower)
    return normalized + lower * cycle_nodes
end

"""
    evaluate(inst, op_chain) -> Evaluation

Evaluates an operation chain to obtain the cost.
"""
function evaluate(inst::Instance, op_chain::Vector{Int})
    mchain = machine_chain(inst, op_chain)
    mnext = machine_next(inst, mchain)
    makespan, cycle_nodes = makespan_and_cycles(inst, mnext)
    return Evaluation(cost(inst, makespan, cycle_nodes), makespan, cycle_nodes)
end
