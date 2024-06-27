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
    MOIIntention{F <: Function} <: MOI.AbstractVectorSet

Represents an intention set in the model.

# Arguments
- `f::F`: A function representing the intention.
- `dimension::Int`: The dimension of the vector set.
"""
struct MOIIntention{F <: Function} <: MOI.AbstractVectorSet
    f::F
    dimension::Int

    MOIIntention(f, dim = 0) = new{typeof(f)}(f, dim)
end

"""
    MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIIntention{F}}) where {F <: Function}

Check if the optimizer supports a given intention constraint.

# Arguments
- `::Optimizer`: The optimizer instance.
- `::Type{VOV}`: The type of the variable.
- `::Type{MOIIntention{F}}`: The type of the intention.

# Returns
- `Bool`: True if the optimizer supports the constraint, false otherwise.
"""
function MOI.supports_constraint(
        ::Optimizer, ::Type{VOV}, ::Type{MOIIntention{F}}) where {F <: Function}
    return true
end

"""
    MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIIntention{F}) where {F <: Function}

Add an intention constraint to the optimizer.

# Arguments
- `optimizer::Optimizer`: The optimizer instance.
- `vars::MOI.VectorOfVariables`: The variables for the constraint.
- `set::MOIIntention{F}`: The intention set defining the constraint.

# Returns
- `CI{VOV, MOIIntention{F}}`: The constraint index.
"""
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables,
        set::MOIIntention{F}) where {F <: Function}
    err = x -> convert(Float64, !set.f(x))
    cidx = constraint!(optimizer, err, map(x -> x.value, vars.variables))
    return CI{VOV, MOIIntention{F}}(cidx)
end

"""
    Base.copy(set::MOIIntention)

Copy an intention set.

# Arguments
- `set::MOIIntention`: The intention set to be copied.

# Returns
- `MOIIntention`: A copy of the intention set.
"""
Base.copy(set::MOIIntention) = MOIIntention(deepcopy(set.f), copy(set.dimension))

"""
    Predicate{F <: Function} <: JuMP.AbstractVectorSet

Deprecated: Use `Intention` instead.

Represents a predicate set in the model.

# Arguments
- `f::F`: A function representing the predicate.
"""
struct Predicate{F <: Function} <: JuMP.AbstractVectorSet
    f::F
end

"""
    Intention{F <: Function} <: JuMP.AbstractVectorSet

Represents an intention set in the model.

# Arguments
- `f::F`: A function representing the intention.
"""
struct Intention{F <: Function} <: JuMP.AbstractVectorSet
    f::F
end

"""
    JuMP.moi_set(set::Predicate, dim::Int) -> MOIIntention

Convert a `Predicate` set to a `MOIIntention` set.

# Arguments
- `set::Predicate`: The predicate set to be converted.
- `dim::Int`: The dimension of the vector set.

# Returns
- `MOIIntention`: The converted MOIIntention set.
"""
JuMP.moi_set(set::Predicate, dim::Int) = MOIIntention(set.f, dim)

"""
    JuMP.moi_set(set::Intention, dim::Int) -> MOIIntention

Convert an `Intention` set to a `MOIIntention` set.

# Arguments
- `set::Intention`: The intention set to be converted.
- `dim::Int`: The dimension of the vector set.

# Returns
- `MOIIntention`: The converted MOIIntention set.
"""
JuMP.moi_set(set::Intention, dim::Int) = MOIIntention(set.f, dim)

## SECTION - Test Items
@testitem "Error and Predicate" begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:4]≤4, Int)
    @variable(model, 1≤Y[1:4]≤4, Int)

    @constraint(model, X in Error(x -> x[1] + x[2] + x[3] + x[4] == 10))
    @constraint(model, Y in Intention(x -> x[1] + x[2] + x[3] + x[4] == 10))

    optimize!(model)
    @info "Error and Intention" value.(X) value.(Y)
    termination_status(model)
    @info solution_summary(model)
end
