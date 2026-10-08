module StructuralScenarios
using CBLS, LocalSearchSolvers, Random
import MathOptInterface as MOI
const LS=LocalSearchSolvers
const CC=CBLS.ConstraintCommons

function channel_truth(values,dimension,index)
    index != 0 && return 1<=index<=length(values) &&
        count(!iszero,values)==1 && values[index]==1
    if dimension==1
        return all(i->1<=values[i]<=length(values) && values[values[i]]==i,
            eachindex(values))
    elseif dimension==2 && iseven(length(values))
        n=length(values)÷2
        return all(i->1<=values[i]<=n && values[n+values[i]]==i,1:n) &&
            all(i->1<=values[n+i]<=n && values[values[n+i]]==i,1:n)
    end
    false
end

function circuit_truth(values,operator,target)
    n=length(values)
    all(v->1<=v<=n,values) || return false
    active=Set(i for i in eachindex(values) if values[i]!=i)
    length(active)>=2 || return false
    start=first(active);visited=Set{Int}();current=start
    while current ∉ visited
        current in active || return false
        push!(visited,current);current=values[current]
    end
    current==start && visited==active && operator(length(active),target==0 ? n : target)
end

function cumulative_truth(origins,data,operator,target)
    lengths=isempty(data) ? ones(length(origins)) :
        data isa AbstractMatrix ? collect(data[1,:]) : data
    heights=isempty(data) ? ones(length(origins)) :
        data isa AbstractMatrix ? collect(data[2,:]) : data
    operator(0,target) || return false
    endpoints=sort!(unique(vcat(origins,origins.+lengths)))
    all(t->operator(sum((heights[i] for i in eachindex(origins)
        if origins[i]<=t<origins[i]+lengths[i]);init=0),target),endpoints)
end

function parity_language()
    CC.Automaton(Dict((:even,0)=>:even,(:even,1)=>:odd,
        (:odd,0)=>:odd,(:odd,1)=>:even),:even,:even)
end
function table_language()
    CC.MDD([Dict((:root,0)=>:a,(:root,1)=>:b,(:root,2)=>:c),
        Dict((:a,2)=>:d,(:b,2)=>:d,(:c,0)=>:e),
        Dict((:d,0)=>:last,(:e,0)=>:last),Dict((:last,1)=>:terminal)])
end

function specifications()
    tables=[[0,1,2,3],[1,1,2,3]]
    durations=[1,2,0,1];task_data=[2 1 0 1; 1 2 3 1]
    (
        (;set=CBLS.MOIChannel(1,0,4),inputs=([2,1,4,3],[2,3,1,4]),
            oracle=v->channel_truth(v,1,0)),
        (;set=CBLS.MOIChannel(2,0,4),inputs=([2,1,2,1],[1,2,2,1]),
            oracle=v->channel_truth(v,2,0)),
        (;set=CBLS.MOIChannel(1,2,4),inputs=([0,1,0,0],[0,1,1,0]),
            oracle=v->channel_truth(v,1,2)),
        (;set=CBLS.MOICircuit(>=,0,4),inputs=([2,3,4,1],[2,1,4,3]),
            oracle=v->circuit_truth(v,>=,0)),
        (;set=CBLS.MOICircuit(==,3,4),inputs=([2,3,1,4],[2,3,4,1]),
            oracle=v->circuit_truth(v,==,3)),
        (;set=CBLS.MOICumulative(<=,Int[],2,4),inputs=([0,1,2,3],[0,0,0,0]),
            oracle=v->cumulative_truth(v,Int[],<=,2)),
        (;set=CBLS.MOICumulative(<=,copy(durations),2,4),
            inputs=([0,1,2,3],[0,0,0,0]),oracle=v->cumulative_truth(v,durations,<=,2)),
        (;set=CBLS.MOICumulative(<=,copy(task_data),3,4),
            inputs=([0,1,2,3],[0,0,0,0]),oracle=v->cumulative_truth(v,task_data,<=,3)),
        (;set=CBLS.MOIInstantiation([0,1,2,3],4),inputs=([0,1,2,3],[1,1,2,3]),
            oracle=v->v==[0,1,2,3]),
        (;set=CBLS.MOIExtension(deepcopy(tables),4),inputs=([0,1,2,3],[3,2,1,0]),
            oracle=v->v in tables),
        (;set=CBLS.MOISupports(deepcopy(tables),4),inputs=([0,1,2,3],[3,2,1,0]),
            oracle=v->v in tables),
        (;set=CBLS.MOIConflicts(deepcopy(tables),4),inputs=([3,2,1,0],[0,1,2,3]),
            oracle=v->v ∉ tables),
        (;set=CBLS.MOIRegular(parity_language(),4),inputs=([1,0,1,0],[1,0,0,0]),
            oracle=v->all(x->x in (0,1),v) && iseven(count(==(1),v))),
        (;set=CBLS.MOIMultivaluedDecisionDiagram(table_language(),4),
            inputs=([0,2,0,1],[0,1,0,1]),
            oracle=v->Tuple(v) in ((0,2,0,1),(1,2,0,1),(2,0,0,1))))
end

function evaluate_case(parameters)
    repetitions=get(parameters,"repetitions",1024)
    prepare=()->map(specifications()) do specification
        optimizer=CBLS.Optimizer()
        variables=MOI.add_variables(optimizer,4)
        MOI.add_constraint(optimizer,MOI.VectorOfVariables(variables),specification.set)
        (;evaluator=LS.get_constraint(optimizer.backend_model,1).f,
            specification.inputs,expected=sum(v->!specification.oracle(v),specification.inputs),
            workspace=zeros(4,32))
    end
    operation=fixture->begin
        score=0.0
        for _ in 1:repetitions
            score+=sum(map(pair_score,fixture))
        end
        score
    end
    verify=(fixture,result)->result==repetitions*sum(s->s.expected,fixture)
    (;prepare,operation,verify)
end

pair_score(state)=state.evaluator(state.inputs[1];X=state.workspace)+
    state.evaluator(state.inputs[2];X=state.workspace)

function solve_case(parameters)
    steps=get(parameters,"steps",128)
    specifications_=specifications()
    prepare=()->begin
        options=LS.Options(dynamic=false,iteration=(false,steps),time_limit=Inf,
            process_threads_map=Dict(1=>1),print_level=:silent,log_mode=:silent,
            log_to_file=false,progress_mode=:none,use_progress_meter=false)
        optimizer=CBLS.Optimizer(;options)
        variables=MOI.add_variables(optimizer,4length(specifications_))
        foreach(v->MOI.add_constraint(optimizer,v,CBLS.DiscreteSet(0:4)),variables)
        for (group,specification) in enumerate(specifications_), _ in 1:4
            MOI.add_constraint(optimizer,MOI.VectorOfVariables(variables[(4group-3):4group]),
                specification.set)
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
    violation=values->4.0*sum(!specification.oracle(@view(values[(4group-3):4group]))
        for (group,specification) in enumerate(specifications_))
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
structural_evaluate_case(p)=StructuralScenarios.evaluate_case(p)
structural_solve_case(p)=StructuralScenarios.solve_case(p)
