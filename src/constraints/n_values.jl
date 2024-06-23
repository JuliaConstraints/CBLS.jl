"""
    MOINValues{F <: Function, T1 <: Number, T2 <: Number, V <: Vector{T2}} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOINValues{F <: Function, T1 <: Number, T2 <: Number, V <: Vector{T2}} <:
       MOI.AbstractVectorSet
    op::F
    val::T1
    vals::V
    dimension::Int

    function MOINValues(op, val, vals, dim = 0)
        return new{typeof(op), typeof(val), eltype(vals), typeof(vals)}(op, val, vals, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOINValues{F, T1, T2, V}}) where {
        F <: Function, T1 <: Number, T2 <: Number, V <: Vector{T2}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOINValues)
    vals = isempty(set.vals) ? nothing : set.vals
    function e(x; kwargs...)
        d = Dict(:op => set.op, :val => set.val)
        isnothing(vals) && (d[:vals] = vals)
        new_kwargs = merge(kwargs, d)
        return error_f(USUAL_CONSTRAINTS[:nvalues])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV,
        MOINValues{typeof(set.op), typeof(set.val), eltype(set.vals), typeof(set.vals)}}(cidx)
end

function Base.copy(set::MOINValues)
    return MOINValues(copy(set.op), copy(set.val), copy(set.vals), copy(set.dimension))
end

"""
Global constraint ensuring that the number of distinct values in `X` satisfies the given condition.
"""
struct NValues{F <: Function, T1 <: Number, T2 <: Number, V <: Vector{T2}} <:
       JuMP.AbstractVectorSet
    op::F
    val::T1
    vals::V

    function NValues(op, val, vals)
        return new{typeof(op), typeof(val), eltype(vals), typeof(vals)}(op, val, vals)
    end
end

function NValues(; op::F = ==,
        val::T1,
        vals::V = Vector{Number}()) where {
        F <: Function, T1 <: Number, T2 <: Number, V <: Vector{T2}}
    return NValues(op, val, vals)
end

function JuMP.moi_set(set::NValues, dim::Int)
    vals = isnothing(set.vals) ? Vector{Number}() : set.vals
    return MOINValues(set.op, set.val, vals, dim)
end

## SECTION - Test Items
@testitem "NValues" tags=[:usual, :constraints, :nvalues] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤5, Int)
    @variable(model, 1≤Y[1:5]≤5, Int)
    @variable(model, 1≤Z[1:5]≤5, Int)

    @constraint(model, X in NValues(; op = ==, val = 5))
    @constraint(model, Y in NValues(; op = ==, val = 2))
    @constraint(model, Z in NValues(; op = <=, val = 5, vals = [1, 2]))

    optimize!(model)
    @info "NValues" value.(X) value.(Y) value.(Z)
    termination_status(model)
    @info solution_summary(model)
end
