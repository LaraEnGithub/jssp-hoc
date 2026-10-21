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
