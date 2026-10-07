function MOI.supports_constraint(
        ::Optimizer, ::Type{VOV}, ::Type{<:CPE.XCSP3AllDifferent})
    return true
end

function _add_constraint_backend!(optimizer::Optimizer, vars::VOV,
        set::CPE.XCSP3AllDifferent)
    length(vars.variables) == MOI.dimension(set) || throw(DimensionMismatch(
        "XCSP3AllDifferent function and set dimensions differ"))
    except = isempty(set.except) ? nothing : set.except
    evaluator = bind_error(Constraints.make_error(:all_different); vals = except)
    index = constraint!(optimizer, evaluator, map(variable -> variable.value, vars.variables))
    return CI{VOV, typeof(set)}(index)
end


@inline _xcsp3_operator(::Val{:eq}) = ==
@inline _xcsp3_operator(::Val{:ne}) = !=
@inline _xcsp3_operator(::Val{:lt}) = <
@inline _xcsp3_operator(::Val{:le}) = <=
@inline _xcsp3_operator(::Val{:gt}) = >
@inline _xcsp3_operator(::Val{:ge}) = >=
@inline _xcsp3_operator(::Val{:in}) = (value, interval) -> value in interval
@inline _xcsp3_operator(::Val{:notin}) = (value, interval) -> value ∉ interval
@inline _xcsp3_operator(operator::Symbol) = _xcsp3_operator(Val(operator))

struct XCSP3SumEvaluator{S, E, F} <: Function
    set::S
    error::E
    operator::F
end

function (evaluator::XCSP3SumEvaluator)(values; X = nothing)
    set = evaluator.set
    length(values) == MOI.dimension(set) || throw(DimensionMismatch(
        "XCSP3Sum received an assignment of the wrong dimension"))
    list = @view values[1:set.list_length]
    next_position = set.list_length + 1
    coefficients = if set.coefficients isa CPE.XCSP3Variables
        last_position = next_position + set.list_length - 1
        result = @view values[next_position:last_position]
        next_position = last_position + 1
        result
    else
        set.coefficients.values
    end
    operand = set.condition.operand
    target = if operand isa CPE.XCSP3Variable
        values[next_position]
    elseif operand isa CPE.XCSP3Position
        values[operand.index]
    elseif operand isa CPE.XCSP3Constant
        operand.value
    elseif operand isa CPE.XCSP3ValueSet
        operand.values
    else
        operand.lower:operand.upper
    end
    return evaluator.error(
        list; X, op = evaluator.operator, pair_vars = coefficients, val = target)
end

function MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{<:CPE.XCSP3Sum})
    return true
end

function _add_constraint_backend!(optimizer::Optimizer, vars::VOV, set::CPE.XCSP3Sum)
    length(vars.variables) == MOI.dimension(set) || throw(DimensionMismatch(
        "XCSP3Sum function and set dimensions differ"))
    evaluator = XCSP3SumEvaluator(
        set, Constraints.make_error(:sum), _xcsp3_operator(set.condition.operator))
    index = constraint!(optimizer, evaluator, map(variable -> variable.value, vars.variables))
    return CI{VOV, typeof(set)}(index)
end

# Argument descriptors carry layout only. Views read the current assignment, even
# when one MOI variable appears in several blocks of the constrained vector.
@inline _xcsp3_argument(arg::CPE.XCSP3Constants, assignment, position) = (arg.values, position)
@inline _xcsp3_argument(arg::CPE.XCSP3Variables, assignment, position) =
    (@view(assignment[position:(position + arg.length - 1)]), position + arg.length)
@inline _xcsp3_target(arg::CPE.XCSP3Variable, assignment, position) = assignment[position]
@inline _xcsp3_target(arg::CPE.XCSP3Position, assignment, position) = assignment[arg.index]
@inline _xcsp3_target(arg::CPE.XCSP3Constant, assignment, position) = arg.value
@inline _xcsp3_target(arg::CPE.XCSP3ValueSet, assignment, position) = arg.values
@inline _xcsp3_target(arg::CPE.XCSP3Interval, assignment, position) = arg.lower:arg.upper

struct XCSP3CountEvaluator{S, E, F} <: Function
    set::S
    error::E
    operator::F
end
struct XCSP3NValuesEvaluator{S, E, F} <: Function
    set::S
    error::E
    operator::F
end

function (evaluator::XCSP3CountEvaluator)(assignment; X = nothing)
    set = evaluator.set
    length(assignment) == MOI.dimension(set) || throw(DimensionMismatch("invalid count assignment"))
    list = @view assignment[1:set.list_length]
    vals, next_position = _xcsp3_argument(set.values, assignment, set.list_length + 1)
    target = _xcsp3_target(set.condition.operand, assignment, next_position)
    return evaluator.error(list; X, vals, op = evaluator.operator, val = target)
end

function (evaluator::XCSP3NValuesEvaluator)(assignment; X = nothing)
    set = evaluator.set
    length(assignment) == MOI.dimension(set) || throw(DimensionMismatch("invalid nValues assignment"))
    list = @view assignment[1:set.list_length]
    target = _xcsp3_target(set.condition.operand, assignment, set.list_length + 1)
    return evaluator.error(list; X, vals = set.except, op = evaluator.operator, val = target)
end

# Read-only column adapter, not a materialized hcat per candidate. Constraints.jl
# owns the counting semantics and penalty; this adapter only exposes its matrix API.
struct XCSP3OccurrenceTable{T, V, O} <: AbstractMatrix{T}
    values::V
    occurs::O
end
_xcsp3_occurrence_type(::Type{T}) where {T <: Number} = T
_xcsp3_occurrence_type(::Type{T}) where {T <: AbstractRange} = eltype(T)
_xcsp3_occurrence_type(::Type) = Any
function XCSP3OccurrenceTable(values::V, occurs::O) where {V, O}
    T = promote_type(eltype(V), _xcsp3_occurrence_type(eltype(O)))
    return XCSP3OccurrenceTable{T, V, O}(values, occurs)
end
Base.size(table::XCSP3OccurrenceTable) = (length(table.values), 3)
@inline function Base.getindex(table::XCSP3OccurrenceTable{T}, i::Int, j::Int) where {T}
    @boundscheck checkbounds(table, i, j)
    j == 1 && return convert(T, table.values[i])
    occurrence = table.occurs[i]
    value = occurrence isa Number ? occurrence : (j == 2 ? first(occurrence) : last(occurrence))
    return convert(T, value)
end

struct XCSP3CardinalityEvaluator{S, E, D} <: Function
    set::S
    error::E
    distinct_error::D
end
function (evaluator::XCSP3CardinalityEvaluator)(assignment; X = nothing)
    set = evaluator.set
    length(assignment) == MOI.dimension(set) || throw(DimensionMismatch("invalid cardinality assignment"))
    list = @view assignment[1:set.list_length]
    vals, position = _xcsp3_argument(set.values, assignment, set.list_length + 1)
    occurs, _ = _xcsp3_argument(set.occurs, assignment, position)
    table = XCSP3OccurrenceTable(vals, occurs)
    result = evaluator.error(list; X, vals = table, bool = set.closed)
    if set.values isa CPE.XCSP3Variables && set.occurs isa CPE.XCSP3Variables
        result += evaluator.distinct_error(vals)
    end
    return result
end

_xcsp3_evaluator(set::CPE.XCSP3Count) = XCSP3CountEvaluator(
    set, Constraints.make_error(:count), _xcsp3_operator(set.condition.operator))
_xcsp3_evaluator(set::CPE.XCSP3NValues) = XCSP3NValuesEvaluator(
    set, Constraints.make_error(:nvalues), _xcsp3_operator(set.condition.operator))
_xcsp3_evaluator(set::CPE.XCSP3Cardinality) = XCSP3CardinalityEvaluator(
    set, Constraints.make_error(:cardinality), Constraints.make_error(:all_different))

const XCSP3CountingSet = Union{CPE.XCSP3Count, CPE.XCSP3NValues, CPE.XCSP3Cardinality}
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{<:XCSP3CountingSet}) = true
function _add_constraint_backend!(optimizer::Optimizer, vars::VOV, set::XCSP3CountingSet)
    length(vars.variables) == MOI.dimension(set) || throw(DimensionMismatch(
        "XCSP3 counting function and set dimensions differ"))
    evaluator = _xcsp3_evaluator(copy(set))
    index = constraint!(optimizer, evaluator, map(variable -> variable.value, vars.variables))
    return CI{VOV, typeof(set)}(index)
end


@testitem "provisional XCSP3 MOI vertical slice" tags=[:xcsp3, :moi] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import MathOptInterface as MOI
    import Test: @test, @test_throws

    optimizer = CBLS.Optimizer()
    variables = MOI.add_variables(optimizer, 7)

    all_different = CPE.XCSP3AllDifferent(3; except = [0])
    @test MOI.supports_constraint(
        optimizer, MOI.VectorOfVariables, typeof(all_different))
    all_different_index = MOI.add_constraint(
        optimizer, MOI.VectorOfVariables(variables[1:3]), all_different)
    all_different_error = CBLS.LS.get_constraint(
        optimizer.solver, all_different_index.value).f
    @test all_different_error([0, 0, 1]) == 0.0
    @test all_different_error([1, 1, 2]) > 0.0

    variable_sum = CPE.XCSP3Sum(3;
        coefficients = CPE.XCSP3Variables(3),
        condition = CPE.XCSP3Condition(:eq, CPE.XCSP3Variable()),
    )
    @test MOI.supports_constraint(optimizer, MOI.VectorOfVariables, typeof(variable_sum))
    sum_index = MOI.add_constraint(
        optimizer, MOI.VectorOfVariables(variables), variable_sum)
    sum_error = CBLS.LS.get_constraint(optimizer.solver, sum_index.value).f
    @test sum_error([2, 3, 4, 4, 5, -1, 19]) == 0.0
    @test sum_error([2, 3, 4, 4, 5, -1, 18]) > 0.0

    set_sum = CPE.XCSP3Sum(3;
        condition = CPE.XCSP3Condition(:in, CPE.XCSP3ValueSet(Set([8, 9]))),
    )
    set_sum_index = MOI.add_constraint(
        optimizer, MOI.VectorOfVariables(variables[1:3]), set_sum)
    set_sum_error = CBLS.LS.get_constraint(optimizer.solver, set_sum_index.value).f
    @test set_sum_error([2, 3, 4]) == 0.0
    @test set_sum_error([1, 2, 3]) > 0.0

    @test_throws DimensionMismatch MOI.add_constraint(
        optimizer, MOI.VectorOfVariables(variables[1:2]), all_different)
end


@testitem "JuMP accepts CPE XCSP3 sets directly" tags=[:xcsp3, :jump] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import JuMP
    import MathOptInterface as MOI
    import Test: @test

    model = JuMP.Model(CBLS.Optimizer)
    JuMP.@variable(model, x[1:3])
    JuMP.@constraint(model, domain[i = 1:3], x[i] in CPE.Domain(Set(1:3)))
    all_different = JuMP.@constraint(model, x in CPE.XCSP3AllDifferent(3))
    bounded_sum = JuMP.@constraint(model,
        x in CPE.XCSP3Sum(3; condition = CPE.XCSP3Condition(:le, 6)))

    @test JuMP.index(all_different) isa
          MOI.ConstraintIndex{MOI.VectorOfVariables, <:CPE.XCSP3AllDifferent}
    @test JuMP.index(bounded_sum) isa
          MOI.ConstraintIndex{MOI.VectorOfVariables, <:CPE.XCSP3Sum}
    @test all(JuMP.constraint_object(constraint).set == CPE.Domain(Set(1:3))
        for constraint in domain)
end
