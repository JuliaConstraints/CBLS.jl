@testitem "JuMP integer QAP objective result types" tags=[:moi, :core, :objective_results] default_imports=false begin
    import CBLS
    import JuMP
    import MathOptInterface as MOI
    import Test: @test, @test_throws

    # Both paths reach the real CBLS getter. Singleton integer assignments
    # make this a reporting regression rather than a convergence test.
    W = [0 2; 3 0]
    D = [0 5; 7 0]
    for direct in (false, true), subset in (false, true)
        opt = CBLS.Optimizer()
        model = direct ? JuMP.direct_model(opt) : JuMP.Model(() -> opt)
        JuMP.set_silent(model)
        JuMP.set_attribute(model, MOI.NumberOfThreads(), 1)
        JuMP.set_optimizer_attribute(model, "iteration", 2)
        JuMP.set_time_limit_sec(model, 2.0)
        JuMP.@variable(model, p[1:2], Int)
        JuMP.fix(p[1], 1)
        JuMP.fix(p[2], 2)
        calls = Ref(0)
        qap = values -> begin
            calls[] += 1
            sum(sum(W[values[i], values[j]] * D[i, j] for j in 1:2) for i in 1:2)
        end
        objective = subset ? CBLS.ScalarFunction(qap, p) : CBLS.ScalarFunction(qap)
        JuMP.set_objective_sense(model, MOI.MIN_SENSE)
        JuMP.set_objective_function(model, objective)
        @test_throws MOI.ResultIndexBoundsError MOI.get(opt, MOI.ObjectiveValue())
        JuMP.optimize!(model)
        @test JuMP.result_count(model) == 1
        @test JuMP.value.(p) == [1.0, 2.0]
        raw = CBLS._objective_value(opt.objective, CBLS.best_values(opt))
        @test raw isa Int64
        @test raw == 31
        before = calls[]
        @test MOI.get(opt, MOI.ObjectiveValue()) === 31.0
        @test calls[] == before + 1
        @test JuMP.objective_value(model) === 31.0
        summary = JuMP.solution_summary(model)
        @test summary.objective_value === 31.0
        @test occursin("objective_value", sprint(show, summary))
        @test_throws MOI.ResultIndexBoundsError JuMP.objective_value(model; result=2)
        @test CBLS._objective_value(opt.objective, CBLS.best_values(opt)) === raw
    end
end

@testitem "MOI reported objectives preserve native arithmetic and result lifecycle" tags=[:moi, :core, :objective_results] default_imports=false begin
    import CBLS
    import JuMP
    import MathOptInterface as MOI
    import Test: @test, @test_throws

    # Float64 is the reporting contract. In particular, a large integer is
    # rounded there without changing the callback's exact integer result.
    for direct in (false, true), score in (Int64(-7), Float32(1.5), -0.0, Int64(2)^53 + 1),
            sense in (MOI.MIN_SENSE, MOI.MAX_SENSE)
        opt = CBLS.Optimizer()
        model = direct ? JuMP.direct_model(opt) : JuMP.Model(() -> opt)
        JuMP.set_silent(model)
        JuMP.set_attribute(model, MOI.NumberOfThreads(), 1)
        JuMP.set_optimizer_attribute(model, "iteration", 2)
        JuMP.set_time_limit_sec(model, 2.0)
        JuMP.@variable(model, x, Int)
        JuMP.fix(x, 2)
        JuMP.set_objective_sense(model, sense)
        JuMP.set_objective_function(model, CBLS.ScalarFunction(_ -> score, [x]))
        JuMP.optimize!(model)
        @test JuMP.result_count(model) == 1
        @test CBLS._objective_value(opt.objective, CBLS.best_values(opt)) === score
        @test isequal(JuMP.objective_value(model), Float64(score))
        @test JuMP.objective_value(model) isa Float64
        @test JuMP.objective_sense(model) == sense
        @test_throws MOI.ResultIndexBoundsError JuMP.objective_value(model; result=2)
        JuMP.set_objective_sense(model, MOI.FEASIBILITY_SENSE)
        @test MOI.get(opt, MOI.ResultCount()) == 0
        @test_throws MOI.ResultIndexBoundsError MOI.get(opt, MOI.ObjectiveValue())
        JuMP.optimize!(model)
        @test JuMP.objective_value(model) === 0.0
        @test CBLS._objective_value(opt.objective, CBLS.best_values(opt)) === score
    end
end

@testitem "JuMP standard scalar objective replacement result types" tags=[:moi, :core, :objective_results] default_imports=false begin
    import CBLS
    import JuMP
    import MathOptInterface as MOI
    import Test: @test, @test_throws

    for direct in (false, true)
        opt = CBLS.Optimizer()
        model = direct ? JuMP.direct_model(opt) : JuMP.Model(() -> opt)
        JuMP.set_silent(model)
        JuMP.set_attribute(model, MOI.NumberOfThreads(), 1)
        JuMP.set_optimizer_attribute(model, "iteration", 2)
        JuMP.set_time_limit_sec(model, 2.0)
        JuMP.@variable(model, x, Int)
        JuMP.@variable(model, y, Int)
        JuMP.fix(x, 2)
        JuMP.fix(y, 3)
        for (objective, expected) in ((x, 2.0), (3y + 1, 10.0), (2x^2 + y, 11.0)),
                sense in (MOI.MIN_SENSE, MOI.MAX_SENSE)
            JuMP.set_objective_sense(model, sense)
            JuMP.set_objective_function(model, objective)
            @test MOI.get(opt, MOI.ResultCount()) == 0
            JuMP.optimize!(model)
            @test JuMP.result_count(model) == 1
            @test JuMP.objective_value(model) === expected
            @test CBLS._objective_value(opt.objective, CBLS.best_values(opt)) == expected
            @test JuMP.objective_sense(model) == sense
            @test_throws MOI.ResultIndexBoundsError JuMP.objective_value(model; result=2)
        end
    end
end
