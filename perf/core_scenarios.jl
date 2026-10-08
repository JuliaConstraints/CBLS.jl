module CoreScenarios
using CBLS, Constraints, LocalSearchSolvers, MetaStrategist, Random
import MathOptInterface as MOI
const LS = LocalSearchSolvers

options(steps=256) = LS.Options(dynamic=false, iteration=(false,steps), time_limit=Inf,
    process_threads_map=Dict(1=>1), print_level=:silent, log_mode=:silent,
    log_to_file=false, progress_mode=:none, use_progress_meter=false)

"A finite-domain CBLS model with an independent ring-sum and objective oracle."
function optimizer(n=32, steps=256)
    opt = CBLS.Optimizer(;options=options(steps))
    variables = MOI.add_variables(opt,n)
    for variable in variables
        MOI.add_constraint(opt,variable,CBLS.DiscreteSet(0:7))
    end
    for i in 1:n
        MOI.add_constraint(opt,MOI.VectorOfVariables(variables[[i,mod1(i+1,n)]]),
            CBLS.MOISum(<=,Int[],7,2))
    end
    f = CBLS.ScalarFunction(sum)
    MOI.set(opt,MOI.ObjectiveFunction{typeof(f)}(),f)
    MOI.set(opt,MOI.ObjectiveSense(),MOI.MIN_SENSE)
    opt
end
violation(values) = Float64(count(i->values[i]+values[mod1(i+1,length(values))]>7,eachindex(values)))
function valid_state(s)
    values=collect(LS.get_values(s))
    all(v->v in 0:7,values) && LS.get_error(s)==violation(values) &&
        (!LS.has_solution(s) || begin
            best=collect(LS.best_values(s))
            violation(best)==0 && LS.best_value(s)==sum(best)
        end)
end

function initialize_case(parameters)
    n=get(parameters,"variables",32)
    prepare=()->optimizer(n)
    operation=opt->begin
        Random.seed!(41)
        LS._init!(opt.solver)
        opt.solver
    end
    (;prepare,operation,verify=(opt,s)->valid_state(s))
end

function solve_case(parameters)
    n=get(parameters,"variables",32);steps=get(parameters,"steps",256)
    prepare=()->optimizer(n,steps)
    operation=opt->begin
        Random.seed!(41)
        MOI.optimize!(opt)
        opt.solver
    end
    (;prepare,operation,verify=(opt,s)->LS.iterations(s)==steps && valid_state(s))
end

"Two private typed units execute the same declared work behind an episode barrier."
function episode_case(parameters)
    n=get(parameters,"variables",32);steps=get(parameters,"steps",256)
    prepare=()->ntuple(2) do i
        opt=optimizer(n,steps)
        LS.prepare_unit(opt.solver;seed=41+i,builder=LS.execution_builder(mode=:typed))
    end
    operation=units->begin
        tasks=map(u->Threads.@spawn(LS.run_episode!(u;iterations=steps)),units)
        map(fetch,tasks)
    end
    verify=(units,results)->all(r->r.iterations==steps,results) &&
        all(u->valid_state(u.solver),units) &&
        units[1].solver.state.neighborhood!==units[2].solver.state.neighborhood
    cleanup=units->foreach(LS.release_unit!,units)
    (;prepare,operation,verify,cleanup)
end

"Accepted and rejected multi-variable candidates; rejected moves never mutate caches."
function meta_move_case(parameters)
    n=get(parameters,"variables",32);repetitions=get(parameters,"repetitions",1024)
    prepare=()->begin
        opt=optimizer(n);s=opt.solver;Random.seed!(41);LS._init!(s)
        for i in 1:n;LS._value!(s,i,0);end
        LS._compute!(s);LS._replace_pool!(s,LS.pool(s.state.configuration))
        scope=LS.MetaVariable(:block,1:8)
        good=LS.MetaMove(scope,fill(1,8));bad=LS.MetaMove(scope,fill(7,8))
        zero=LS.MetaMove(scope,zeros(Int,8))
        (;s,good,bad,zero)
    end
    operation=state->begin
        accepted=rejected=0
        for _ in 1:repetitions
            LS._candidate_cost(state.s,state.bad)>0 || error("expected rejected candidate")
            rejected+=1
            LS._candidate_cost(state.s,state.good)==0 || error("expected accepted candidate")
            affected=LS._commit!(state.s,state.good)
            LS._compute!(state.s;cons_lst=affected);accepted+=1
            affected=LS._commit!(state.s,state.zero)
            LS._compute!(state.s;cons_lst=affected)
        end
        (;accepted,rejected)
    end
    verify=(state,result)->result==(;accepted=repetitions,rejected=repetitions) &&
        all(iszero,LS.get_values(state.s)) && valid_state(state.s)
    (;prepare,operation,verify)
end
end

initialize_case(p)=CoreScenarios.initialize_case(p)
solve_case(p)=CoreScenarios.solve_case(p)
episode_case(p)=CoreScenarios.episode_case(p)
meta_move_case(p)=CoreScenarios.meta_move_case(p)
