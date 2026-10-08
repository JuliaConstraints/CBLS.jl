module AdapterScenarios
using CBLS, LocalSearchSolvers, Random
import MathOptInterface as MOI
const LS=LocalSearchSolvers

function sets()
    (CBLS.MOIAllDifferent(Int[],4),CBLS.MOIAllEqual(+,Int[],nothing,4),
        CBLS.MOIOrdered(<=,Int[],4),CBLS.MOIElement(2,==,1,4),
        CBLS.MOIMinimum(>=,1,4),CBLS.MOIMaximum(<=,2,4))
end
truths(values)=(allunique(values),all(==(first(values)),values),
    all(i->values[i]<=values[i+1],1:3),values[2]==1,
    minimum(values)>=1,maximum(values)<=2)

function options(steps)
    LS.Options(dynamic=false,iteration=(false,steps),time_limit=Inf,
        process_threads_map=Dict(1=>1),print_level=:silent,log_mode=:silent,
        log_to_file=false,progress_mode=:none,use_progress_meter=false)
end
function optimizer(steps=128)
    opt=CBLS.Optimizer(;options=options(steps))
    variables=MOI.add_variables(opt,24)
    foreach(v->MOI.add_constraint(opt,v,CBLS.DiscreteSet(0:3)),variables)
    for (group,set) in enumerate(sets()), _ in 1:4
        ids=(4group-3):4group
        MOI.add_constraint(opt,MOI.VectorOfVariables(variables[ids]),set)
    end
    objective=CBLS.ScalarFunction(sum)
    MOI.set(opt,MOI.ObjectiveFunction{typeof(objective)}(),objective)
    MOI.set(opt,MOI.ObjectiveSense(),MOI.MIN_SENSE)
    opt
end
function violation(values)
    4.0*count(group->!truths(@view(values[(4group-3):4group]))[group],1:6)
end
function valid_state(solver)
    values=collect(LS.get_values(solver))
    all(v->v in 0:3,values) && LS.get_error(solver)==violation(values) &&
        (!LS.has_solution(solver) || begin
            best=collect(LS.best_values(solver))
            violation(best)==0 && LS.best_value(solver)==sum(best)
        end)
end

function evaluate_case(parameters)
    repetitions=get(parameters,"repetitions",1024)
    prepare=()->begin
        opt=CBLS.Optimizer()
        variables=MOI.add_variables(opt,4)
        foreach(set->MOI.add_constraint(opt,MOI.VectorOfVariables(variables),set),sets())
        evaluators=ntuple(i->LS.get_constraint(opt.backend_model,i).f,6)
        (;evaluators,inputs=([0,1,2,3],[1,1,2,3]),workspace=zeros(4,32))
    end
    operation=state->begin
        score=0.0
        for _ in 1:repetitions, values in state.inputs
            score+=foldl((total,evaluator)->total+evaluator(values;X=state.workspace),
                state.evaluators;init=0.0)
        end
        score
    end
    verify=(state,result)->result==repetitions*sum(v->count(!,truths(v)),state.inputs)
    (;prepare,operation,verify)
end

function solve_case(parameters)
    steps=get(parameters,"steps",128)
    prepare=()->begin
        opt=optimizer(steps)
        (;opt,strategy=deepcopy(opt.solver.strategies))
    end
    operation=state->begin
        state.opt.solver.strategies=deepcopy(state.strategy)
        Random.seed!(41);MOI.optimize!(state.opt);state.opt.solver
    end
    verify=(state,solver)->LS.iterations(solver)==steps && valid_state(solver)
    (;prepare,operation,verify)
end
end
adapter_evaluate_case(p)=AdapterScenarios.evaluate_case(p)
adapter_solve_case(p)=AdapterScenarios.solve_case(p)
