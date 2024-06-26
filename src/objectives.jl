MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
function MOI.get(model::Optimizer, ::MOI.ObjectiveSense)
    return sense(model) == 1 ? MOI.MIN_SENSE : MOI.MAX_SENSE
end
function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    sense!(model, Val(sense == MOI.MAX_SENSE ? :max : :min))
end

"""
    ScalarFunction{F <: Function, V <: Union{Nothing, VOV}} <: MOI.AbstractScalarFunction

A container to express any function with real value in JuMP syntax. Used with the `@objective` macro.

# Arguments:
- `f::F`: function to be applied to `X`
- `X::V`: a subset of the variables of the model.

Given a `model`, and some (collection of) variables `X` to optimize. an objective function `f` can be added as follows. Note that only `Min` for minimization us currently defined. `Max` will come soon.

```julia
# Applies to all variables in order of insertion.
# Recommended only when the function argument order does not matter.
@objective(model, ScalarFunction(f))

# Generic use
@objective(model, ScalarFunction(f, X))
```
"""
struct ScalarFunction{F <: Function, V <: Union{Nothing, VOV}} <: MOI.AbstractScalarFunction
    f::F
    X::V

    ScalarFunction(f, X::Union{Nothing, VOV} = nothing) = new{typeof(f), typeof(X)}(f, X)
end

# external constructors

function ScalarFunction(f, X::A) where {A <: AbstractArray{VariableRef}}
    return ScalarFunction(f, VOV(vec(map(index, X))))
end
ScalarFunction(f, x::VariableRef) = ScalarFunction(f, [x])
ScalarFunction(f, x::VI) = ScalarFunction(f, VOV([x]))

# copy
Base.copy(func::ScalarFunction) = ScalarFunction(func.f, func.X)

# supports
function MOI.supports(::Optimizer,
        ::OF{ScalarFunction{F, V}}) where {F <: Function, V <: Union{Nothing, VI, VOV}}
    true
end

# set
function MOI.set(optimizer::Optimizer, ::OF, func::ScalarFunction{F, Nothing}
) where {F <: Function} # for direct use of MOI
    return objective!(optimizer, func.f)
end

function MOI.set(optimizer::Optimizer, ::OF, func::ScalarFunction{F, VOV}
) where {F <: Function} # VOV, mainly for JuMP
    objective_func = _ -> func.f(map(y -> get_value(optimizer, y.value), func.X.variables))
    return objective!(optimizer, objective_func)
end

#  @autodoc
function MOIU.map_indices(index_map::Function, sf::ScalarFunction{F, VOV}
) where {F <: Function}
    return ScalarFunction(sf.f, MOIU.map_indices(index_map, sf.X))
end

#  @autodoc
function MOIU.map_indices(::Function, sf::ScalarFunction{F, Nothing}) where {F <: Function}
    return ScalarFunction(sf.f, nothing)
end

function MOIU._to_string(::MOIU._PrintOptions, ::MOI.ModelLike, f::ScalarFunction)
    return "Scalar Objective function: $(typeof(f))"
end

function JuMP.jump_function_type(::GenericModel{T}, F::Type{<:ScalarFunction}) where {T}
    return F
end
