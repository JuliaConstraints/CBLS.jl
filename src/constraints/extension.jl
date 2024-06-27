"""
    MOIExtension{T <: Number, V <: Union{Vector{Vector{T}}, Tuple{Vector{T}, Vector{T}}}} <: MOI.AbstractVectorSet

    DOCSTRING
"""
struct MOIExtension{
    T <: Number, V <: Union{Vector{Vector{T}}, Tuple{Vector{T}, Vector{T}}}} <:
       MOI.AbstractVectorSet
    pair_vars::V
    dimension::Int

    function MOIExtension(pair_vars, dim = 0)
        ET = eltype(first(typeof(pair_vars) <: Tuple ? first(pair_vars) : pair_vars))
        return new{ET, typeof(pair_vars)}(pair_vars, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIExtension{T, V}}) where {
        T <: Number, V <: Union{Vector{Vector{T}}, Tuple{Vector{T}, Vector{T}}}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIExtension)
    pair_vars = set.pair_vars
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:pair_vars => set.pair_vars))
        return error_f(USUAL_CONSTRAINTS[:extension])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    ET = eltype(first(typeof(pair_vars) <: Tuple ? first(pair_vars) : pair_vars))
    return CI{VOV, MOIExtension{ET, typeof(pair_vars)}}(cidx)
end

function Base.copy(set::MOIExtension)
    return MOIExtension(copy(set.pair_vars), copy(set.dimension))
end

"""
Global constraint enforcing that the tuple `x` matches a configuration within the supports set `pair_vars[1]` or does not match any configuration within the conflicts set `pair_vars[2]`. It embodies the logic: `x ∈ pair_vars[1] || x ∉ pair_vars[2]`, providing a comprehensive way to define valid (supported) and invalid (conflicted) tuples for constraint satisfaction problems. This constraint is versatile, allowing for the explicit delineation of both acceptable and unacceptable configurations.
"""
struct Extension{T <: Number, V <: Union{Vector{Vector{T}}, Tuple{Vector{T}, Vector{T}}}} <:
       JuMP.AbstractVectorSet
    pair_vars::V

    function Extension(pair_vars)
        ET = eltype(first(typeof(pair_vars) <: Tuple ? first(pair_vars) : pair_vars))
        return new{ET, typeof(pair_vars)}(pair_vars)
    end
end

Extension(; pair_vars) = Extension(pair_vars)

function JuMP.moi_set(set::Extension, dim::Int)
    return MOIExtension(set.pair_vars, dim)
end

"""
    MOISupports{T <: Number, V <: Vector{Vector{T}}} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOISupports{T <: Number, V <: Vector{Vector{T}}} <: MOI.AbstractVectorSet
    pair_vars::V
    dimension::Int

    function MOISupports(pair_vars, dim = 0)
        ET = eltype(first(pair_vars))
        return new{ET, typeof(pair_vars)}(pair_vars, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOISupports{T, V}}) where {
        T <: Number, V <: Vector{Vector{T}}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOISupports)
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:pair_vars => set.pair_vars))
        return error_f(USUAL_CONSTRAINTS[:supports])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    ET = eltype(first(set.pair_vars))
    return CI{VOV, MOISupports{ET, typeof(set.pair_vars)}}(cidx)
end

function Base.copy(set::MOISupports)
    return MOISupports(copy(set.pair_vars), copy(set.dimension))
end

"""
Global constraint ensuring that the tuple `x` matches a configuration listed within the support set `pair_vars`. This constraint is derived from the extension model, specifying that `x` must be one of the explicitly defined supported configurations: `x ∈ pair_vars`. It is utilized to directly declare the tuples that are valid and should be included in the solution space.

```julia
@constraint(model, X in Supports(; pair_vars))
```
"""
struct Supports{T <: Number, V <: Vector{Vector{T}}} <: JuMP.AbstractVectorSet
    pair_vars::V

    function Supports(; pair_vars)
        ET = eltype(first(pair_vars))
        return new{ET, typeof(pair_vars)}(pair_vars)
    end
end

function JuMP.moi_set(set::Supports, dim::Int)
    return MOISupports(set.pair_vars, dim)
end

"""
    MOIConflicts{T <: Number, V <: Vector{Vector{T}}} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIConflicts{T <: Number, V <: Vector{Vector{T}}} <:
       MOI.AbstractVectorSet
    pair_vars::V
    dimension::Int

    function MOIConflicts(pair_vars, dim = 0)
        ET = eltype(first(pair_vars))
        return new{ET, typeof(pair_vars)}(pair_vars, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIConflicts{T, V}}) where {
        T <: Number, V <: Vector{Vector{T}}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIConflicts)
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:pair_vars => set.pair_vars))
        return error_f(USUAL_CONSTRAINTS[:conflicts])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    ET = eltype(first(set.pair_vars))
    return CI{VOV, MOIConflicts{ET, typeof(set.pair_vars)}}(cidx)
end

function Base.copy(set::MOIConflicts)
    return MOIConflicts(copy(set.pair_vars), copy(set.dimension))
end

"""
Global constraint ensuring that the tuple `x` does not match any configuration listed within the conflict set `pair_vars`. This constraint, originating from the extension model, stipulates that `x` must avoid all configurations defined as conflicts: `x ∉ pair_vars`. It is useful for specifying tuples that are explicitly forbidden and should be excluded from the solution space.

```julia
@constraint(model, X in Conflicts(; pair_vars))
```
"""
struct Conflicts{T <: Number, V <: Vector{Vector{T}}} <: JuMP.AbstractVectorSet
    pair_vars::V

    function Conflicts(; pair_vars)
        ET = eltype(first(pair_vars))
        return new{ET, typeof(pair_vars)}(pair_vars)
    end
end

function JuMP.moi_set(set::Conflicts, dim::Int)
    return MOIConflicts(set.pair_vars, dim)
end

## SECTION - Test Items
@testitem "Extension" tags=[:usual, :constraints, :extension] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤5, Int)
    @variable(model, 1≤Y[1:5]≤5, Int)
    @variable(model, 1≤X_Supports[1:5]≤5, Int)
    @variable(model, 1≤X_Conflicts[1:5]≤5, Int)

    @constraint(model, X in Extension(; pair_vars = [[1, 2, 3, 4, 5]]))
    @constraint(model, Y in Extension(; pair_vars = [[1, 2, 1, 4, 5], [1, 2, 3, 5, 5]]))
    @constraint(model, X_Supports in Supports(; pair_vars = [[1, 2, 3, 4, 5]]))
    @constraint(model,
        X_Conflicts in Conflicts(; pair_vars = [[1, 2, 1, 4, 5], [1, 2, 3, 5, 5]]))

    optimize!(model)
    @info "Extension" value.(X) value.(Y) value.(X_Supports) value.(X_Conflicts)
    termination_status(model)
    @info solution_summary(model)
end
