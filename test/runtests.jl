using Test
using LSAJSSP

@testset "LSAJSSP" begin
    include("test_instance.jl")
    include("test_graph.jl")
    include("test_workspace.jl")
end
