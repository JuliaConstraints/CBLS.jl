using CBLS
using Test

const _TARGETED_TESTITEM_RUN = !isempty(strip(get(ENV, "CBLS_TEST_TAGS", "")))

@testset "CBLS.jl" begin
    if !_TARGETED_TESTITEM_RUN
        include("Aqua.jl")
        # Official applicable MOI tests and bounded lifecycle/solve regressions
        # are testitems in moi_lifecycle.jl. Do not run an unbounded LP/conic
        # optimizer suite on a finite-domain heuristic backend.
        include("JuMP.jl")
    end
    include("TestItemRunner.jl")
end
