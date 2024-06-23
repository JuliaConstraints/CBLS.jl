"""
    MOINoOverlap{I <: Integer, T <: Number, V <: Vector{T}} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOINoOverlap{I <: Integer, T <: Number, V <: Vector{T}} <:
       MOI.AbstractVectorSet
    bool::Bool
    dim::I
    pair_vars::V
    dimension::Int

    function MOINoOverlap(bool, dim, pair_vars, moi_dim = 0)
        return new{typeof(dim), eltype(pair_vars), typeof(pair_vars)}(
            bool, dim, pair_vars, moi_dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOINoOverlap{I, T, V}}) where {
        I <: Integer, T <: Number, V <: Vector{T}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOINoOverlap)
    function e(x; kwargs...)
        d = if isempty(set.pair_vars)
            Dict(:dim => set.dim, :bool => set.bool)
        else
            Dict{Symbol, Any}(
                :dim => set.dim, :bool => set.bool, :pair_vars => set.pair_vars)
        end
        new_kwargs = merge(kwargs, d)
        return error_f(USUAL_CONSTRAINTS[:no_overlap])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{
        VOV, MOINoOverlap{typeof(set.dim), eltype(set.pair_vars), typeof(set.pair_vars)}}(cidx)
end

function Base.copy(set::MOINoOverlap)
    return MOINoOverlap(
        copy(set.bool), copy(set.dim), copy(set.pair_vars), copy(set.dimension))
end

"""
Global constraint ensuring that the tuple `x` does not overlap with any configuration listed within the pair set `pair_vars`. This constraint, originating from the extension model, stipulates that `x` must avoid all configurations defined as pairs: `x ∩ pair_vars = ∅`. It is useful for specifying tuples that are explicitly forbidden and should be excluded from the solution space.

```julia
@constraint(model, X in NoOverlap(; bool = true, dim = 1, pair_vars = nothing))
```
"""
struct NoOverlap{I <: Integer, T <: Number, V <: Vector{T}} <:
       JuMP.AbstractVectorSet
    bool::Bool
    dim::I
    pair_vars::V

    function NoOverlap(; bool = true, dim = 1, pair_vars = Vector{Number}())
        return new{typeof(dim), eltype(pair_vars), typeof(pair_vars)}(bool, dim, pair_vars)
    end
end

function JuMP.moi_set(set::NoOverlap, dim::Int)
    return MOINoOverlap(set.bool, set.dim, set.pair_vars, dim)
end

## SECTION - Test Items
@testitem "noOverlap" tags=[:usual, :constraints, :no_overlap] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤5, Int)
    @variable(model, 1≤Y[1:5]≤6, Int)
    @variable(model, 1≤Z[1:12]≤12, Int)

    @constraint(model, X in NoOverlap())
    @constraint(model, Y in NoOverlap(; pair_vars = [1, 1, 1, 1, 1]))
    @constraint(model,
        Z in NoOverlap(; pair_vars = [2, 4, 1, 4, 2, 3, 5, 1, 2, 3, 3, 2], dim = 3))

    optimize!(model)
    @info "NoOverlap" value.(X) value.(Y) value.(Z)
    termination_status(model)
    @info termination_status(model)
end
