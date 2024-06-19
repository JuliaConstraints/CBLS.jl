"""
    MOIError{F <: Function} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `f::F`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOIError(f, dim = 0) = begin
        #= none:5 =#
        new{typeof(f)}(f, dim)
    end`: DESCRIPTION
"""
struct MOIError{F <: Function} <: MOI.AbstractVectorSet
    f::F
    dimension::Int

    MOIError(f, dim = 0) = new{typeof(f)}(f, dim)
end

"""
    MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIError}) = begin

DOCSTRING

# Arguments:
- ``: DESCRIPTION
- ``: DESCRIPTION
- ``: DESCRIPTION
"""
function MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIError{F}}
) where {F <: Function}
    return true
end

"""
    MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIError)

DOCSTRING

# Arguments:
- `optimizer`: DESCRIPTION
- `vars`: DESCRIPTION
- `set`: DESCRIPTION
"""
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables,
        set::MOIError{F}) where {F <: Function}
    cidx = constraint!(optimizer, set.f, map(x -> x.value, vars.variables))
    return CI{VOV, MOIError{F}}(cidx)
end

"""
    Base.copy(set::MOIError) = begin

DOCSTRING
"""
Base.copy(set::MOIError) = MOIError(deepcopy(set.f), set.dimension)

"""
    Error{F <: Function} <: JuMP.AbstractVectorSet

The solver will compute a straightforward error function based on the `concept`. To run the solver efficiently, it is possible to provide an *error function* `err` instead of `concept`. `err` must return a nonnegative real number.

```julia
@constraint(model, X in Error(err))
```
"""
struct Error{F <: Function} <: JuMP.AbstractVectorSet
    f::F
end

# @autodoc
JuMP.moi_set(set::Error{F}, dim::Int) where {F <: Function} = MOIError(set.f, dim)

"""
    MOIPredicate{F <: Function} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `f::F`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOIPredicate(f, dim = 0) = begin
        #= none:5 =#
        new{typeof(f)}(f, dim)
    end`: DESCRIPTION
"""
struct MOIPredicate{F <: Function} <: MOI.AbstractVectorSet
    f::F
    dimension::Int

    MOIPredicate(f, dim = 0) = new{typeof(f)}(f, dim)
end
function MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIPredicate{F}}
) where {F <: Function}
    return true
end
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables,
        set::MOIPredicate{F}) where {F <: Function}
    err = x -> convert(Float64, !set.f(x))
    cidx = constraint!(optimizer, err, map(x -> x.value, vars.variables))
    return CI{VOV, MOIPredicate{F}}(cidx)
end

Base.copy(set::MOIPredicate) = MOIPredicate(deepcopy(set.f), copy(set.dimension))

"""
    Predicate{F <: Function} <: JuMP.AbstractVectorSet

Assuming `X` is a (collection of) variables, `concept` a boolean function over `X`, and that a `model` is defined. In `JuMP` syntax we can create a constraint based on `concept` as follows.

```julia
@constraint(model, X in Predicate(concept))
```
"""
struct Predicate{F <: Function} <: JuMP.AbstractVectorSet
    f::F
end
JuMP.moi_set(set::Predicate, dim::Int) = MOIPredicate(set.f, dim)
