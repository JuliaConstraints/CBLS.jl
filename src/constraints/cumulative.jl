"""
    MOICumulative{F <: Function, T1 <: Number, T2 <: Number} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOICumulative{F <: Function, T1 <: Number, T2 <: Number, V <: VecOrMat{T1}} <:
       MOI.AbstractVectorSet
    op::F
    pair_vars::V
    val::T2
    dimension::Int

    function MOICumulative(op, pair_vars, val, dim = 0)
        return new{typeof(op), eltype(pair_vars), typeof(val), typeof(pair_vars)}(
            op, pair_vars, val, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOICumulative{F, T1, T2, V}}) where {
        F <: Function, T1 <: Number, T2 <: Number, V <: VecOrMat{T1}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOICumulative)
    function e(x; kwargs...)
        d = Dict(:op => set.op, :val => set.val)
        !isempty(set.pair_vars) && push!(d, :pair_vars => set.pair_vars)
        new_kwargs = merge(kwargs, d)
        return error_f(USUAL_CONSTRAINTS[:cumulative])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV,
        MOICumulative{
            typeof(set.op), eltype(set.pair_vars), typeof(set.val), typeof(set.pair_vars)}}(cidx)
end

function Base.copy(set::MOICumulative)
    return MOICumulative(
        copy(set.op), copy(set.pair_vars), copy(set.val), copy(set.dimension))
end

"""
Global constraint ensuring that the cumulative sum of the heights of the tasks is less than or equal to `val`.

```julia
@constraint(model, X in Cumulative(; pair_vars, op, val))
```
"""
struct Cumulative{F <: Function, T1 <: Number, T2 <: Number, V <: VecOrMat{T1}} <:
       JuMP.AbstractVectorSet
    op::F
    pair_vars::V
    val::T2

    function Cumulative(op, pair_vars, val)
        return new{typeof(op), eltype(pair_vars), typeof(val), typeof(pair_vars)}(
            op, pair_vars, val)
    end
end

function Cumulative(; op::F = ≤, pair_vars::V = Vector{Number}(),
        val::T2) where {F <: Function, T1 <: Number, T2 <: Number, V <: VecOrMat{T1}}
    return Cumulative(op, pair_vars, val)
end

function JuMP.moi_set(set::Cumulative, dim::Int)
    return MOICumulative(set.op, set.pair_vars, set.val, dim)
end

## SECTION - Test Items
@testitem "Cumulative" tags=[:usual, :constraints, :cumulative] begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤5, Int)
    @variable(model, 1≤Y[1:5]≤5, Int)
    @variable(model, 1≤Z[1:5]≤5, Int)

    @constraint(model, X in Cumulative(; val = 1))
    @constraint(model,
        Y in Cumulative(; pair_vars = [3 2 5 4 2; 1 2 1 1 3], op = ≤, val = 5))
    @constraint(model,
        Z in Cumulative(; pair_vars = [3 2 5 4 2; 1 2 1 1 3], op = <, val = 5))

    optimize!(model)
    @info "Cumulative" value.(X) value.(Y) value.(Z)
    termination_status(model)
    @info solution_summary(model)
end
