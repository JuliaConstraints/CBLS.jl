# Compilation of positional arguments happens once, outside the search loop.
struct CoreConstant{T}; value::T; end
struct CoreArray{A}; arguments::A; end
struct CoreExpression{A}; operator::Symbol; arguments::A; end

_bind_core(value) = CoreConstant(value)
_bind_core(value::CPE.XCSP3Position) = value
_bind_core(value::CPE.XCSP3Positions) = value
_bind_core(::CPE.XCSP3Star) = CoreConstant(nothing)
_bind_core(value::CPE.XCSP3Constant) = _bind_core(value.value)
_bind_core(value::CPE.XCSP3Constants) = _bind_core(value.values)
_bind_core(value::CPE.XCSP3ValueSet) = CoreConstant(value.values)
_bind_core(value::CPE.XCSP3Interval) = CoreConstant(value.lower:value.upper)
_bind_core(value::CPE.XCSP3Condition) = (CoreConstant(value.operator), _bind_core(value.operand))
_bind_core(value::CPE.XCSP3Expression) = CoreExpression(value.operator, map(_bind_core, value.arguments))
function _bind_core(value::Tuple)
    entries = map(_bind_core, value)
    return all(x -> x isa CoreConstant, entries) ? CoreConstant(map(x -> x.value, entries)) : entries
end
_bind_core(value::NamedTuple) = map(_bind_core, value)
function _bind_core(value::AbstractArray)
    entries = map(_bind_core, value)
    return all(x -> x isa CoreConstant, entries) ? CoreConstant(map(x -> x.value, entries)) : CoreArray(entries)
end
_bind_core(value::MOI.AbstractVectorSet) = CoreConstant(_xcsp3_evaluator(copy(value)))

@inline _resolve_core(value::CoreConstant, assignment) = value.value
@inline _resolve_core(value::CPE.XCSP3Position, assignment) = assignment[value.index]
@inline _resolve_core(value::CPE.XCSP3Positions, assignment) = view(assignment, value.indices)
@inline _resolve_core(values::Tuple, assignment) = map(x -> _resolve_core(x, assignment), values)
@inline _resolve_core(values::NamedTuple, assignment) = map(x -> _resolve_core(x, assignment), values)
_resolve_core(value::CoreArray, assignment) = map(x -> _resolve_core(x, assignment), value.arguments)
function _resolve_core(value::CoreExpression, assignment)
    args = value.arguments
    if value.operator == :if
        branch = Bool(_resolve_core(args[1], assignment)) ? 2 : 3
        return _resolve_core(args[branch], assignment)
    elseif value.operator == :and
        return all(x -> Bool(_resolve_core(x, assignment)), args)
    elseif value.operator == :or
        return any(x -> Bool(_resolve_core(x, assignment)), args)
    elseif value.operator == :imp
        return !Bool(_resolve_core(args[1], assignment)) || Bool(_resolve_core(args[2], assignment))
    end
    return Constraints.core_expression(value.operator, _resolve_core(args, assignment))
end

struct XCSP3StructuralEvaluator{A, E} <: Function
    dimension::Int
    arguments::A
    evaluator::E
end
function (e::XCSP3StructuralEvaluator)(assignment; X = nothing)
    length(assignment) == e.dimension || throw(DimensionMismatch("core assignment dimension"))
    try
        return e.evaluator(_resolve_core(e.arguments, assignment))
    catch error
        # Undefined arithmetic in an otherwise valid intension expression is not
        # a satisfying assignment. Shape/type/programming errors are not masked.
        error isa Union{DivideError, DomainError, InexactError} && return 1.0
        rethrow()
    end
end
function _xcsp3_evaluator(set::CPE.XCSP3Core{K}) where {K}
    if K == :slide
        sum(set.arguments.collects) == MOI.dimension(set.arguments.template) ||
            throw(DimensionMismatch("slide window and template dimensions"))
    end
    arguments = _bind_core(set.arguments)
    if K in (:regular,:mdd) && arguments.transitions isa CoreConstant &&
            get(arguments,:start,CoreConstant(nothing)) isa CoreConstant &&
            get(arguments,:final,CoreConstant(nothing)) isa CoreConstant
        language = Constraints.CoreLanguage(arguments.transitions.value;
            start = get(arguments,:start,CoreConstant(nothing)).value,
            final = get(arguments,:final,CoreConstant(nothing)).value)
        arguments = merge(arguments,(;transitions = CoreConstant(language)))
    end
    return XCSP3StructuralEvaluator(MOI.dimension(set), arguments,
        Constraints.CoreEvaluator(Val(K)))
end
_xcsp3_evaluator(set::CPE.XCSP3AllDifferent) =
    bind_error(Constraints.make_error(:all_different); vals = isempty(set.except) ? nothing : copy(set.except))
_xcsp3_evaluator(set::CPE.XCSP3Sum) =
    XCSP3SumEvaluator(set, Constraints.make_error(:sum), _xcsp3_operator(set.condition.operator))
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{<:CPE.XCSP3Core}) = true
function _add_constraint_backend!(optimizer::Optimizer, variables::VOV, set::CPE.XCSP3Core)
    length(variables.variables) == MOI.dimension(set) || throw(DimensionMismatch("core function/set dimension"))
    evaluator = _xcsp3_evaluator(copy(set))
    index = constraint!(optimizer, evaluator, map(variable -> variable.value, variables.variables))
    return CI{VOV, typeof(set)}(index)
end

# Domain-dependent parameters are prepared after model construction, but before
# solver specialization/search. They must never be inferred from an assignment.
function _precedence_scope_domains(value::CPE.XCSP3Positions, variables, model)
    return [_precedence_position_domain(index, variables, model) for index in vec(value.indices)]
end
function _precedence_position_domain(index, variables, model)
    LS.get_variable(model, variables[index].value).domain isa ConstraintDomains.ContinuousDomain &&
        throw(ArgumentError("implicit precedence needs finite discrete domains; supply explicit values otherwise"))
    d = LS.get_domain(model, variables[index].value)
    # A continuous interval is not a finite collection of precedence values.
    all(v -> v isa Real && isfinite(v), d) || throw(ArgumentError(
        "implicit precedence needs finite discrete domains; supply explicit values otherwise"))
    return d
end
_precedence_term_domain(value::CPE.XCSP3Position, variables, model) =
    _precedence_position_domain(value.index, variables, model)
_precedence_term_domain(value::Real, variables, model) = (value,)
_precedence_term_domain(value::CPE.XCSP3Constant, variables, model) =
    _precedence_term_domain(value.value, variables, model)
_precedence_term_domain(value, variables, model) = throw(ArgumentError(
    "implicit precedence over expressions needs explicit counted values"))
function _precedence_scope_domains(value::Union{AbstractArray, Tuple}, variables, model)
    return [_precedence_term_domain(term, variables, model) for term in value]
end
_precedence_scope_domains(value::CPE.XCSP3Constants, variables, model) =
    _precedence_scope_domains(value.values, variables, model)

function _prepare_xcsp3_domains!(optimizer::Optimizer, model)
    for (index, (function_, set)) in optimizer.registry
        set isa CPE.XCSP3Core{:precedence} || continue
        haskey(set.arguments, :values) && continue
        domains = _precedence_scope_domains(set.arguments.list, function_.variables, model)
        counted_values = Constraints.core_precedence_values(domains)
        prepared = CPE.XCSP3Precedence(MOI.dimension(set);
            merge(set.arguments, (; values = counted_values))...)
        previous = LS.get_constraint(model, index.value)
        LS.get_constraints(model)[index.value] = LS.constraint(_xcsp3_evaluator(prepared), previous.vars)
    end
    return model
end
