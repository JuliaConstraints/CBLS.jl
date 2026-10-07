@testitem "Every remaining XCSP3 core family reaches the backend" tags=[:xcsp3, :core] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import MathOptInterface as MOI
    import Test: @test, @test_throws
    P = CPE.XCSP3Position
    V = CPE.XCSP3Positions
    E = CPE.XCSP3Expression
    C = CPE.XCSP3Condition
    cases = [
        (CPE.XCSP3Intension(3; expression = E(:eq, E(:add, P(1), P(2)), P(3))), [1,2,3], [1,2,4]),
        (CPE.XCSP3Extension(2; list = V(1:2), tuples = ([1, CPE.XCSP3Star()], [2,2])), [1,9], [2,9]),
        (CPE.XCSP3Extension(2; list = V(1:2), tuples = ([1,1],), positive = false), [1,2], [1,1]),
        (CPE.XCSP3Regular(2; list = V(1:2), transitions = [(0,1,1),(1,2,2),(0,1,3),(3,3,2)], start = 0, final = [2]), [1,2], [2,1]),
        (CPE.XCSP3MDD(2; list = V(1:2), transitions = [(0,1,1),(1,2,2)]), [1,2], [1,1]),
        (CPE.XCSP3AllDifferentLists(4; lists = (V(1:2), V(3:4))), [1,1,2,1], [1,2,1,2]),
        (CPE.XCSP3AllDifferentLists(4; matrix = V(reshape(1:4,2,2))), [1,2,2,1], [1,1,2,2]),
        (CPE.XCSP3AllEqual(3; list = V(1:3)), [2,2,2], [2,1,2]),
        (CPE.XCSP3Ordered(5; list = V(1:3), lengths = V(4:5)), [0,2,4,2,2], [0,1,4,2,2]),
        (CPE.XCSP3Lex(4; lists = (V(1:2), V(3:4)), operator = :lt), [0,2,1,0], [1,0,0,2]),
        (CPE.XCSP3Precedence(3; list = V(1:3), values = [1,2]), [0,1,2], [2,1,0]),
        (CPE.XCSP3Precedence(3; list = V(1:3), values = [1,2], covered = true), [1,2,1], [1,1,1]),
        (CPE.XCSP3Maximum(5; list = V(1:3), index = P(4), condition = C(:eq,P(5)), rank = :first), [1,3,3,2,3], [1,3,3,3,3]),
        (CPE.XCSP3Minimum(5; list = V(1:3), index = P(4), condition = C(:eq,P(5)), rank = :last), [1,1,2,2,1], [1,1,2,1,1]),
        (CPE.XCSP3Element(5; list = V(1:3), index = P(4), value = P(5), start_index = 0, rank = :first), [2,3,3,1,3], [2,3,3,2,3]),
        (CPE.XCSP3Element(3; matrix = [1 2;3 4], row_index = P(1), column_index = P(2), value = P(3)), [1,2,2], [1,2,3]),
        (CPE.XCSP3Channel(2; list = V(1:2), start_index = 0), [1,0], [0,0]),
        (CPE.XCSP3Channel(5; list = V(1:2), second = V(3:5)), [3,1,2,0,1], [3,1,1,0,1]),
        (CPE.XCSP3Channel(4; list = V(1:3), value = P(4), start_index = 0), [0,1,0,1], [0,1,1,1]),
        (CPE.XCSP3Stretch(4; list = V(1:4), values = [1,2], widths = [1:2,1:3], patterns = [(1,2)]), [1,1,2,2], [2,2,1,1]),
        (CPE.XCSP3NoOverlap(8; origins = V(reshape(1:4,2,2)), lengths = V(reshape(5:8,2,2))), [0,0,2,0,2,2,1,1], [0,0,1,0,2,2,1,1]),
        (CPE.XCSP3Cumulative(7; origins = V(1:2), lengths = V(3:4), heights = [1,2], ends = V(5:6), condition = C(:le,P(7))), [0,2,2,2,2,4,2], [0,2,2,2,2,4,1]),
        (CPE.XCSP3BinPacking(5; list = V(1:3), sizes = [2,3,4], loads = V(4:5)), [1,2,1,6,3], [1,2,1,7,3]),
        (CPE.XCSP3Knapsack(4; list = V(1:2), weights = [2,3], profits = [5,4], weight_condition = C(:le,P(3)), profit_condition = C(:ge,P(4))), [1,1,5,9], [1,1,4,9]),
        (CPE.XCSP3Instantiation(3; list = V(1:3), values = [1,2,3]), [1,2,3], [1,3,2]),
        (CPE.XCSP3Circuit(5; list = V(1:4), size = P(5), start_index = 0), [1,2,0,3,3], [1,0,3,2,4]),
        (CPE.XCSP3Slide(4; lists = (V(1:4),), offsets = [1], collects = [2], template = CPE.XCSP3Sum(2; condition = C(:eq,3))), [1,2,1,2], [1,2,3,2]),
    ]
    for (set, good, bad) in cases
        optimizer = CBLS.Optimizer()
        vars = MOI.add_variables(optimizer, MOI.dimension(set))
        @test MOI.supports_constraint(optimizer, MOI.VectorOfVariables, typeof(set))
        ci = MOI.add_constraint(optimizer, MOI.VectorOfVariables(vars), set)
        evaluator = CBLS.LS.get_constraint(optimizer.solver, ci.value).f
        @test iszero(evaluator(good))
        @test iszero(evaluator(Float64.(good)))
        @test evaluator(bad) > 0
        @test evaluator(Float64.(bad)) > 0
        @test copy(set) == set
        @test CPE.semantic_variant(set) == :xcsp3
        @test_throws DimensionMismatch evaluator([good; 0])
        @test MOI.is_valid(optimizer, ci)
        @test MOI.get(optimizer, MOI.ConstraintSet(), ci) == set
        @test MOI.get(optimizer, MOI.NumberOfConstraints{MOI.VectorOfVariables,typeof(set)}()) == 1
        for (variable, value) in zip(vars, good)
            MOI.add_constraint(optimizer, variable, MOI.EqualTo(Float64(value)))
        end
        copied = CBLS.Optimizer()
        mapping = MOI.copy_to(copied, optimizer)
        @test MOI.is_valid(copied, mapping[ci])
        MOI.set(copied, MOI.Silent(), true)
        MOI.set(copied, MOI.NumberOfThreads(), 1)
        MOI.set(copied, MOI.TimeLimitSec(), 2.0)
        MOI.set(copied, MOI.RawOptimizerAttribute("iteration"), 4)
        MOI.optimize!(copied)
        @test MOI.get(copied, MOI.ResultCount()) == 1
        @test MOI.get(copied, MOI.ConstraintPrimal(), mapping[ci]) == good
    end
    @test length(Set(CPE.semantic_id(first(case)) for case in cases)) == 21
    @test_throws ArgumentError CPE.XCSP3Minimum(2; list = V(1:2))
    @test_throws DimensionMismatch CPE.XCSP3Element(1; list = V(1:2), value = 0)
    @test_throws ArgumentError CPE.XCSP3Intension(1; expression = (a = [MOI.VariableIndex(1)],))
    @test_throws ArgumentError CPE.XCSP3Expression(:eval, "arbitrary code")
    lazy = CPE.XCSP3Intension(1; expression = E(:if, E(:eq,P(1),0), 1, E(:eq,E(:div,1,P(1)),1)))
    @test iszero(CBLS._xcsp3_evaluator(lazy)([0]))
end

@testitem "XCSP3 extrema and element exhaustive rank/index oracles" tags=[:xcsp3, :core] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import Test: @test
    for n in (1,3), rank in (:any,:first,:last), start in (0,1)
        for (family, operation) in ((CPE.XCSP3Minimum,minimum),(CPE.XCSP3Maximum,maximum),(CPE.XCSP3Element,nothing))
            args = (; list = CPE.XCSP3Positions(1:n), index = CPE.XCSP3Position(n+1), rank, start_index = start)
            target = CPE.XCSP3Position(n+2)
            set = isnothing(operation) ? family(n+2; args..., value = target) :
                family(n+2; args..., condition = CPE.XCSP3Condition(:eq,target))
            f = CBLS._xcsp3_evaluator(set)
            for x in Iterators.product(ntuple(_ -> 0:2,n)...), index in (start-1):(start+n), value in 0:2
                matching = findall(==(value), collect(x))
                local_index = index - start + 1
                expected = !isempty(matching) && local_index in matching &&
                    (isnothing(operation) || operation(x) == value) &&
                    (rank == :any || local_index == (rank == :first ? first(matching) : last(matching)))
                @test iszero(f([x...;index;value])) == expected
            end
        end
    end
end
