using CBLS
using Test

@testset "CBLS.jl" begin
    include("Aqua.jl")
    include("MOI_wrapper.jl")
    include("JuMP.jl")
    include("TestItemRunner.jl")
end
