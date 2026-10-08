module DistanceScenarios
using CBLS, LocalSearchSolvers, Random
import MathOptInterface as MOI
const LS=LocalSearchSolvers
truth(values)=abs(values[1]-values[2])!=abs(values[3]-values[4])

function evaluate_case(parameters)
    repetitions=get(parameters,"repetitions",1024)
    prepare=()->begin
        optimizer=CBLS.Optimizer();variables=MOI.add_variables(optimizer,4)
        MOI.add_constraint(optimizer,MOI.VectorOfVariables(variables),CBLS.MOIDistDifferent(4))
        (;evaluator=LS.get_constraint(optimizer.backend_model,1).f,
            inputs=([0,1,2,3],[0,1,1,3]),workspace=zeros(4,32))
    end
    operation=fixture->begin
        result=0.0
        for _ in 1:repetitions,values in fixture.inputs
            result+=fixture.evaluator(values;X=fixture.workspace)
        end
        result
    end
    verify=(fixture,result)->result==repetitions*sum(v->!truth(v),fixture.inputs)
    (;prepare,operation,verify)
end

function solve_case(parameters)
    steps=get(parameters,"steps",128);groups=8
    prepare=()->begin
        options=LS.Options(dynamic=false,iteration=(false,steps),time_limit=Inf,
            process_threads_map=Dict(1=>1),print_level=:silent,log_mode=:silent,
            log_to_file=false,progress_mode=:none,use_progress_meter=false)
        optimizer=CBLS.Optimizer(;options);variables=MOI.add_variables(optimizer,4groups)
        foreach(v->MOI.add_constraint(optimizer,v,CBLS.DiscreteSet(0:4)),variables)
        for group in 1:groups,_ in 1:4
            MOI.add_constraint(optimizer,MOI.VectorOfVariables(variables[(4group-3):4group]),
                CBLS.MOIDistDifferent(4))
        end
        objective=CBLS.ScalarFunction(sum)
        MOI.set(optimizer,MOI.ObjectiveFunction{typeof(objective)}(),objective)
        MOI.set(optimizer,MOI.ObjectiveSense(),MOI.MIN_SENSE)
        (;optimizer,strategy=deepcopy(optimizer.solver.strategies))
    end
    operation=fixture->begin
        fixture.optimizer.solver.strategies=deepcopy(fixture.strategy)
        Random.seed!(41);MOI.optimize!(fixture.optimizer);fixture.optimizer.solver
    end
    violation=values->4.0*count(group->!truth(@view(values[(4group-3):4group])),1:groups)
    verify=(fixture,solver)->begin
        values=collect(LS.get_values(solver))
        LS.iterations(solver)==steps && all(v->v in 0:4,values) &&
            LS.get_error(solver)==violation(values) &&
            (!LS.has_solution(solver) || begin
                best=collect(LS.best_values(solver))
                violation(best)==0 && LS.best_value(solver)==sum(best)
            end)
    end
    (;prepare,operation,verify)
end
end
distance_evaluate_case(p)=DistanceScenarios.evaluate_case(p)
distance_solve_case(p)=DistanceScenarios.solve_case(p)
