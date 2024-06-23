"""
    MOIMaximum {F <: Function, T <: Number} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIMaximum{F <: Function, T <: Number} <: MOI.AbstractVectorSet
    op::F
    val::T
    dimension::Int

    function MOIMaximum(op, val, dim = 0)
        return new{typeof(op), typeof(val)}(op, val, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIMaximum{F, T}}) where {
        F <: Function, T <: Number}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIMaximum)
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:op => set.op, :val => set.val))
        return error_f(USUAL_CONSTRAINTS[:maximum])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIMaximum{typeof(set.op), typeof(set.val)}}(cidx)
end

function Base.copy(set::MOIMaximum)
    return MOIMaximum(copy(set.op), copy(set.val), copy(set.dimension))
end

"""
Global constraint ensuring that the maximum value in the tuple `x` satisfies the condition `op(x) val`. This constraint is useful for specifying that the maximum value in the tuple must satisfy a certain condition.

```julia
@constraint(model, X in Maximum(; op = ==, val))
```
"""
struct Maximum{F <: Function, T <: Number} <: JuMP.AbstractVectorSet
    op::F
    val::T

    function Maximum(op, val)
        return new{typeof(op), typeof(val)}(op, val)
    end
end

Maximum(; op::F = ==, val::T) where {F <: Function, T <: Number} = Maximum(op, val)

function JuMP.moi_set(set::Maximum, dim::Int)
    return MOIMaximum(set.op, set.val, dim)
end

## SECTION - Test Items
@testitem "Maximum" tags=[:usual, :constraints, :maximum] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤5, Int)

    @constraint(model, X in Maximum(; op = ==, val = 5))

    optimize!(model)
    @info "Maximum" value.(X)
    termination_status(model)
    @info solution_summary(model)
end
