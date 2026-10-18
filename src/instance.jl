struct InstanceFormatError <: Exception
    source::String
    line::Int
    msg::String
end

function Base.showerror(io::IO, e::InstanceFormatError)
    print(io, "InstanceFormatError: ", e.source, ":", e.line, ": ", e.msg)
end

"""
A job shop instance: n jobs, each with m operations, on m machines.

Operations are numbered job by job: operation j of job i has id (i - 1) * m + j,
so the vectors below have one entry per operation and are indexed by that id.
"""
struct Instance
    name::String
    n::Int                 # number of jobs
    m::Int                 # number of machines
    n_ops::Int             # total number of operations, n * m
    job::Vector{Int}       # job that each operation belongs to
    pos::Vector{Int}       # position of each operation inside its job (1..m)
    machine::Vector{Int}   # machine that processes each operation (1..m)
    time::Vector{Int}      # processing time of each operation
    ci_file::Int           # lower bound written in the file header
    cu_file::Int           # upper bound written in the file header
    lower_bound::Int       # lower bound computed from the data
    upper_bound::Int       # upper bound computed from the data
end

"""
    compute_bounds(n, m, machine, time) -> (lower_bound, upper_bound)

Bounds on the makespan of any schedule.

- The upper bound is the sum of all processing times (everything done one after another).
- The lower bound is the larger of the longest job (its operations run in sequence)
  and the busiest machine (it processes one operation at a time).

`machine` and `time` have one entry per operation; the operations of job i are
the entries (i - 1) * m + 1 to i * m.
"""
function compute_bounds(n::Int, m::Int, machine::Vector{Int}, time::Vector{Int})
    longest_job = 0
    for i in 1:n
        first = (i - 1) * m + 1
        longest_job = max(longest_job, sum(@view time[first:first + m - 1]))
    end

    machine_load = zeros(Int, m)
    for u in eachindex(time)
        machine_load[machine[u]] += time[u]
    end

    lower_bound = max(longest_job, maximum(machine_load))
    upper_bound = sum(time)
    return lower_bound, upper_bound
end
