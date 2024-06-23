"""
    MOIChannel <: MOI.AbstractVectorSet

DOCSTRING
"""

struct MOIChannel{D <: Integer, I <: Integer} <: MOI.AbstractVectorSet
    dim::D
    id::I
    dimension::Int

    function MOIChannel(dim, id, dim_moi = 0)
        return new{typeof(dim), typeof(id)}(dim, id, dim_moi)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIChannel{D, I}}) where {D <: Integer, I <: Integer}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIChannel)
    id = iszero(set.id) ? nothing : set.id
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:dim => set.dim, :id => id))
        return error_f(USUAL_CONSTRAINTS[:channel])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIChannel{typeof(set.dim), typeof(set.id)}}(cidx)
end

function Base.copy(set::MOIChannel)
    return MOIChannel(copy(set.dim), copy(set.id), copy(set.dimension))
end

"""
Global constraint ensuring that the values of `X` are a channel.

```julia
@constraint(model, X in Channel())
```
"""

struct Channel{D <: Integer, I <: Integer} <: JuMP.AbstractVectorSet
    dim::D
    id::I

    function Channel(dim, id)
        return new{typeof(dim), typeof(id)}(dim, id)
    end
end

function Channel(; dim::D = 1, id::I = 0) where {D <: Integer, I <: Integer}
    return Channel(dim, id)
end

JuMP.moi_set(set::Channel, dim_moi::Int) = MOIChannel(set.dim, set.id, dim_moi)

@testitem "Channel" tags=[:usual, :constraints, :channel] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:4]≤4, Int)
    @variable(model, 1≤Y[1:10]≤5, Int)
    @variable(model, 0≤Z[1:4]≤1, Int)

    @constraint(model, X in CBLS.Channel())
    @constraint(model, Y in CBLS.Channel(; dim = 2))
    @constraint(model, Z in CBLS.Channel(; id = 3))

    optimize!(model)

    @info "Channel" value.(X) value.(Y) value.(Z)
    termination_status(model)
    @info solution_summary(model)
end
