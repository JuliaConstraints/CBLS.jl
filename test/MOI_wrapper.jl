# ============================ /test/MOI_wrapper.jl ============================
module TestCBLS

import CBLS
using Test

import MathOptInterface as MOI

const OPTIMIZER = MOI.instantiate(
    MOI.OptimizerWithAttributes(CBLS.Optimizer, MOI.Silent() => true),
)

const BRIDGED = MOI.instantiate(
    MOI.OptimizerWithAttributes(CBLS.Optimizer, MOI.Silent() => true),
    with_bridge_type = Float64, with_cache_type = Float64
)

# See the docstring of MOI.Test.Config for other arguments.
const CONFIG = MOI.Test.Config(
    # Modify tolerances as necessary.
    atol = 1e-6,
    rtol = 1e-6,
    # Use MOI.LOCALLY_SOLVED for local solvers.
    optimal_status = MOI.LOCALLY_SOLVED    # Pass attributes or MOI functions to `exclude` to skip tests that    # rely on this functionality.    # exclude = Any[MOI.VariableName, MOI.delete]
)

"""
    runtests()

This function runs all functions in the this Module starting with `test_`.
"""
function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

"""
    test_runtests()

This function runs all the tests in MathOptInterface.Test.

Pass arguments to `exclude` to skip tests for functionality that is not
implemented or that your solver doesn't support.
"""
function test_runtests()
    MOI.Test.runtests(
        BRIDGED,
        CONFIG,
        exclude = [
            "test_attribute_SolveTimeSec", # Hang indefinitely
            "test_model_copy_to_UnsupportedAttribute", # Not supported. What it is suppsoed to be?
            "supports_constraint_VariableIndex_EqualTo" # Not supported. What it is suppsoed to be?
        ],
        # This argument is useful to prevent tests from failing on future
        # releases of MOI that add new tests. Don't let this number get too far
        # behind the current MOI release though. You should periodically check
        # for new tests to fix bugs and implement new features.
        exclude_tests_after = v"1.31.0",
        verbose = true
    )
    return
end

"""
    test_SolverName()

You can also write new tests for solver-specific functionality. Write each new
test as a function with a name beginning with `test_`.
"""
function test_SolverName()
    @test MOI.get(CBLS.Optimizer(), MOI.SolverName()) == "CBLS"
    return
end

end # module TestCBLS

# This line at the end of the file runs all the tests!
TestCBLS.runtests()
