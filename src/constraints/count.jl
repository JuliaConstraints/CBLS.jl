"""
    MOICount <: MOI.AbstractVectorSet

DOCSTRING
"""

struct MOICount{F <: Function, T1 <: Number, T2 <: Number} <: MOI.AbstractVectorSet
    op::F
    val::T1
    vals::Vector{T2}
    dimension::Int

    function MOICount(op, val, vals, dim = 0)
        new{typeof(op), typeof(val), eltype(vals)}(op, val, vals, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOICount{F, T1, T2}}) where {F <: Function, T1 <: Number, T2 <: Number}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOICount)
    s = if set.op == ==
        :exactly
    elseif set.op == ≥
        :at_least
    elseif set.op == ≤
        :at_most
    else
        :count
    end
    function e(x; kwargs...)
        d = Dict(:vals => set.vals, :val => set.val)
        s == :count && push!(d, :op => set.op)
        new_kwargs = merge(kwargs, d)
        return error_f(USUAL_CONSTRAINTS[s])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOICount{typeof(set.op), typeof(set.val), eltype(set.vals)}}(cidx)
end

function Base.copy(set::MOICount)
    return MOICount(
        copy(set.op), copy(set.val), copy(set.vals), copy(set.dimension))
end

"""
Global constraint ensuring that the number of occurrences of `val` in `X` is equal to `count`.

```julia
@constraint(model, X in Count(count, val, vals))
```
"""
struct Count{F <: Function, T1 <: Number, T2 <: Number} <: JuMP.AbstractVectorSet
    op::F
    val::T1
    vals::Vector{T2}

    function Count(op, val, vals)
        return new{typeof(op), typeof(val), eltype(vals)}(op, val, vals)
    end
end

function Count(;
        op::F, val::T1, vals::Vector{T2}) where {
        F <: Function, T1 <: Number, T2 <: Number}
    return Count(op, val, vals)
end

function JuMP.moi_set(set::Count, dim::Int)
    return MOICount(set.op, set.val, set.vals, dim)
end

"""
Constraint ensuring that the number of occurrences of the values in `vals` in `x` is at least `val`.

```julia
@constraint(model, X in AtLeast(val, vals))
```
"""
struct AtLeast{T1 <: Number, T2 <: Number} <: JuMP.AbstractVectorSet
    val::T1
    vals::Vector{T2}

    function AtLeast(val, vals)
        return new{typeof(val), eltype(vals)}(val, vals)
    end
end

function AtLeast(;
        val::T1, vals::Vector{T2}) where {T1 <: Number, T2 <: Number}
    return AtLeast(val, vals)
end

function JuMP.moi_set(set::AtLeast, dim::Int)
    return MOICount(≥, set.val, set.vals, dim)
end

"""
Constraint ensuring that the number of occurrences of the values in `vals` in `x` is at most `val`.

```julia
@constraint(model, X in AtMost(val, vals))
```
"""
struct AtMost{T1 <: Number, T2 <: Number} <: JuMP.AbstractVectorSet
    val::T1
    vals::Vector{T2}

    function AtMost(val, vals)
        return new{typeof(val), eltype(vals)}(val, vals)
    end
end

function AtMost(;
        val::T1, vals::Vector{T2}) where {T1 <: Number, T2 <: Number}
    return AtMost(val, vals)
end

function JuMP.moi_set(set::AtMost, dim::Int)
    return MOICount(≤, set.val, set.vals, dim)
end

"""
Constraint ensuring that the number of occurrences of the values in `vals` in `x` is exactly `val`.

```julia
@constraint(model, X in Exactly(val, vals))
```
"""
struct Exactly{T1 <: Number, T2 <: Number} <: JuMP.AbstractVectorSet
    val::T1
    vals::Vector{T2}

    function Exactly(val, vals)
        return new{typeof(val), eltype(vals)}(val, vals)
    end
end

function Exactly(;
        val::T1, vals::Vector{T2}) where {T1 <: Number, T2 <: Number}
    return Exactly(val, vals)
end

function JuMP.moi_set(set::Exactly, dim::Int)
    return MOICount(==, set.val, set.vals, dim)
end

## SECTION - Test Items
@testitem "Count" tags=[:usual, :constraints, :count] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:4]≤4, Int)
    @variable(model, 1≤X_at_least[1:4]≤4, Int)
    @variable(model, 1≤X_at_most[1:4]≤4, Int)
    @variable(model, 1≤X_exactly[1:4]≤4, Int)

    @constraint(model, X in Count(vals = [1, 2, 3, 4], op = ≥, val = 2))
    @constraint(model, X_at_least in AtLeast(vals = [1, 2, 3, 4], val = 2))
    @constraint(model, X_at_most in AtMost(vals = [1, 2], val = 1))
    @constraint(model, X_exactly in Exactly(vals = [1, 2], val = 2))

    optimize!(model)
    @info "Count" value.(X) value.(X_at_least) value.(X_at_most) value.(X_exactly)
    termination_status(model)
    @info solution_summary(model)
end
