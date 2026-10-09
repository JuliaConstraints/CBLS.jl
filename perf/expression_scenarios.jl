module ExpressionScenarios
using CBLS, LocalSearchSolvers, Random
import MathOptInterface as MOI
import ConstraintProgrammingExtensions as CPE
const LS = LocalSearchSolvers
const P = CPE.XCSP3Position
const E = CPE.XCSP3Expression

function expression_case(index)
    index == 1 && return E(:eq, E(:add, P(1), P(2)), P(3))
    index == 2 && return E(:le, E(:add, E(:sqr, P(1)), E(:sqr, P(2))), E(:mul, 2, P(3)))
    index == 3 && return E(:if, E(:eq, P(1), 0), 1, E(:eq, E(:div, P(2), P(1)), P(3)))
    index == 4 && return E(:and, E(:ne, P(1), 0), E(:eq, E(:mod, P(2), P(1)), P(3)))
    index == 5 && return E(:imp, E(:eq, P(1), 0), E(:gt, E(:add, P(2), P(3)), 0))
    throw(ArgumentError("expression case $index"))
end
function truth(index, values)
    a, b, c = values
    index == 1 && return a + b == c
    index == 2 && return a^2 + b^2 <= 2c
    index == 3 && return a == 0 || div(b, a) == c
    index == 4 && return a != 0 && rem(b, a) == c
    index == 5 && return a != 0 || b + c > 0
    throw(ArgumentError("expression case $index"))
end

function evaluate_case(parameters)
    index = get(parameters, "expression", 1)
    repetitions = get(parameters, "repetitions", 2048)
    prepare = () -> begin
        optimizer = CBLS.Optimizer()
        variables = MOI.add_variables(optimizer, 3)
        MOI.add_constraint(optimizer, MOI.VectorOfVariables(variables),
            CPE.XCSP3Intension(3; expression = expression_case(index)))
        (; evaluator = LS.get_constraint(optimizer.backend_model, 1).f,
            inputs = ([0,1,2], [1,2,3], [2,3,4]), workspace = zeros(3,32))
    end
    operation = fixture -> begin
        score = 0.0
        for _ in 1:repetitions, values in fixture.inputs
            score += fixture.evaluator(values; X = fixture.workspace)
        end
        score
    end
    verify = (fixture, result) ->
        result == repetitions * count(values -> !truth(index, values), fixture.inputs)
    (; prepare, operation, verify)
end

function solve_case(parameters)
    steps = get(parameters, "steps", 128)
    groups = 8
    prepare = () -> begin
        options = LS.Options(dynamic = false, iteration = (false,steps), time_limit = Inf,
            process_threads_map = Dict(1=>1), print_level = :silent, log_mode = :silent,
            log_to_file = false, progress_mode = :none, use_progress_meter = false)
        optimizer = CBLS.Optimizer(; options)
        variables = MOI.add_variables(optimizer, 3groups)
        foreach(v -> MOI.add_constraint(optimizer, v, CBLS.DiscreteSet(0:4)), variables)
        for group in 1:groups, index in 1:5
            MOI.add_constraint(optimizer, MOI.VectorOfVariables(variables[(3group-2):3group]),
                CPE.XCSP3Intension(3; expression = expression_case(index)))
        end
        objective = CBLS.ScalarFunction(sum)
        MOI.set(optimizer, MOI.ObjectiveFunction{typeof(objective)}(), objective)
        MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
        (; optimizer, strategy = deepcopy(optimizer.solver.strategies))
    end
    operation = fixture -> begin
        fixture.optimizer.solver.strategies = deepcopy(fixture.strategy)
        Random.seed!(41)
        MOI.optimize!(fixture.optimizer)
        fixture.optimizer.solver
    end
    violation = values -> sum(!truth(index, @view(values[(3group-2):3group]))
        for group in 1:groups, index in 1:5)
    verify = (fixture, solver) -> begin
        values = collect(LS.get_values(solver))
        LS.iterations(solver) == steps && all(v -> v in 0:4, values) &&
            LS.get_error(solver) == violation(values) &&
            (!LS.has_solution(solver) || begin
                best = collect(LS.best_values(solver))
                violation(best) == 0 && LS.best_value(solver) == sum(best)
            end)
    end
    (; prepare, operation, verify)
end
end
expression_evaluate_case(parameters) = ExpressionScenarios.evaluate_case(parameters)
expression_solve_case(parameters) = ExpressionScenarios.solve_case(parameters)
