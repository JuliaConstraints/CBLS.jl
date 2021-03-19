using CBLS
using Test

@testset "CBLS.jl" begin
    include("MOI_wrapper.jl")
    include("JuMP.jl")
end
