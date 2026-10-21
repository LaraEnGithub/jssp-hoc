const EXAMPLE_3X3 = "3 3 24 10\n0 3 1 3 2 3\n0 2 2 3 1 4\n1 3 0 2 2 1\n"

@testset "machine_next" begin
    inst = parse_instance(IOBuffer(EXAMPLE_3X3), "example")
    # machine chain [(O11, O21, O32), (O12, O31, O23), (O13, O22, O33)]
    @test machine_next(inst, [[1, 4, 8], [2, 7, 6], [3, 5, 9]]) == [4, 7, 5, 8, 9, 0, 6, 0, 0]
end
