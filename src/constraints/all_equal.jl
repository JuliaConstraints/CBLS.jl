"""
    MOIAllEqual <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAllEqual{F <: Function, T1 <: Number, T2 <: Union{Nothing, Number}} <:
       MOI.AbstractVectorSet
    op::F
    pair_vars::Vector{T1}
    val::T2
    dimension::Int

    function MOIAllEqual(op, pair_vars, val, dim = 0)
        return new{typeof(op), eltype(pair_vars), typeof(val)}(op, pair_vars, val, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIAllEqual{F, T1, T2}}) where {
        F <: Function, T1 <: Number, T2 <: Union{Nothing, Number}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIAllEqual)
    function e(x; kwargs...)
        new_kwargs = merge(
            kwargs, Dict(:op => set.op, :pair_vars => set.pair_vars, :val => set.val))
        return error_f(USUAL_CONSTRAINTS[:all_equal])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAllEqual{typeof(set.op), eltype(set.pair_vars), typeof(set.val)}}(cidx)
end

function Base.copy(set::MOIAllEqual)
    return MOIAllEqual(
        copy(set.op), copy(set.pair_vars), copy(set.val), copy(set.dimension))
end

"""
Global constraint ensuring that all the values of `X` are all equal.

```julia
@constraint(model, X in AllEqual())
```
"""
struct AllEqual{F <: Function, T1 <: Number, T2 <: Union{Nothing, Number}} <:
       JuMP.AbstractVectorSet
    op::F
    pair_vars::Vector{T1}
    val::T2

    function AllEqual(op, pair_vars, val)
        return new{typeof(op), eltype(pair_vars), typeof(val)}(op, pair_vars, val)
    end
end

function AllEqual(; op::F = +, pair_vars::Vector{T1} = Vector{Number}(),
        val::T2 = nothing) where {F <: Function, T1 <: Number, T2 <: Union{Nothing, Number}}
    return AllEqual(op, pair_vars, val)
end

JuMP.moi_set(set::AllEqual, dim::Int) = MOIAllEqual(set.op, set.pair_vars, set.val, dim)

@testitem "All Equal" tags=[:usual, :constraints, :all_equal] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 0≤X1[1:4]≤4, Int)
    @variable(model, 0≤X2[1:4]≤4, Int)
    @variable(model, 0≤X3[1:4]≤4, Int)
    @variable(model, 0≤X4[1:4]≤4, Int)

    @constraint(model, X1 in AllEqual())
    @constraint(model, X2 in AllEqual(; pair_vars = [0, 1, 2, 3]))
    @constraint(model, X3 in AllEqual(; op = /, val = 1, pair_vars = [1, 2, 3, 4]))
    @constraint(model, X4 in AllEqual(; op = *, val = 1, pair_vars = [1, 2, 3, 4]))

    optimize!(model)
    @info "All Equal" value.(X1) value.(X2) value.(X3) value.(X4)
    termination_status(model)
    @info solution_summary(model)
end
