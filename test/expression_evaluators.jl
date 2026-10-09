module ExpressionEvaluatorTests
using Test, CBLS
import ConstraintProgrammingExtensions as CPE
import MathOptInterface as MOI
const P = CPE.XCSP3Position
const E = CPE.XCSP3Expression
const LS = CBLS.LS

function registered(expression; variables = nothing)
    optimizer = CBLS.Optimizer()
    model_variables = MOI.add_variables(optimizer, 3)
    scope = isnothing(variables) ? model_variables : model_variables[variables]
    set = CPE.XCSP3Intension(length(scope); expression)
    index = MOI.add_constraint(optimizer, MOI.VectorOfVariables(scope), set)
    optimizer, index, set, LS.get_constraint(optimizer.backend_model, index.value).f
end
raw(evaluator) = evaluator
raw(evaluator::LS.WorkspaceAdapter) = raw(evaluator.evaluator)

@testset "Prepared expressions preserve each original operator" begin
    cases = (
        (E(:neg,P(1)), x -> -x[1]),
        (E(:abs,P(1)), x -> abs(x[1])),
        (E(:sqr,P(1)), x -> x[1]^2),
        (E(:add,P(1),P(2),P(3)), x -> x[1]+x[2]+x[3]),
        (E(:sub,P(1),P(2)), x -> x[1]-x[2]),
        (E(:mul,P(1),P(2),P(3)), x -> x[1]*x[2]*x[3]),
        (E(:div,P(1),E(:add,E(:abs,P(2)),1)), x -> div(x[1],abs(x[2])+1)),
        (E(:mod,P(1),E(:add,E(:abs,P(2)),1)), x -> rem(x[1],abs(x[2])+1)),
        (E(:pow,P(1),E(:abs,P(2))), x -> x[1]^abs(x[2])),
        (E(:min,P(1),P(2),P(3)), x -> min(x[1],x[2],x[3])),
        (E(:max,P(1),P(2),P(3)), x -> max(x[1],x[2],x[3])),
        (E(:dist,P(1),P(2)), x -> abs(x[1]-x[2])),
        (E(:set,P(1),P(2),P(3)), x -> (x[1],x[2],x[3])),
        (E(:eq,P(1),P(2),P(3)), x -> x[1]==x[2]==x[3]),
        (E(:ne,P(1),P(2)), x -> x[1]!=x[2]),
        (E(:lt,P(1),P(2)), x -> x[1]<x[2]),
        (E(:le,P(1),P(2)), x -> x[1]<=x[2]),
        (E(:gt,P(1),P(2)), x -> x[1]>x[2]),
        (E(:ge,P(1),P(2)), x -> x[1]>=x[2]),
        (E(:in,P(1),E(:set,P(2),P(3))), x -> x[1] in (x[2],x[3])),
        (E(:notin,P(1),E(:set,P(2),P(3))), x -> x[1] ∉ (x[2],x[3])),
        (E(:not,E(:eq,P(1),P(2))), x -> !(x[1]==x[2])),
        (E(:and,E(:eq,P(1),P(2)),E(:eq,P(2),P(3))), x -> x[1]==x[2] && x[2]==x[3]),
        (E(:or,E(:eq,P(1),P(2)),E(:eq,P(2),P(3))), x -> x[1]==x[2] || x[2]==x[3]),
        (E(:xor,E(:eq,P(1),P(2)),E(:eq,P(2),P(3)),E(:eq,P(1),P(3))),
            x -> isodd((x[1]==x[2])+(x[2]==x[3])+(x[1]==x[3]))),
        (E(:iff,E(:eq,P(1),P(2)),E(:eq,P(2),P(3))), x -> (x[1]==x[2])==(x[2]==x[3])),
        (E(:imp,E(:eq,P(1),P(2)),E(:eq,P(2),P(3))), x -> !(x[1]==x[2]) || x[2]==x[3]),
        (E(:if,E(:eq,P(1),P(2)),P(2),P(3)), x -> x[1]==x[2] ? x[2] : x[3]),
    )
    for (expression, oracle) in cases
        bound = CBLS._bind_core(expression)
        @test bound.operator === expression.operator
        for domain in (-2:2,(-1.0,0.0,1.0)), assignment in Iterators.product(domain,domain,domain)
            values = collect(assignment)
            @test isequal(CBLS._resolve_core(bound,values),oracle(values))
        end
    end
end

@testset "Registered intension truth, short circuits, and arithmetic errors" begin
    cases = (
        (E(:eq,E(:add,P(1),P(2)),P(3)), x -> x[1]+x[2]==x[3]),
        (E(:le,E(:add,E(:sqr,P(1)),E(:sqr,P(2))),E(:mul,2,P(3))), x -> x[1]^2+x[2]^2<=2x[3]),
        (E(:if,E(:eq,P(1),0),1,E(:eq,E(:div,P(2),P(1)),P(3))), x -> x[1]==0 || div(x[2],x[1])==x[3]),
        (E(:and,E(:ne,P(1),0),E(:eq,E(:mod,P(2),P(1)),P(3))), x -> x[1]!=0 && rem(x[2],x[1])==x[3]),
        (E(:or,E(:eq,P(1),0),E(:eq,E(:div,P(2),P(1)),P(3))), x -> x[1]==0 || div(x[2],x[1])==x[3]),
        (E(:imp,E(:ne,P(1),0),E(:eq,E(:div,P(2),P(1)),P(3))), x -> x[1]==0 || div(x[2],x[1])==x[3]),
    )
    for (expression, oracle) in cases
        optimizer, index, set, evaluator = registered(expression)
        @test MOI.get(optimizer,MOI.ConstraintSet(),index)==set
        workspace = fill(7.0,3,32)
        for domain in (-2:2,(-1.0,0.0,1.0)), assignment in Iterators.product(domain,domain,domain)
            values = collect(assignment)
            @test evaluator(values;X=workspace)==Float64(!oracle(values))
        end
        @test all(==(7.0),workspace)
        @test_throws DimensionMismatch evaluator([0,1])
        @test_throws DimensionMismatch evaluator([0,1,2,3])
    end
    for (expression, values) in (
            (E(:eq,E(:div,1,P(1)),0), [0,0,0]),
            (E(:eq,E(:mod,1,P(1)),0), [0,0,0]),
            (E(:eq,E(:pow,0,E(:neg,P(1))),0), [1,0,0]),
            (E(:and,P(1),true), [2,0,0]))
        _, _, _, evaluator = registered(expression)
        @test evaluator(values)==1.0
    end
    _, _, _, invalid_bool = registered(E(:and,P(1),true))
    @test_throws MethodError invalid_bool([:invalid,0,0])
    _, _, _, invalid_arithmetic = registered(E(:eq,E(:add,P(1),1),0))
    @test_throws MethodError invalid_arithmetic([:invalid,0,0])
    for expression in (P(1), E(:if,true,P(1),E(:div,1,0)),
            E(:if,false,E(:div,1,0),P(1)))
        _, _, _, evaluator = registered(expression)
        for value in (-1.0,-0.0,0.0,1.0,2.0,NaN,Inf)
            @test evaluator([value,0,0])==Float64(value!=1.0)
        end
    end
end

@testset "Expression arguments and repeated scopes remain owned" begin
    positions = [1,2]
    expression = E(:eq,E(:add,P(1),P(2)),P(3))
    optimizer, index, set, evaluator = registered(expression; variables=[1,1,2])
    @test LS.get_constraint(optimizer.backend_model,index.value).vars==[1,1,2]
    @test evaluator([2,2,4])==0.0
    @test evaluator([2,2,5])==1.0
    cloned = deepcopy(optimizer.backend_model)
    @test LS.get_constraint(cloned,index.value).f([2,2,4])==0.0
    copied = CBLS.Optimizer()
    mapping = MOI.copy_to(copied,optimizer)
    @test MOI.get(copied,MOI.ConstraintSet(),mapping[index])==set
    @test LS.get_constraint(copied.backend_model,mapping[index].value).vars==[1,1,2]
    @test LS.get_constraint(copied.backend_model,mapping[index].value).f([2,2,4])==0.0

    allowed = [1,2]
    optimizer, index, set, evaluator = registered(E(:in,P(1),CPE.XCSP3Constant(allowed)))
    @test evaluator([1,0,0])==0.0
    allowed[1]=9
    @test evaluator([1,0,0])==0.0 && evaluator([9,0,0])==1.0
    set.arguments.expression.arguments[2].value[1]=8
    @test evaluator([1,0,0])==0.0 && evaluator([8,0,0])==1.0
    cloned = deepcopy(optimizer.backend_model)
    cloned_evaluator = LS.get_constraint(cloned,index.value).f
    @test cloned_evaluator([1,0,0])==0.0
    @test raw(cloned_evaluator).arguments.expression.arguments[2].value !==
        raw(evaluator).arguments.expression.arguments[2].value
    copied = CBLS.Optimizer()
    mapping = MOI.copy_to(copied,optimizer)
    @test LS.get_constraint(copied.backend_model,mapping[index].value).f([1,0,0])==0.0

    array = [P(1),P(2)]
    bound_array = CBLS._bind_core(array)
    first_values, second_values = [1,2,3], [4,5,6]
    first_result = CBLS._resolve_core(bound_array,first_values)
    second_result = CBLS._resolve_core(bound_array,second_values)
    @test first_result==[1,2] && second_result==[4,5]
    @test first_result!==second_result && first_result!==first_values
    first_result[1]=9
    @test second_result==[4,5] && first_values==[1,2,3]
    array[1]=P(3)
    @test CBLS._resolve_core(bound_array,first_values)==[1,2]
    original = CPE.XCSP3Positions(positions)
    bound_expression = CBLS._bind_core(E(:in,P(3),original))
    @test bound_expression.operator==:in
    @test CBLS._resolve_core(bound_expression,[1,2,2])
    positions[1]=3
    @test CBLS._resolve_core(bound_expression,[1,2,1])
    if length(typeof(bound_expression).parameters)==2
        @test_throws MethodError CBLS.CoreExpression{:ne,typeof(bound_expression.arguments)}(:in,bound_expression.arguments)
    else
        @test bound_expression.operator==:in
    end
end
end
