MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
function MOI.get(model::Optimizer, ::MOI.ObjectiveSense)
    return model.objective_sense
end
@optimizer_edit function MOI.set(model::Optimizer, ::MOI.ObjectiveSense, sense::MOI.OptimizationSense)
    model.objective_sense = sense
    _sync_objective!(model)
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
Base.copy(func::ScalarFunction) = ScalarFunction(func.f, isnothing(func.X) ? nothing : copy(func.X))

# supports
function MOI.supports(::Optimizer,
        ::OF{ScalarFunction{F, V}}) where {F <: Function, V <: Union{Nothing, VI, VOV}}
    true
end

# set
const SupportedObjective = Union{ScalarFunction, VI, MOI.ScalarAffineFunction{<:Real},
    MOI.ScalarQuadraticFunction{<:Real}}
MOI.supports(::Optimizer, ::OF{F}) where {F <: Union{VI, MOI.ScalarAffineFunction{<:Real}, MOI.ScalarQuadraticFunction{<:Real}}} = true
_objective_value(f::ScalarFunction{F,Nothing}, values) where {F} = f.f(values)
struct ObjectiveSubset{T,A} <: AbstractVector{T}
    values::A
    variables::Vector{VI}
end
ObjectiveSubset(values, variables) = ObjectiveSubset{eltype(values),typeof(values)}(values, variables)
Base.size(x::ObjectiveSubset) = (length(x.variables),)
Base.IndexStyle(::Type{<:ObjectiveSubset}) = IndexLinear()
Base.getindex(x::ObjectiveSubset, i::Int) = x.values[x.variables[i].value]
_objective_value(f::ScalarFunction{F,VOV}, values) where {F} = f.f(ObjectiveSubset(values, f.X.variables))
_objective_value(f::MOI.AbstractScalarFunction, values) = MOIU.eval_variables(v -> values[v.value], f)
function _sync_objective!(opt)
    opt.solver.model = opt.backend_model
    empty!(opt.backend_model.objectives)
    opt.backend_model.max_objs[] = 0
    sense!(opt, Val(opt.objective_sense == MOI.MAX_SENSE ? :max : :min))
    if !isnothing(opt.objective) && opt.objective_sense != MOI.FEASIBILITY_SENSE
        f = opt.objective
        objective!(opt, values -> _objective_value(f, values))
    end
    opt.optimized = false
    return nothing
end
@optimizer_edit function MOI.set(opt::Optimizer, ::OF{F}, f::F) where {F <: SupportedObjective}
    foreach(v -> _valid!(opt, v), _function_variables(f))
    opt.objective = copy(f)
    return _sync_objective!(opt)
end
MOI.get(opt::Optimizer, ::MOI.ObjectiveFunctionType) =
    isnothing(opt.objective) ? MOI.ScalarAffineFunction{Float64} : typeof(opt.objective)
function MOI.get(opt::Optimizer, ::OF{F}) where {F}
    f = isnothing(opt.objective) ? MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Float64}[], 0.0) : opt.objective
    return f isa F ? copy(f) : convert(F, f)
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
