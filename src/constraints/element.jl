"""
    MOIElement{I <: Integer, F <: Function, T <: Union{Nothing, Number}} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIElement{I <: Integer, F <: Function, T <: Union{Nothing, Number}} <:
       MOI.AbstractVectorSet
    id::I
    op::F
    val::T
    dimension::Int

    function MOIElement(id, op, val, dim = 0)
        return new{typeof(id), typeof(op), typeof(val)}(id, op, val, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIElement{I, F, T}}) where {
        I <: Integer, F <: Function, T <: Union{Nothing, Number}}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIElement)
    id = iszero(set.id) ? nothing : set.id
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:id => id, :op => set.op, :val => set.val))
        return error_f(USUAL_CONSTRAINTS[:element])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIElement{typeof(set.id), typeof(set.op), typeof(set.val)}}(cidx)
end

function Base.copy(set::MOIElement)
    return MOIElement(copy(set.id), copy(set.op), copy(set.val), copy(set.dimension))
end

"""
Global constraint ensuring that the value of `X` at index `id` is equal to `val`.

```julia
@constraint(model, X in Element(; id = nothing, op = ==, val = 0))
```
"""
struct Element{I <: Integer, F <: Function, T <: Union{Nothing, Number}} <:
       JuMP.AbstractVectorSet
    id::I
    op::F
    val::T

    function Element(; id::I = 0, op::F = ==,
            val::T = 0) where {I <: Integer, F <: Function, T <: Union{Nothing, Number}}
        return new{typeof(id), typeof(op), typeof(val)}(id, op, val)
    end
end

function JuMP.moi_set(set::Element, dim_moi::Int)
    return MOIElement(set.id, set.op, set.val, dim_moi)
end

## SECTION - Test Items
@testitem "Element" tags=[:usual, :constraints, :element] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤5, Int)
    @variable(model, 1≤Y[1:5]≤5, Int)
    @variable(model, 0≤Z[1:5]≤5, Int)

    @constraint(model, X in Element())
    @constraint(model, Y in Element(; id = 1, val = 1))
    @constraint(model, Z in Element(; id = 2, val = 2))

    optimize!(model)
    @info "Element" value.(X) value.(Y) value.(Z)
    termination_status(model)
    @info solution_summary(model)
end
