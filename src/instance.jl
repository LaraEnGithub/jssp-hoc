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

"""
    parse_int(token, source, line) -> Int

Converts a piece of text to an integer. Throws an `InstanceFormatError` that points
to `source` and `line` if the text is not an integer.
"""
function parse_int(token::AbstractString, source::String, line::Int)
    value = tryparse(Int, token)
    value === nothing && throw(InstanceFormatError(source, line, "'$token' is not an integer"))
    return value
end

"""
    read_rows(io) -> Vector{Tuple{Int,Vector{String}}}

Splits the text into lines and each line into words (separated by any whitespace).
Empty lines are skipped. Each row is returned as `(line number, words)`, where the
line number is the one in the original text, empty lines included.
"""
function read_rows(io::IO)
    rows = Tuple{Int,Vector{String}}[]
    for (line, text) in enumerate(eachline(io))
        words = String.(split(text))
        isempty(words) || push!(rows, (line, words))
    end
    return rows
end

"""
    parse_header(rows, source) -> (n, m, cu_file, ci_file)

Reads the header `n m cu ci` from the first row. Throws an `InstanceFormatError`
if there is no header, it does not have exactly four integers, or `n` or `m`
is not positive.
"""
function parse_header(rows::Vector{Tuple{Int,Vector{String}}}, source::String)
    isempty(rows) && throw(InstanceFormatError(source, 1, "empty file"))

    line, words = rows[1]
    length(words) == 4 ||
        throw(InstanceFormatError(source, line, "header must be 'n m cu ci', found $(length(words)) values"))

    n, m, cu_file, ci_file = [parse_int(w, source, line) for w in words]
    n > 0 || throw(InstanceFormatError(source, line, "n must be positive"))
    m > 0 || throw(InstanceFormatError(source, line, "m must be positive"))
    return n, m, cu_file, ci_file
end
