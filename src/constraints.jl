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
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIError{F}) where {F <: Function}
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
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIPredicate{F}) where {F <: Function}
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

"""
    MOIAllDifferent <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAllDifferent <: MOI.AbstractVectorSet
    dimension::Int

    MOIAllDifferent(dim = 0) = new(dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAllDifferent}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIAllDifferent)
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:all_different])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAllDifferent}(cidx)
end
Base.copy(set::MOIAllDifferent) = MOIAllDifferent(copy(set.dimension))

"""
Global constraint ensuring that all the values of a given configuration are unique.

```julia
@constraint(model, X in AllDifferent())
```
"""
struct AllDifferent <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AllDifferent, dim::Int) = MOIAllDifferent(dim)

"""
    MOIAllEqual <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAllEqual <: MOI.AbstractVectorSet
    dimension::Int

    MOIAllEqual(dim = 0) = new(dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAllEqual}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIAllEqual)
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:all_equal])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAllEqual}(cidx)
end

Base.copy(set::MOIAllEqual) = MOIAllEqual(copy(set.dimension))

"""
Global constraint ensuring that all the values of `X` are all equal.

```julia
@constraint(model, X in AllEqual())
```
"""
struct AllEqual <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AllEqual, dim::Int) = MOIAllEqual(dim)

"""
    MOIEq <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIEq <: MOI.AbstractVectorSet
    dimension::Int

    MOIEq(dim = 0) = new(dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIEq}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIEq)
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:eq])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIEq}(cidx)
end

Base.copy(set::MOIEq) = MOIEq(copy(set.dimension))

"""
Equality between two variables.

```julia
@constraint(model, X in Eq())
```
"""
struct Eq <: JuMP.AbstractVectorSet end
JuMP.moi_set(::Eq, dim::Int) = MOIEq(dim)

"""
    MOIAlwaysTrue <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAlwaysTrue <: MOI.AbstractVectorSet
    dimension::Int

    MOIAlwaysTrue(dim = 0) = new(dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAlwaysTrue}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIAlwaysTrue)
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(USUAL_CONSTRAINTS[:always_true])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAlwaysTrue}(cidx)
end

Base.copy(set::MOIAlwaysTrue) = MOIAlwaysTrue(copy(set.dimension))

"""
Always return `true`. Mainly used for testing purpose.

```julia
@constraint(model, X in AlwaysTrue())
```
"""
struct AlwaysTrue <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AlwaysTrue, dim::Int) = MOIAlwaysTrue(dim)

"""
    MOIOrdered <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIOrdered <: MOI.AbstractVectorSet
    dimension::Int

    MOIOrdered(dim = 0) = new(dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIOrdered}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIOrdered)
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:ordered])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIOrdered}(cidx)
end

Base.copy(set::MOIOrdered) = MOIOrdered(copy(set.dimension))

"""
Global constraint ensuring that all the values of `x` are ordered.

```julia
@constraint(model, X in Ordered())
```
"""
struct Ordered <: JuMP.AbstractVectorSet end
JuMP.moi_set(::Ordered, dim::Int) = MOIOrdered(dim)


"""
    MOIDistDifferent <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIDistDifferent <: MOI.AbstractVectorSet
    dimension::Int

    MOIDistDifferent(dim = 4) = new(dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIDistDifferent}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIDistDifferent)
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:dist_different])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIDistDifferent}(cidx)
end
Base.copy(set::MOIDistDifferent) = MOIDistDifferent(copy(set.dimension))

"""
Local constraint ensuring that, given a vector `X` of size 4, `|X[1] - X[2]| ≠ |X[3] - X[4]|)`.

```julia
@constraint(model, X in DistDifferent())
```
"""
struct DistDifferent <: JuMP.AbstractVectorSet end
JuMP.moi_set(::DistDifferent, dim::Int) = MOIDistDifferent(dim)

"""
    MOIAllEqualParam{T <: Number} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `param::T`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOIAllEqualParam(param, dim = 0) = begin
        #= none:5 =#
        new{typeof(param)}(param, dim)
    end`: DESCRIPTION
"""
struct MOIAllEqualParam{T <: Number} <: MOI.AbstractVectorSet
    param::T
    dimension::Int

    MOIAllEqualParam(param, dim = 0) = new{typeof(param)}(param, dim)
end
function MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAllEqualParam{T}}
) where {T <: Number}
    return true
end
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIAllEqualParam{T}
) where T <: Number
    # max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:all_equal_param])(x; param=param, dom_size=dom_size
    )
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIAllEqualParam{T}}(cidx)
end

Base.copy(set::MOIAllEqualParam) = MOIAllEqualParam(copy(set.param), copy(set.dimension))

"""
Global constraint ensuring that all the values of `X` are all equal to a given parameter `param`.

```julia
@constraint(model, X in AllEqualParam(param))
```
"""
struct AllEqualParam{T <: Number} <: JuMP.AbstractVectorSet
    param::T
end
JuMP.moi_set(set::AllEqualParam, dim::Int) = MOIAllEqualParam(set.param, dim)

"""
    MOISumEqualParam{T <: Number} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `param::T`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOISumEqualParam(param, dim = 0) = begin
        #= none:5 =#
        new{typeof(param)}(param, dim)
    end`: DESCRIPTION
"""
struct MOISumEqualParam{T <: Number} <: MOI.AbstractVectorSet
    param::T
    dimension::Int

    MOISumEqualParam(param, dim = 0) = new{typeof(param)}(param, dim)
end
function MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOISumEqualParam{T}}
) where {T <: Number}
    return true
end
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOISumEqualParam{T}
) where {T <: Number}
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:sum_equal_param])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOISumEqualParam{T}}(cidx)
end

Base.copy(set::MOISumEqualParam) = MOISumEqualParam(copy(set.param),
copy(set.dimension))

"""
Global constraint ensuring that the sum of the values of `X` is equal to a given parameter `param`.

```julia
@constraint(model, X in SumEqualParam(param))
```
"""
struct SumEqualParam{T <: Number} <: JuMP.AbstractVectorSet
    param::T
end
JuMP.moi_set(set::SumEqualParam, dim::Int) = MOISumEqualParam(set.param, dim)

"""
    MOILessThanParam{T <: Number} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `param::T`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOILessThanParam(param, dim = 0) = begin
        #= none:5 =#
        new{typeof(param)}(param, dim)
    end`: DESCRIPTION
"""
struct MOILessThanParam{T <: Number} <: MOI.AbstractVectorSet
    param::T
    dimension::Int

    MOILessThanParam(param, dim = 0) = new{typeof(param)}(param, dim)
end
function MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOILessThanParam{T}}
) where {T <: Number}
    return true
end
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOILessThanParam{T}
) where {T <: Number}
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:less_than_param])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOILessThanParam{T}}(cidx)
end

Base.copy(set::MOILessThanParam) = MOILessThanParam(copy(set.param),
copy(set.dimension))

"""
Constraint ensuring that the value of `x` is less than a given parameter `param`.

```julia
@constraint(model, x in LessThanParam(param))
```
"""
struct LessThanParam{T <: Number} <: JuMP.AbstractVectorSet
    param::T
end
JuMP.moi_set(set::LessThanParam, dim::Int) = MOILessThanParam(set.param, dim)

"""
    MOIMinusEqualParam{T <: Number} <: MOI.AbstractVectorSet

DOCSTRING

# Arguments:
- `param::T`: DESCRIPTION
- `dimension::Int`: DESCRIPTION
- `MOIMinusEqualParam(param, dim = 0) = begin
        #= none:5 =#
        new{typeof(param)}(param, dim)
    end`: DESCRIPTION
"""
struct MOIMinusEqualParam{T <: Number} <: MOI.AbstractVectorSet
    param::T
    dimension::Int

    MOIMinusEqualParam(param, dim = 0) = new{typeof(param)}(param, dim)
end
function MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIMinusEqualParam{T}}
) where {T <: Number}
    return true
end
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIMinusEqualParam{T}
) where {T <: Number}
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:minus_equal_param])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIMinusEqualParam{T}}(cidx)
end

Base.copy(set::MOIMinusEqualParam) = MOIMinusEqualParam(copy(set.param),
copy(set.dimension))

"""
Constraint ensuring that the value of `x` is less than a given parameter `param`.

```julia
@constraint(model, x in MinusEqualParam(param))
```
"""
struct MinusEqualParam{T <: Number} <: JuMP.AbstractVectorSet
    param::T
end
JuMP.moi_set(set::MinusEqualParam, dim::Int) = MOIMinusEqualParam(set.param, dim)


"""
    MOISequentialTasks <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOISequentialTasks <: MOI.AbstractVectorSet
    dimension::Int

    MOISequentialTasks(dim = 4) = new(dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOISequentialTasks}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOISequentialTasks)
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:sequential_tasks])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOISequentialTasks}(cidx)
end
Base.copy(set::MOISequentialTasks) = MOISequentialTasks(copy(set.dimension))

"""
Local constraint ensuring that, given a vector `X` of size 4, `|X[1] - X[2]| ≠ |X[3] - X[4]|)`.

```julia
@constraint(model, X in SequentialTasks())
```
"""
struct SequentialTasks <: JuMP.AbstractVectorSet end
JuMP.moi_set(::SequentialTasks, dim::Int) = MOISequentialTasks(dim)
