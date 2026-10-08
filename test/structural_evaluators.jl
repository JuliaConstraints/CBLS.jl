module StructuralEvaluatorTests
using Test, CBLS, Constraints
import MathOptInterface as MOI
const LS=CBLS.LS
include("../perf/structural_scenarios.jl")
const Scenarios=StructuralScenarios

function evaluator(set)
    optimizer=CBLS.Optimizer()
    variables=MOI.add_variables(optimizer,4)
    MOI.add_constraint(optimizer,MOI.VectorOfVariables(variables),set)
    optimizer,LS.get_constraint(optimizer.backend_model,1).f
end
raw_evaluator(error)=error
raw_evaluator(error::LS.WorkspaceAdapter)=raw_evaluator(error.evaluator)

@testset "Structural adapters retain independent original truth" begin
    for specification in Scenarios.specifications()
        _,error=evaluator(specification.set)
        @test !Constraints.supports_incremental(error)
        for assignment in Iterators.product(ntuple(_->0:4,4)...)
            values=collect(assignment)
            @test error(values;X=nothing)==Float64(!specification.oracle(values))
        end
    end
    for operator in (==,!=,<,<=,>,>=),target in (0,2,3)
        _,error=evaluator(CBLS.MOICircuit(operator,target,4))
        for assignment in Iterators.product(ntuple(_->0:4,4)...)
            values=collect(assignment)
            @test error(values;X=nothing)==
                Float64(!Scenarios.circuit_truth(values,operator,target))
        end
    end
    for operator in (==,!=,<,<=,>,>=),target in (0,2,4),
            data in (Int[],[1,2,0,1],[2 1 0 1; 1 2 3 1])
        _,error=evaluator(CBLS.MOICumulative(operator,copy(data),target,4))
        for assignment in Iterators.product(ntuple(_->0:3,4)...)
            values=collect(assignment)
            @test error(values;X=nothing)==
                Float64(!Scenarios.cumulative_truth(values,data,operator,target))
        end
    end
    data=[0.5 1.5 0.0 0.5; 1.0 2.0 4.0 1.0]
    _,error=evaluator(CBLS.MOICumulative(<=,data,3.0,4))
    for assignment in Iterators.product(ntuple(_->(0.0,0.5,1.0),4)...)
        values=collect(assignment)
        @test error(values;X=nothing)==Float64(!Scenarios.cumulative_truth(values,data,<=,3.0))
    end
end

@testset "Structural keyword precedence and MOI-owned data" begin
    _,channel=evaluator(CBLS.MOIChannel(1,0,4))
    @test raw_evaluator(channel)([2,1,4,3];X=nothing,dim=7,id=1)==0.0
    _,circuit=evaluator(CBLS.MOICircuit(==,0,4))
    @test raw_evaluator(circuit)([2,3,4,1];X=nothing,op=!=,val=2)==0.0
    _,default_tasks=evaluator(CBLS.MOICumulative(<=,Int[],2,4))
    @test raw_evaluator(default_tasks)([0,0,0,0];X=nothing,pair_vars=[0,0,0,0])==0.0
    @test default_tasks([0,0,0,0];X=nothing)==1.0

    for specification in Scenarios.specifications()
        set=specification.set
        field=hasfield(typeof(set),:pair_vars) ? :pair_vars :
            hasfield(typeof(set),:language) ? :language : nothing
        isnothing(field) && continue
        data=getfield(set,field)
        data isa AbstractArray && isempty(data) && continue
        optimizer,error=evaluator(set)
        values=first(specification.inputs)
        expected=error(values;X=nothing)
        clone=deepcopy(optimizer.backend_model)
        copied=LS.get_constraint(clone,1).f
        @test copied(values;X=nothing)==expected
        if data isa AbstractVector{<:AbstractVector}
            foreach(v->fill!(v,9),data)
        elseif data isa AbstractArray
            fill!(data,9)
        elseif data.states isa AbstractVector
            foreach(empty!,data.states)
        else
            empty!(data.states)
        end
        @test error(values;X=nothing)==expected
        @test copied(values;X=nothing)==expected
    end
end
end
