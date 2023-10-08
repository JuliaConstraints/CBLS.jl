"""
    JuMP.build_variable(::Function, info::JuMP.VariableInfo, set::T) where T <: MOI.AbstractScalarSet

DOCSTRING

# Arguments:
- ``: DESCRIPTION
- `info`: DESCRIPTION
- `set`: DESCRIPTION
"""
function JuMP.build_variable(
    ::Function,
    info::JuMP.VariableInfo,
    set::T,
) where {T<:MOI.AbstractScalarSet}
    return JuMP.VariableConstrainedOnCreation(JuMP.ScalarVariable(info), set)
end

"""
    Optimizer <: MOI.AbstractOptimizer

DOCSTRING

# Arguments:
- `solver::Solver`: DESCRIPTION
- `status::MOI.TerminationStatusCode`: DESCRIPTION
- `options::Options`: DESCRIPTION
"""
mutable struct Optimizer <: MOI.AbstractOptimizer
    solver::LS.MainSolver
    int_vars::Set{Int}
    compare_vars::Set{Int}
end

"""
    Optimizer(model = Model(); options = Options())

DOCSTRING
"""
function Optimizer(model = model(); options = Options())
    return Optimizer(
        solver(model, options = options),
        Set{Int}(),
        Set{Int}()
        )
end

# forward functions from Solver
@forward Optimizer.solver LS.variable!, LS._set_domain!, LS.constraint!, LS.solution
@forward Optimizer.solver LS.max_domains_size, LS.objective!, Base.empty!, LS._inc_cons!
@forward Optimizer.solver LS._best_bound, LS.best_value, LS.is_sat, LS.get_value
@forward Optimizer.solver LS.domain_size, LS.best_values, LS._max_cons, LS.update_domain!
@forward Optimizer.solver LS.get_variable, LS.has_solution, LS.sense, LS.sense!
@forward Optimizer.solver LS.time_info, LS.status

# forward functions from Solver (from Options)
@forward Optimizer.solver LS._verbose, LS.set_option!, LS.get_option

"""
    MOI.get(::Optimizer, ::MOI.SolverName) = begin

DOCSTRING
"""
MOI.get(::Optimizer, ::MOI.SolverName) = "LocalSearchSolvers"

"""
    MOI.set(::Optimizer, ::MOI.Silent, bool = true) = begin

DOCSTRING

# Arguments:
- ``: DESCRIPTION
- ``: DESCRIPTION
- `bool`: DESCRIPTION
"""
MOI.set(::Optimizer, ::MOI.Silent, bool = true) = @debug "TODO: Silent"

"""
    MOI.is_empty(model::Optimizer) = begin

DOCSTRING
"""
MOI.is_empty(model::Optimizer) = LS._is_empty(model.solver)

"""
Copy constructor for the optimizer
"""
MOI.supports_incremental_interface(::Optimizer) = true
function MOI.copy_to(model::Optimizer, src::MOI.ModelLike)
    return MOIU.default_copy_to(model, src)
end

"""
    MOI.optimize!(model::Optimizer)
"""
MOI.optimize!(optimizer::Optimizer) = solve!(optimizer.solver)

"""
    DiscreteSet(values)
"""
struct DiscreteSet{T <: Number} <: MOI.AbstractScalarSet
    values::Vector{T}
end
DiscreteSet(values) = DiscreteSet(collect(values))
DiscreteSet(values::T...) where {T<:Number} = DiscreteSet(collect(values))

"""
    Base.copy(set::DiscreteSet) = begin

DOCSTRING
"""
Base.copy(set::DiscreteSet) = DiscreteSet(copy(set.values))

"""
    MOI.empty!(opt) = begin

DOCSTRING
"""
MOI.empty!(opt) = empty!(opt)


function MOI.is_valid(optimizer::Optimizer, index::CI{VI, MOI.Integer})
    return index.value ∈ optimizer.int_vars
end
