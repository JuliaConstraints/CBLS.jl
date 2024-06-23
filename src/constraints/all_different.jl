"""
    MOIAllDifferent <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAllDifferent{T <: Number} <: MOI.AbstractVectorSet
    vals::Vector{T}
    dimension::Int

    MOIAllDifferent(vals, dim = 0) = new{eltype(vals)}(vals, dim)
end

function MOI.supports_constraint(
        ::Optimizer, ::Type{VOV}, ::Type{MOIAllDifferent{T}}) where {T <: Number}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIAllDifferent)
    vals = isempty(set.vals) ? nothing : set.vals
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:vals => vals))
        return error_f(USUAL_CONSTRAINTS[:all_different])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAllDifferent{eltype(set.vals)}}(cidx)
end

Base.copy(set::MOIAllDifferent) = MOIAllDifferent(copy(set.vals), copy(set.dimension))

"""
Global constraint ensuring that all the values of a given configuration are unique.

```julia
@constraint(model, X in AllDifferent())
```
"""
struct AllDifferent{T <: Number} <: JuMP.AbstractVectorSet
    vals::Vector{T}

    AllDifferent(vals) = new{eltype(vals)}(vals)
end

AllDifferent(; vals::Vector{T} = Vector{Number}()) where {T <: Number} = AllDifferent(vals)

JuMP.moi_set(set::AllDifferent, dim::Int) = MOIAllDifferent(set.vals, dim)

## SECTION - Test Items
@testitem "All Different" tags=[:usual, :constraints, :all_different] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:4]≤4, Int)
    @variable(model, 0≤Y[1:4]≤2, Int)

    @constraint(model, X in AllDifferent())
    @constraint(model, Y in AllDifferent(; vals = [0]))

    optimize!(model)
    @info "All Different" value.(X) value.(Y)
    termination_status(model)
    @info solution_summary(model)
end
