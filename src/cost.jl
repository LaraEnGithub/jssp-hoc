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

For a feasible solution the first term places the makespan between the bounds:
0 at the lower bound, 1 at the upper bound. The second term penalizes infeasibility:
each operation stuck in a cycle adds the whole lower bound. When both bounds are
equal the first term is taken as 0, since every feasible makespan equals them.
"""
function cost(inst::Instance, makespan::Int, cycle_nodes::Int)
    lower, upper = inst.lower_bound, inst.upper_bound
    normalized = upper == lower ? 0.0 : (makespan - lower) / (upper - lower)
    return normalized + lower * cycle_nodes
end
