using JuMP

@testset "JuMP: constraints" begin
    m = Model(CBLS.Optimizer)

    err = _ -> 1.0
    concept = _ -> true

    @variable(m, 1 ≤ X[1:10] ≤ 4, Int)

    @constraint(m, X in Error(err))
    @constraint(m, X in Predicate(concept))

    @constraint(m, X in AllDifferent())
    @constraint(m, X in AllEqual())
    @constraint(m, X in AllEqualParam(2))
    @constraint(m, X in AlwaysTrue())
    @constraint(m, X[1:4] in DistDifferent())
    @constraint(m, X[1:2] in Eq())
    @constraint(m, X in Ordered())
    @constraint(m, X in SumEqualParam(22))

    optimize!(m)
end

@testset "JuMP: basic opt" begin
    model = Model(CBLS.Optimizer)

    set_optimizer_attribute(model, "iteration", 100)
    @test get_optimizer_attribute(model, "iteration") == 100
    set_time_limit_sec(model, 5.0)
    @test time_limit_sec(model) == 5.0

    @variable(model, 0 ≤ x ≤ 20, Int)
    @variable(model, y in DiscreteSet(0:20))

    @constraint(model, [x,y] in Predicate(v -> 6v[1] + 8v[2] >= 100 ))
    @constraint(model, [x,y] in Predicate(v -> 7v[1] + 12v[2] >= 120 ))

    objFunc = v -> 12v[1] + 20v[2]
    @objective(model, Min, ScalarFunction(objFunc))

    optimize!(model)

    @info "JuMP: basic opt" value(x) value(y) (12*value(x)+20*value(y)) solve_time(model) termination_status(model)
    # @info solution_summary(model)

end