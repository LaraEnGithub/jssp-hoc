@testset "InstanceFormatError" begin
    e = InstanceFormatError("foo.txt", 3, "machine 5 is outside 0..2")
    @test e isa Exception
    @test (e.source, e.line) == ("foo.txt", 3)
    @test sprint(showerror, e) == "InstanceFormatError: foo.txt:3: machine 5 is outside 0..2"
end

@testset "compute_bounds" begin
    # 3x3 example: longest job = 9, busiest machine (M2) = 10, round-by-round schedule = 12
    machine = [1, 2, 3, 1, 3, 2, 2, 1, 3]
    time = [3, 3, 3, 2, 3, 4, 3, 2, 1]
    @test compute_bounds(3, 3, machine, time) == (10, 12)

    # the longest job wins over the busiest machine (10 > 6)
    @test compute_bounds(2, 2, [1, 2, 1, 2], [5, 5, 1, 1]) == (10, 11)

    # one job: both bounds equal the job length
    @test compute_bounds(1, 2, [1, 2], [2, 1]) == (3, 3)

    # one machine: both bounds equal the total load
    @test compute_bounds(2, 1, [1, 1], [2, 3]) == (5, 5)
end

@testset "parse_int" begin
    @test LSAJSSP.parse_int("42", "foo.txt", 1) == 42
    @test LSAJSSP.parse_int("0", "foo.txt", 1) == 0
    @test LSAJSSP.parse_int("-3", "foo.txt", 1) == -3

    for bad in ["x", "1.5", "1e3", ""]
        e = try
            LSAJSSP.parse_int(bad, "foo.txt", 4)
        catch err
            err
        end
        @test e isa InstanceFormatError
        @test (e.source, e.line) == ("foo.txt", 4)
    end
end

function thrown(f)
    try
        f()
    catch e
        return e
    end
    return nothing
end

const INSTANCES = joinpath(@__DIR__, "..", "instances")

@testset "parse_instance" begin
    # 3x3 example
    inst = parse_instance(IOBuffer("3 3 12 10\n0 3 1 3 2 3\n0 2 2 3 1 4\n1 3 0 2 2 1\n"), "example")
    @test inst.name == "example"
    @test (inst.n, inst.m, inst.n_ops) == (3, 3, 9)
    @test (inst.cu_file, inst.ci_file) == (12, 10)
    @test inst.job == [1, 1, 1, 2, 2, 2, 3, 3, 3]
    @test inst.pos == [1, 2, 3, 1, 2, 3, 1, 2, 3]
    @test inst.machine == [1, 2, 3, 1, 3, 2, 2, 1, 3]   # the file uses 0-based machines
    @test inst.time == [3, 3, 3, 2, 3, 4, 3, 2, 1]
    @test (inst.lower_bound, inst.upper_bound) == (10, 12)

    errors = [("", 1),
              ("1\n", 1),                         # header with one value
              ("1 2 5\n", 1),                     # header with three values
              ("1 x\n0 1 1 1\n", 1),              # not an integer in the header
              ("0 2 5 3\n", 1),                   # n = 0
              ("2 2 5 3\n0 1 1 1\n", 2),          # a job row is missing
              ("1 2 5 3\n0 1 1 1\n0 1 1 1\n", 3), # an extra job row
              ("1 2 5 3\n0 1 1\n", 2),            # incomplete pair
              ("1 2 5 3\n0 1 2 1\n", 2),          # machine out of range
              ("1 2 5 3\n0 1 1 -1\n", 2),         # negative time
              ("1 2 5 3\n0 1 1 x\n", 2),          # not an integer
              ("1 2 5 3\n\n0 1 1 x\n", 3)]        # empty lines count in the numbering
    for (text, line) in errors
        e = thrown(() -> parse_instance(IOBuffer(text), "test"))
        @test e isa InstanceFormatError
        @test e.line == line
    end

    @test_throws SystemError read_instance(joinpath(INSTANCES, "does_not_exist.txt"))
end
