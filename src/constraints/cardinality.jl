"""
    MOICardinality <: MOI.AbstractVectorSet

DOCSTRING
"""

struct MOICardinality{T <: Number, V <: VecOrMat{T}} <: MOI.AbstractVectorSet
    bool::Bool
    vals::V
    dimension::Int

    MOICardinality(bool, vals, dim = 0) = new{eltype(vals), typeof(vals)}(bool, vals, dim)
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOICardinality{T, V}}) where {T <: Number, V <: VecOrMat{T}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOICardinality)
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:bool => set.bool, :vals => set.vals))
        return error_f(USUAL_CONSTRAINTS[:cardinality])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOICardinality{eltype(set.vals), typeof(set.vals)}}(cidx)
end

function Base.copy(set::MOICardinality)
    return MOICardinality(copy(set.bool), copy(set.vals), copy(set.dimension))
end

"""
Global constraint ensuring that the number of occurrences of each value in `X` is equal to the corresponding value in `vals`.

```julia
@constraint(model, X in Cardinality(vals))
```
"""

struct Cardinality{T <: Number, V <: VecOrMat{T}} <: JuMP.AbstractVectorSet
    bool::Bool
    vals::V

    Cardinality(bool, vals) = new{eltype(vals), typeof(vals)}(bool, vals)
end

function Cardinality(; vals::VecOrMat{T}, bool::Bool = false) where {T <: Number}
    return Cardinality(bool, vals)
end

JuMP.moi_set(set::Cardinality, dim::Int) = MOICardinality(set.bool, set.vals, dim)

struct CardinalityOpen{T <: Number, V <: VecOrMat{T}} <: JuMP.AbstractVectorSet
    vals::V

    CardinalityOpen(vals) = new{eltype(vals), typeof(vals)}(vals)
end

function CardinalityOpen(; vals::VecOrMat{T}) where {T <: Number}
    return CardinalityOpen(vals)
end

JuMP.moi_set(set::CardinalityOpen, dim::Int) = MOICardinality(false, set.vals, dim)

struct CardinalityClosed{T <: Number, V <: VecOrMat{T}} <: JuMP.AbstractVectorSet
    vals::V

    CardinalityClosed(vals) = new{eltype(vals), typeof(vals)}(vals)
end

function CardinalityClosed(; vals::VecOrMat{T}) where {T <: Number}
    return CardinalityClosed(vals)
end

JuMP.moi_set(set::CardinalityClosed, dim::Int) = MOICardinality(true, set.vals, dim)

@testitem "Cardinality" tags=[:usual, :constraints, :cardinality] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:4]≤10, Int)
    @variable(model, 1≤Y[1:4]≤10, Int)
    @variable(model, 1≤Z[1:4]≤10, Int)

    @constraint(model, X in Cardinality(; vals = [2 0 1; 5 1 3; 10 2 3]))
    @constraint(model, Y in CardinalityOpen(; vals = [2 0 1; 5 1 3; 10 2 3]))
    @constraint(model, Z in CardinalityClosed(; vals = [2 0 1; 5 1 3; 10 2 3]))

    optimize!(model)
    @info "Cardinality" value.(X) value.(Y) value.(Z)
    termination_status(model)
    @info solution_summary(model)
end
