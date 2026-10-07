@testitem "XCSP3 counting independent exhaustive oracles" tags=[:xcsp3, :moi] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import MathOptInterface as MOI
    import Test: @test, @test_throws

    # All tests invoke the actual evaluator installed in the backend, not a
    # reimplementation of the adapter. Oracles use elementary Julia operations.
    function installed(set)
        optimizer = CBLS.Optimizer()
        variables = MOI.add_variables(optimizer, MOI.dimension(set))
        @test MOI.supports_constraint(optimizer, MOI.VectorOfVariables, typeof(set))
        index = MOI.add_constraint(optimizer, MOI.VectorOfVariables(variables), set)
        f = CBLS.LS.get_constraint(optimizer.solver, index.value).f
        @test_throws DimensionMismatch f(zeros(Int, MOI.dimension(set) + 1))
        @test_throws DimensionMismatch MOI.add_constraint(optimizer,
            MOI.VectorOfVariables(variables[1:(end - 1)]), set)
        return f
    end
    operators = ((:eq, ==), (:ne, !=), (:lt, <), (:le, <=), (:gt, >), (:ge, >=),
        (:in, in), (:notin, (x, y) -> x ∉ y))
    for n in (1, 3), (name, op) in operators
        operands = name in (:in, :notin) ?
            (CPE.XCSP3Interval(1, 2), CPE.XCSP3ValueSet(Set([0, 2])),
                CPE.XCSP3ValueSet(Set{Int}())) :
            (CPE.XCSP3Constant(2), CPE.XCSP3Variable())
        for operand in operands
            condition = CPE.XCSP3Condition(name, operand)
            target_variable = operand isa CPE.XCSP3Variable
            targets = target_variable ? (0:4) : (nothing,)
            static_target = operand isa CPE.XCSP3Constant ? operand.value :
                operand isa CPE.XCSP3Interval ? (operand.lower:operand.upper) :
                operand isa CPE.XCSP3ValueSet ? operand.values : nothing
            for value_spec in (CPE.XCSP3Constants([0, 1]), CPE.XCSP3Constants([1, 1]),
                    CPE.XCSP3Constants(Int[]), CPE.XCSP3Variables(2))
                set = CPE.XCSP3Count(n; values = value_spec, condition)
                f = installed(set)
                variable_values = value_spec isa CPE.XCSP3Variables
                choices = variable_values ? ([0, 1], [1, 1], [2, 0]) : (value_spec.values,)
                for x in Iterators.product(ntuple(_ -> 0:2, n)...), vals in choices, target in targets
                    rhs = target_variable ? target : static_target
                    assignment = vcat(collect(x), variable_values ? vals : Int[],
                        target_variable ? [target] : Int[])
                    expected = op(count(v -> v in vals, x), rhs)
                    result = f(assignment)
                    @test isfinite(result) && result >= 0
                    @test iszero(result) == expected
                end
            end
            for except in (Int[], [0], [0, 1, 2])
                f = installed(CPE.XCSP3NValues(n; except, condition))
                for x in Iterators.product(ntuple(_ -> 0:2, n)...), target in targets
                    rhs = target_variable ? target : static_target
                    assignment = vcat(collect(x), target_variable ? [target] : Int[])
                    expected = op(length(Set(v for v in x if v ∉ except)), rhs)
                    result = f(assignment)
                    @test isfinite(result) && result >= 0
                    @test iszero(result) == expected
                end
            end
        end
    end

    for n in (1, 3), closed in (false, true), variable_values in (false, true)
        for occurrence_spec in (CPE.XCSP3Constants([1, 1]),
                CPE.XCSP3Constants([0:1, 1:3]), CPE.XCSP3Constants(Any[1, 0:2]),
                CPE.XCSP3Variables(2))
            value_spec = variable_values ? CPE.XCSP3Variables(2) : CPE.XCSP3Constants([0, 1])
            set = CPE.XCSP3Cardinality(n; values = value_spec, occurs = occurrence_spec, closed)
            f = installed(set)
            variable_occurs = occurrence_spec isa CPE.XCSP3Variables
            choices = variable_values ? ([0, 1], [1, 1], [2, 0]) : ([0, 1],)
            counts = variable_occurs ? ([0, 0], [1, 1], [2, 1], [-1, 1], [3, 3]) : (occurrence_spec.values,)
            for x in Iterators.product(ntuple(_ -> 0:2, n)...), vals in choices, occurs in counts
                expected = (!closed || all(v -> v in vals, x)) &&
                    all(eachindex(vals)) do j
                        c = count(==(vals[j]), x)
                        occurs[j] isa Number ? c == occurs[j] : c in occurs[j]
                    end
                if variable_values && variable_occurs
                    expected &= length(unique(vals)) == length(vals)
                end
                assignment = vcat(collect(x), variable_values ? vals : Int[],
                    variable_occurs ? occurs : Int[])
                result = f(assignment)
                @test isfinite(result) && result >= 0
                @test iszero(result) == expected
            end
        end
    end
    # The backend owns a copy, so caller mutation cannot silently change a model.
    set = CPE.XCSP3Count(1; values = CPE.XCSP3Constants([1]),
        condition = CPE.XCSP3Condition(:eq, 1))
    f = installed(set)
    set.values.values[1] = 2
    @test iszero(f([1]))
end

@testitem "XCSP3 cardinality defaults to open without changing explicit variants" tags=[:xcsp3, :moi] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import MathOptInterface as MOI
    import Test: @test

    default_set = CPE.XCSP3Cardinality(2;
        values = CPE.XCSP3Constants([0]), occurs = CPE.XCSP3Constants([1]))
    open_set = CPE.XCSP3Cardinality(2;
        values = CPE.XCSP3Constants([0]), occurs = CPE.XCSP3Constants([1]), closed = false)
    closed_set = CPE.XCSP3Cardinality(2;
        values = CPE.XCSP3Constants([0]), occurs = CPE.XCSP3Constants([1]), closed = true)
    @test default_set == open_set
    optimizer = CBLS.Optimizer()
    variables = MOI.add_variables(optimizer, 2)
    evaluators = map((default_set, open_set, closed_set)) do set
        ci = MOI.add_constraint(optimizer, MOI.VectorOfVariables(variables), set)
        CBLS.LS.get_constraint(optimizer.solver, ci.value).f
    end
    for x in ([0, 0], [0, 1], [1, 0], [1, 1])
        expected_open = count(==(0), x) == 1
        expected_closed = expected_open && all(==(0), x)
        @test iszero(evaluators[1](x)) == expected_open
        @test evaluators[1](x) == evaluators[2](x)
        @test iszero(evaluators[3](x)) == expected_closed
    end
end

@testitem "Legacy counting bindings preserve exceptions and operators" tags=[:xcsp3, :moi] default_imports=false begin
    import CBLS
    import JuMP
    import MathOptInterface as MOI
    import Test: @test
    for n in (1, 3), op in (==, !=, <, <=, >, >=), target in 0:3
        for vals in (Int[], [0], [0, 1], [1, 1])
            for kind in (:count, :nvalues)
                set = kind == :count ? CBLS.Count(; op, val = target, vals) :
                    CBLS.NValues(; op, val = target, vals)
                optimizer = CBLS.Optimizer()
                variables = MOI.add_variables(optimizer, n)
                index = MOI.add_constraint(optimizer, MOI.VectorOfVariables(variables),
                    JuMP.moi_set(set, n))
                f = CBLS.LS.get_constraint(optimizer.solver, index.value).f
                for x in Iterators.product(ntuple(_ -> 0:2, n)...)
                    statistic = kind == :count ? count(v -> v in vals, x) :
                        length(Set(v for v in x if v ∉ vals))
                    @test iszero(f(collect(x))) == op(statistic, target)
                end
            end
        end
    end
    for closed in (false, true), vals in ([0 1; 1 2], [0 0 1; 1 1 3])
        optimizer = CBLS.Optimizer()
        variables = MOI.add_variables(optimizer, 3)
        set = JuMP.moi_set(CBLS.Cardinality(; bool = closed, vals), 3)
        index = MOI.add_constraint(optimizer, MOI.VectorOfVariables(variables), set)
        f = CBLS.LS.get_constraint(optimizer.solver, index.value).f
        for x in Iterators.product(0:2, 0:2, 0:2)
            expected = (!closed || all(v -> v in vals[:, 1], x)) && all(1:2) do j
                occurs = count(==(vals[j, 1]), x)
                size(vals, 2) == 2 ? occurs == vals[j, 2] : vals[j, 2] <= occurs <= vals[j, 3]
            end
            @test iszero(f(collect(x))) == expected
        end
    end
end

@testitem "JuMP XCSP3 counting attachment and repeated variable roles" tags=[:xcsp3, :jump] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import MathOptInterface as MOI
    import JuMP
    import Test: @test

    model = JuMP.Model(CBLS.Optimizer)
    JuMP.@variable(model, x[1:3])
    JuMP.@variable(model, v[1:2])
    JuMP.@variable(model, o[1:2])
    JuMP.@variable(model, k)
    count = JuMP.@constraint(model, [x; v; k] in CPE.XCSP3Count(3;
        values = CPE.XCSP3Variables(2), condition = CPE.XCSP3Condition(:eq, CPE.XCSP3Variable())))
    distinct = JuMP.@constraint(model, [x; k] in CPE.XCSP3NValues(3;
        except = [0], condition = CPE.XCSP3Condition(:ge, CPE.XCSP3Variable())))
    cardinality = JuMP.@constraint(model, [x; v; o] in CPE.XCSP3Cardinality(3;
        values = CPE.XCSP3Variables(2), occurs = CPE.XCSP3Variables(2)))
    repeated = JuMP.@constraint(model, [x[1]; x[1]; k] in CPE.XCSP3Count(1;
        values = CPE.XCSP3Variables(1), condition = CPE.XCSP3Condition(:eq, CPE.XCSP3Variable())))
    # Force MOI.copy_to through the cache and bridges: construction alone would
    # leave unsupported functions undetected until optimize!.
    MOI.Utilities.attach_optimizer(JuMP.backend(model))
    @test MOI.Utilities.state(JuMP.backend(model)) == MOI.Utilities.ATTACHED_OPTIMIZER
    for constraint in (count, distinct, cardinality, repeated)
        @test JuMP.optimizer_index(constraint) isa MOI.ConstraintIndex
    end
    optimizer = JuMP.unsafe_backend(model)
    index = JuMP.optimizer_index(repeated)
    constraint = CBLS.LS.get_constraint(optimizer.solver, index.value)
    @test iszero(constraint.f([2, 2, 1]))
    @test !iszero(constraint.f([2, 2, 0]))
end
