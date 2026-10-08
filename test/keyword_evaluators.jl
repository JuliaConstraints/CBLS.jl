module KeywordEvaluatorTests
using Test, CBLS, Constraints
import MathOptInterface as MOI
const LS=CBLS.LS

function evaluator(set)
    optimizer=CBLS.Optimizer()
    variables=MOI.add_variables(optimizer,4)
    MOI.add_constraint(optimizer,MOI.VectorOfVariables(variables),set)
    optimizer,LS.get_constraint(optimizer.backend_model,1).f
end
function check_truth(set,oracle)
    _,error=evaluator(set)
    @test !Constraints.supports_incremental(error)
    for a in 0:3,b in 0:3,c in 0:3,d in 0:3
        values=[a,b,c,d]
        @test error(values;X=nothing)==Float64(!oracle(values))
    end
end
raw_evaluator(error)=error
raw_evaluator(error::LS.WorkspaceAdapter)=raw_evaluator(error.evaluator)

@testset "Fixed usual adapters retain independent original truth" begin
    for ignored in (Int[],[0])
        check_truth(CBLS.MOIAllDifferent(copy(ignored),4),
            values->allunique(filter(v->v ∉ ignored,values)))
    end
    for operator in (+,*),coefficients in (Int[],[1,0,-1,2]),target in (nothing,2)
        check_truth(CBLS.MOIAllEqual(operator,copy(coefficients),target,4),values->begin
            transformed=isempty(coefficients) ? values : operator.(values,coefficients)
            reference=isnothing(target) ? first(transformed) : target
            all(==(reference),transformed)
        end)
    end
    for operator in (<=,<,>=,>),offsets in (Int[],[0,1,-1,2])
        check_truth(CBLS.MOIOrdered(operator,copy(offsets),4),
            values->all(i->operator(values[i]+(isempty(offsets) ? 0 : offsets[i]),values[i+1]),1:3))
    end
    for operator in (==,!=,<,<=,>,>=),index in (0,2),target in (nothing,1)
        check_truth(CBLS.MOIElement(index,operator,target,4),values->begin
            selected=index==0 ? values[1] : index
            scope=index==0 ? values[2:end] : values
            reference=isnothing(target) ? last(scope) : target
            candidates=isnothing(target) ? scope[1:end-1] : scope
            1<=selected<=length(candidates) && operator(candidates[selected],reference)
        end)
    end
    for operator in (==,!=,<,<=,>,>=),target in (0,2)
        check_truth(CBLS.MOIMinimum(operator,target,4),values->operator(minimum(values),target))
        check_truth(CBLS.MOIMaximum(operator,target,4),values->operator(maximum(values),target))
    end
end

@testset "Array keywords remain owned after MOI registration and model cloning" begin
    for (set,field,values,replacement) in (
            (CBLS.MOIAllDifferent([0],4),:vals,[0,0,1,2],2),
            (CBLS.MOIAllEqual(+,[1,2,3,4],5,4),:pair_vars,[4,3,2,1],0),
            (CBLS.MOIOrdered(<=,[1,1,1,1],4),:pair_vars,[0,1,2,3],7))
        optimizer,error=evaluator(set)
        @test error(values;X=nothing)==0.0
        getfield(set,field).=replacement
        @test error(values;X=nothing)==0.0
        clone=deepcopy(optimizer.backend_model)
        copied=LS.get_constraint(clone,1).f
        @test copied(values;X=nothing)==error(values;X=nothing)
        @test getfield(raw_evaluator(copied).parameters,field)!==
            getfield(raw_evaluator(error).parameters,field)
    end
end

@testset "Fixed sum keywords retain full evaluation and original truth" begin
    for operator in (==,!=,<,<=,>,>=), coefficients in (Int[],[2,-1,3]), target in (0,3,7)
        opt=CBLS.Optimizer()
        variables=MOI.add_variables(opt,3)
        set=CBLS.MOISum(operator,copy(coefficients),target,3)
        MOI.add_constraint(opt,MOI.VectorOfVariables(variables),set)
        evaluator=LS.get_constraint(opt.backend_model,1).f
        @test !Constraints.supports_incremental(evaluator)
        for a in 0:3,b in 0:3,c in 0:3
            values=[a,b,c]
            total=isempty(coefficients) ? sum(values) : sum(coefficients .* values)
            @test evaluator(values;X=nothing)==Float64(!operator(total,target))
        end
        if !isempty(set.pair_vars)
            set.pair_vars .= 0
            @test evaluator([1,2,3];X=nothing)==Float64(!operator(9,target))
            clone=deepcopy(opt.backend_model)
            @test LS.get_constraint(clone,1).f([1,2,3];X=nothing)==evaluator([1,2,3];X=nothing)
        end
    end
end

@testset "Caller workspace and fixed keyword precedence" begin
    workspace=zeros(3,4)
    callback=(values;X=nothing,val=0,extra=nothing)->(;values,X,val,extra)
    evaluator=CBLS.FixedKeywordError(callback,(;val=7))
    result=evaluator([1,2];X=workspace,val=99,extra=:forwarded)
    @test result.X===workspace
    @test result.val==7 && result.extra==:forwarded
end
end
