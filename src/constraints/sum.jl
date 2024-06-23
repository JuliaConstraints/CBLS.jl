"""
    MOISum{F <: Function, T1 <: Number, T2 <: Number, V <: Number} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOISum{F <: Function, T1 <: Number, T2 <: Number, V <: Vector{T1}} <:
       MOI.AbstractVectorSet
    op::F
    pair_vars::V
    val::T2
    dimension::Int

    function MOISum(op, pair_vars, val, dimension)
        return new{typeof(op), eltype(pair_vars), typeof(val), typeof(pair_vars)}(
            op, pair_vars, val, dimension)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOISum{F, T1, T2, V}}) where {F, T1, T2, V}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOISum)
    function e(x; kwargs...)
        d = if isempty(set.pair_vars)
            Dict(:op => set.op, :val => set.val)
        else
            Dict(:op => set.op, :pair_vars => set.pair_vars, :val => set.val)
        end
        new_kwargs = merge(kwargs, d)
        return error_f(USUAL_CONSTRAINTS[:sum])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV,
        MOISum{
            typeof(set.op), eltype(set.pair_vars), typeof(set.val), typeof(set.pair_vars)}}(cidx)
end

function Base.copy(set::MOISum)
    return MOISum(copy(set.op), copy(set.pair_vars), copy(set.val), copy(set.dimension))
end

"""
Global constraint ensuring that the sum of the variables in `x` satisfies a given condition.
"""
struct Sum{F <: Function, T1 <: Number, T2 <: Number, V <: Vector{T1}} <:
       JuMP.AbstractVectorSet
    op::F
    pair_vars::V
    val::T2

    function Sum(op, pair_vars, val)
        return new{typeof(op), eltype(pair_vars), typeof(val), typeof(pair_vars)}(
            op, pair_vars, val)
    end
end

function Sum(; op = ==, pair_vars = Vector{Number}(), val)
    return Sum(op, pair_vars, val)
end

function JuMP.moi_set(set::Sum, dim::Int)
    return MOISum(set.op, set.pair_vars, set.val, dim)
end

## SECTION - Test Items for Sum
@testitem "Sum" tags=[:usual, :constraints, :sum] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤5, Int)
    @variable(model, 1≤Y[1:5]≤5, Int)

    @constraint(model, X in Sum(; op = ==, val = 15))
    @constraint(model, Y in Sum(; op = <=, val = 10))

    optimize!(model)
    @info "Sum" value.(X) value.(Y)
    termination_status(model)
    @info solution_summary(model)
end
