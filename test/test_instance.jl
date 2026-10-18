@testset "InstanceFormatError" begin
    e = InstanceFormatError("foo.txt", 3, "machine 5 is outside 0..2")
    @test e isa Exception
    @test (e.source, e.line) == ("foo.txt", 3)
    @test sprint(showerror, e) == "InstanceFormatError: foo.txt:3: machine 5 is outside 0..2"
end
