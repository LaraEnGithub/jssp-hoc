@testset "InstanceFormatError" begin
    e = InstanceFormatError("foo.txt", 3, "machine 5 is outside 0..2")
    @test e isa Exception
    @test (e.source, e.line) == ("foo.txt", 3)
    @test sprint(showerror, e) == "InstanceFormatError: foo.txt:3: machine 5 is outside 0..2"
end

@testset "compute_bounds" begin
    # 3x3 example: longest job = 9, busiest machine (M2) = 10, total = 24
    machine = [1, 2, 3, 1, 3, 2, 2, 1, 3]
    time = [3, 3, 3, 2, 3, 4, 3, 2, 1]
    @test compute_bounds(3, 3, machine, time) == (10, 24)

    # the longest job wins over the busiest machine (10 > 6)
    @test compute_bounds(2, 2, [1, 2, 1, 2], [5, 5, 1, 1]) == (10, 12)

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
