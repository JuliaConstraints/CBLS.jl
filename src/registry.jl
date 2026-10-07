# Metadata lives at the MOI boundary, never in the candidate/movement loop.
MOI.is_valid(opt::Optimizer, variable::VI) = 1 <= variable.value <= LS.length_vars(opt.solver)
MOI.is_valid(opt::Optimizer, index::CI) = haskey(opt.registry, index)
_valid!(opt, index) = MOI.is_valid(opt, index) ? nothing : throw(MOI.InvalidIndex(index))
_function_variables(f::VI) = (f,)
_function_variables(f::VOV) = f.variables
function _function_variables(f::MOI.AbstractFunction)
    result = VI[]
    MOIU.map_indices(f) do variable
        variable isa VI && push!(result, variable)
        variable
    end
    return unique(result)
end
_has_lower(set) = set isa Union{MOI.GreaterThan, MOI.EqualTo, MOI.Interval}
_has_upper(set) = set isa Union{MOI.LessThan, MOI.EqualTo, MOI.Interval}

@optimizer_edit function MOI.add_constraint(opt::Optimizer, f::F, set::S) where {F <: MOI.AbstractFunction, S <: MOI.AbstractSet}
    MOI.supports_constraint(opt, F, S) || throw(MOI.UnsupportedConstraint{F, S}())
    foreach(variable -> _valid!(opt, variable), _function_variables(f))
    if set isa MOI.AbstractVectorSet
        MOI.output_dimension(f) == MOI.dimension(set) || throw(DimensionMismatch("function and set dimensions differ"))
    end
    if f isa VI
        for (old_f, old_set) in values(opt.registry)
            old_f == f || continue
            _has_lower(old_set) && _has_lower(set) && throw(MOI.LowerBoundAlreadySet{typeof(old_set), S}(f))
            _has_upper(old_set) && _has_upper(set) && throw(MOI.UpperBoundAlreadySet{typeof(old_set), S}(f))
        end
        haskey(opt.registry, CI{F,S}(f.value)) && throw(MOI.AddConstraintNotAllowed{F,S}("duplicate variable constraint"))
    end
    owned_f, owned_set = copy(f), copy(set)
    opt.solver.model = opt.backend_model
    index = _add_constraint_backend!(opt, owned_f, owned_set)
    opt.registry[index] = (owned_f, owned_set)
    opt.optimized = false
    return index
end

MOI.get(opt::Optimizer, ::MOI.ListOfVariableIndices) = VI.(1:LS.length_vars(opt.solver))
function MOI.get(opt::Optimizer, ::MOI.ListOfConstraintIndices{F,S}) where {F,S}
    return sort!(CI{F,S}[index for index in keys(opt.registry) if index isa CI{F,S}]; by = x -> x.value)
end
MOI.get(opt::Optimizer, ::MOI.NumberOfConstraints{F,S}) where {F,S} =
    count(index -> index isa CI{F,S}, keys(opt.registry))
function MOI.get(opt::Optimizer, ::MOI.ListOfConstraintTypesPresent)
    types = Set{Tuple{Type,Type}}((typeof(f),typeof(set)) for (f,set) in values(opt.registry))
    return sort!(collect(types); by = string)
end
function MOI.get(opt::Optimizer, ::MOI.ConstraintFunction, index::CI)
    _valid!(opt, index)
    return copy(opt.registry[index][1])
end
function MOI.get(opt::Optimizer, ::MOI.ConstraintSet, index::CI)
    _valid!(opt, index)
    return copy(opt.registry[index][2])
end
@optimizer_edit function MOI.delete(opt::Optimizer, index::Union{VI,CI})
    _valid!(opt, index)
    throw(MOI.DeleteNotAllowed(index, "CBLS requires empty! and copy_to for structural deletion"))
end
@optimizer_edit function MOI.modify(opt::Optimizer, index::CI, change::MOI.AbstractFunctionModification)
    _valid!(opt, index)
    throw(MOI.ModifyConstraintNotAllowed(index, change, "rebuild the model to modify constraints"))
end
@optimizer_edit function MOI.set(opt::Optimizer, attr::Union{MOI.ConstraintFunction, MOI.ConstraintSet}, index::CI, value)
    _valid!(opt, index)
    throw(MOI.SetAttributeNotAllowed(attr, "rebuild the model to replace constraint data"))
end

MOI.supports(::Optimizer, ::MOI.Name) = true
MOI.get(opt::Optimizer, ::MOI.Name) = opt.model_name
@optimizer_edit function MOI.set(opt::Optimizer, ::MOI.Name, value::String)
    opt.model_name=value
    nothing
end
MOI.supports(::Optimizer, ::MOI.VariableName, ::Type{VI}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{<:CI}) = true
MOI.supports(::Optimizer, ::MOI.ConstraintName, ::Type{<:CI{VI}}) = false
function MOI.get(opt::Optimizer, ::MOI.VariableName, index::VI)
    _valid!(opt, index)
    return get(opt.variable_names, index, "")
end
@optimizer_edit function MOI.set(opt::Optimizer, ::MOI.VariableName, index::VI, value::String)
    _valid!(opt, index)
    opt.variable_names[index] = value
    return nothing
end
function MOI.get(opt::Optimizer, ::MOI.ConstraintName, index::CI)
    _valid!(opt, index)
    return get(opt.constraint_names, index, "")
end
@optimizer_edit function MOI.set(opt::Optimizer, attr::MOI.ConstraintName, index::CI, value::String)
    _valid!(opt, index)
    index isa CI{VI} && throw(MOI.VariableIndexConstraintNameError())
    MOI.supports(opt, attr, typeof(index)) || throw(MOI.UnsupportedAttribute(attr))
    opt.constraint_names[index] = value
    return nothing
end
function _named_index(names, type, name)
    indices = [index for (index,value) in names if value == name && index isa type]
    length(indices) <= 1 || error("multiple indices have name $name")
    return isempty(indices) ? nothing : only(indices)
end
MOI.get(opt::Optimizer, ::Type{VI}, name::String) = _named_index(opt.variable_names, VI, name)
MOI.get(opt::Optimizer, ::Type{CI{F,S}}, name::String) where {F,S} = _named_index(opt.constraint_names, CI{F,S}, name)
MOI.get(opt::Optimizer, ::Type{CI}, name::String) = _named_index(opt.constraint_names, CI, name)
MOI.get(opt::Optimizer, ::MOI.ListOfVariableAttributesSet) =
    isempty(opt.variable_names) ? MOI.AbstractVariableAttribute[] : MOI.AbstractVariableAttribute[MOI.VariableName()]
MOI.get(opt::Optimizer, ::MOI.ListOfConstraintAttributesSet{F,S}) where {F,S} =
    any(index -> index isa CI{F,S}, keys(opt.constraint_names)) ?
    MOI.AbstractConstraintAttribute[MOI.ConstraintName()] : MOI.AbstractConstraintAttribute[]
function MOI.get(opt::Optimizer, ::MOI.ListOfModelAttributesSet)
    attrs = MOI.AbstractModelAttribute[]
    isempty(opt.model_name) || push!(attrs, MOI.Name())
    opt.objective_sense == MOI.FEASIBILITY_SENSE || push!(attrs, MOI.ObjectiveSense())
    isnothing(opt.objective) || push!(attrs, MOI.ObjectiveFunction{typeof(opt.objective)}())
    return attrs
end

# Standard MOI numerical forms, alongside the exact XCSP3 carriers.
const ScalarPolynomial = Union{MOI.ScalarAffineFunction{<:Real}, MOI.ScalarQuadraticFunction{<:Real}}
MOI.supports_constraint(::Optimizer, ::Type{<:ScalarPolynomial}, ::Type{<:NumericBoundSet}) = true
function _add_constraint_backend!(opt::Optimizer, f::ScalarPolynomial, set::NumericBoundSet)
    variables = _function_variables(f)
    position = Dict(variable => i for (i,variable) in enumerate(variables))
    local_f = MOIU.map_indices(variable -> VI(position[variable]), f)
    error = function (values; X = nothing)
        value = MOIU.eval_variables(variable -> values[variable.value], local_f)
        if set isa MOI.Interval
            return max(0.0, set.lower - value, value - set.upper)
        end
        op = set isa MOI.EqualTo ? (==) : set isa MOI.LessThan ? (<=) : (>=)
        target = set isa MOI.EqualTo ? set.value : set isa MOI.LessThan ? set.upper : set.lower
        return Constraints._condition_violation(value, target, op)
    end
    index = constraint!(opt, error, getfield.(variables, :value))
    return CI{typeof(f),typeof(set)}(index)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOI.AllDifferent}) = true
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{CPE.AllEqual}) = true
function _add_constraint_backend!(opt::Optimizer, f::VOV, set::Union{MOI.AllDifferent,CPE.AllEqual})
    kind = set isa MOI.AllDifferent ? :all_different : :all_equal
    index = constraint!(opt, Constraints.make_error(kind), getfield.(f.variables,:value))
    return CI{VOV,typeof(set)}(index)
end
