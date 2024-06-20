"""
    MOIMinimum {F <: Function, T <: Number} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIMinimum{F <: Function, T <: Number} <: MOI.AbstractVectorSet
    op::F
    val::T
    dimension::Int

    function MOIMinimum(op, val, dim = 0)
        return new{typeof(op), typeof(val)}(op, val, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIMinimum{F, T}}) where {
        F <: Function, T <: Number}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIMinimum)
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:op => set.op, :val => set.val))
        return error_f(USUAL_CONSTRAINTS[:minimum])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIMinimum{typeof(set.op), typeof(set.val)}}(cidx)
end

function Base.copy(set::MOIMinimum)
    return MOIMinimum(copy(set.op), copy(set.val), copy(set.dimension))
end

"""
Global constraint ensuring that the minimum value in the tuple `x` satisfies the condition `op(x) val`. This constraint is useful for specifying that the minimum value in the tuple must satisfy a certain condition.

```julia
@constraint(model, X in Minimum(; op = ==, val))
```
"""
struct Minimum{F <: Function, T <: Number} <: JuMP.AbstractVectorSet
    op::F
    val::T

    function Minimum(op, val)
        return new{typeof(op), typeof(val)}(op, val)
    end
end

Minimum(; op::F = ==, val::T) where {F <: Function, T <: Number} = Minimum(op, val)

function JuMP.moi_set(set::Minimum, dim::Int)
    return MOIMinimum(set.op, set.val, dim)
end

## SECTION - Test Items
@testitem "Minimum" tags=[:usual, :constraints, :minimum] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤5, Int)

    @constraint(model, X in Minimum(; op = ==, val = 3))

    optimize!(model)
    @info "Minimum" value.(X)
    termination_status(model)
    @info solution_summary(model)
end
