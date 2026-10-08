module KeywordEvaluatorTests
using Test, CBLS, Constraints
import MathOptInterface as MOI
const LS=CBLS.LS

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
