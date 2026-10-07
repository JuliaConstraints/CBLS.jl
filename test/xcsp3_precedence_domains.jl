@testitem "XCSP3 implicit precedence uses scope domains before search" default_imports=false begin
    using Test
    import CBLS
    import Constraints
    import MathOptInterface as MOI
    import ConstraintProgrammingExtensions as CPE

    function setup(; explicit = false, add_domains_first = false)
        optimizer = CBLS.Optimizer()
        variables = MOI.add_variables(optimizer, 4)
        add_domains() = foreach(enumerate(variables)) do (i, v)
            MOI.add_constraint(optimizer, v, CBLS.DiscreteSet(i == 1 ? [99] : [0, 1, 2]))
        end
        add_domains_first && add_domains()
        args = (; list = CPE.XCSP3Positions([3, 1, 2]))
        set = CPE.XCSP3Precedence(3;
            merge(args, explicit ? (; values = [0, 1, 2]) : (;))...)
        # Function positions deliberately differ from global variable indices.
        ci = MOI.add_constraint(optimizer, MOI.VectorOfVariables(variables[[4, 2, 3]]), set)
        add_domains_first || add_domains()
        return optimizer, variables, ci, set
    end

    @test Constraints.core_precedence_values(([0, 2], [1, 2])) == [0, 1, 2]
    @test !Constraints.core_satisfied(Val(:precedence),
        (; list = [2, 2, 2], domains = [0:2, 0:2, 0:2]))
    @test_throws ArgumentError Constraints.core_satisfied(Val(:precedence), (; list = [2, 2, 2]))

    for add_domains_first in (false, true)
        optimizer, variables, ci, set = setup(; add_domains_first)
        prepared = CBLS._prepare_xcsp3_domains!(optimizer, deepcopy(optimizer.backend_model))
        evaluator = CBLS.LS.get_constraint(prepared, ci.value).f
        for tuple in Iterators.product(0:2, 0:2, 0:2)
            assignment = collect(tuple)
            scoped = assignment[[3, 1, 2]]
            expected = all(1:2) do v
                !(v in scoped) || ((v - 1) in scoped &&
                    findfirst(==(v - 1), scoped) < findfirst(==(v), scoped))
            end
            @test iszero(evaluator(assignment)) == expected
        end
        @test evaluator([2, 2, 2]) > 0
        @test MOI.get(optimizer, MOI.ConstraintSet(), ci) == set
        @test !haskey(MOI.get(optimizer, MOI.ConstraintSet(), ci).arguments, :values)
        @test_throws ArgumentError CBLS.LS.get_constraint(optimizer.backend_model, ci.value).f([2, 2, 2])

        # A pure intension fixes the assignment without changing its domains.
        P, E = CPE.XCSP3Position, CPE.XCSP3Expression
        expression = E(:and, (E(:eq, P(i), 2) for i in 1:3)...)
        MOI.add_constraint(optimizer, MOI.VectorOfVariables(variables[[4, 2, 3]]),
            CPE.XCSP3Intension(3; expression))
        MOI.set(optimizer, MOI.Silent(), true)
        MOI.set(optimizer, MOI.NumberOfThreads(), 1)
        MOI.set(optimizer, MOI.TimeLimitSec(), 0.1)
        MOI.set(optimizer, MOI.RawOptimizerAttribute("iteration"), 2)
        MOI.optimize!(optimizer)
        @test CBLS.LS.get_constraint(optimizer.solver, ci.value).f([2, 2, 2]) > 0
        @test MOI.get(optimizer, MOI.ResultCount()) == 0
        MOI.optimize!(optimizer)
        @test MOI.get(optimizer, MOI.ConstraintSet(), ci) == set

        copied = CBLS.Optimizer()
        indices = MOI.copy_to(copied, optimizer)
        copy_model = CBLS._prepare_xcsp3_domains!(copied, deepcopy(copied.backend_model))
        @test CBLS.LS.get_constraint(copy_model, indices[ci].value).f([2, 2, 2]) > 0
    end

    explicit, _, ci, _ = setup(; explicit = true)
    prepared = CBLS._prepare_xcsp3_domains!(explicit, deepcopy(explicit.backend_model))
    @test CBLS.LS.get_constraint(prepared, ci.value).f([2, 2, 2]) > 0

    editable, variables, ci, set = setup()
    first_model = CBLS._prepare_xcsp3_domains!(editable, deepcopy(editable.backend_model))
    first_evaluator = CBLS.LS.get_constraint(first_model, ci.value).f
    @test first_evaluator([1, 1, 1]) > 0
    for v in variables[2:4]
        MOI.add_constraint(editable, v, MOI.GreaterThan(1))
    end
    second_model = CBLS._prepare_xcsp3_domains!(editable, deepcopy(editable.backend_model))
    @test iszero(CBLS.LS.get_constraint(second_model, ci.value).f([1, 1, 1]))
    @test first_evaluator([1, 1, 1]) > 0 # previously prepared domains stay immutable
    @test MOI.get(editable, MOI.ConstraintSet(), ci) == set

    continuous = CBLS.Optimizer()
    variables = MOI.add_variables(continuous, 2)
    for variable in variables
        MOI.add_constraint(continuous, variable, MOI.Interval(0.0, 2.0))
    end
    MOI.add_constraint(continuous, MOI.VectorOfVariables(variables),
        CPE.XCSP3Precedence(2; list = CPE.XCSP3Positions(1:2)))
    @test_throws ArgumentError CBLS._prepare_xcsp3_domains!(
        continuous, deepcopy(continuous.backend_model))
end
