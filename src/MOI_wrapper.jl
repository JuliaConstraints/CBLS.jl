"""
    JuMP.build_variable(::Function, info::JuMP.VariableInfo, set::T) where T <: MOI.AbstractScalarSet

Create a variable constrained by a scalar set.

# Arguments
- `info::JuMP.VariableInfo`: Information about the variable to be created.
- `set::T where T <: MOI.AbstractScalarSet`: The set defining the constraints on the variable.

# Returns
- `JuMP.VariableConstrainedOnCreation`: A variable constrained by the specified set.
"""
function JuMP.build_variable(
        ::Function,
        info::JuMP.VariableInfo,
        set::T
) where {T <: MOI.AbstractScalarSet}
    return JuMP.VariableConstrainedOnCreation(JuMP.ScalarVariable(info), set)
end

"""
    Optimizer <: MOI.AbstractOptimizer

Defines an optimizer for CBLS.

# Fields
- `solver::LS.MainSolver`: The main solver used for local search.
- `int_vars::Set{Int}`: Set of integer variables.
- `compare_vars::Set{Int}`: Set of variables to compare.
"""
mutable struct Optimizer <: MOI.AbstractOptimizer
    solver::LS.MainSolver
    int_vars::Set{Int}
    compare_vars::Set{Int}
end

"""
    Optimizer(model = Model(); options = Options())

Create an instance of the Optimizer.

# Arguments
- `model`: The model to be optimized.
- `options::Options`: Options for configuring the solver.

# Returns
- `Optimizer`: An instance of the optimizer.
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
@forward Optimizer.solver LS.time_info, LS.status, LS.length_vars

# forward functions from Solver (from Options)
@forward Optimizer.solver LS._verbose, LS.set_option!, LS.get_option

"""
    MOI.get(::Optimizer, ::MOI.SolverName)

Get the name of the solver.

# Arguments
- `::Optimizer`: The optimizer instance.

# Returns
- `String`: The name of the solver.
"""
MOI.get(::Optimizer, ::MOI.SolverName) = "CBLS"

"""
    MOI.set(::Optimizer, ::MOI.Silent, bool = true)

Set the verbosity of the solver.

# Arguments
- `::Optimizer`: The optimizer instance.
- `::MOI.Silent`: The silent option for the solver.
- `bool::Bool`: Whether to set the solver to silent mode.

# Returns
- `Nothing`
"""
MOI.set(::Optimizer, ::MOI.Silent, bool = true) = @debug "TODO: Silent"

"""
    MOI.is_empty(model::Optimizer)

Check if the model is empty.

# Arguments
- `model::Optimizer`: The optimizer instance.

# Returns
- `Bool`: True if the model is empty, false otherwise.
"""
MOI.is_empty(model::Optimizer) = LS._is_empty(model.solver)

"""
    MOI.supports_incremental_interface(::Optimizer)

Check if the optimizer supports incremental interface.

# Arguments
- `::Optimizer`: The optimizer instance.

# Returns
- `Bool`: True if the optimizer supports incremental interface, false otherwise.
"""
MOI.supports_incremental_interface(::Optimizer) = true

"""
    MOI.copy_to(model::Optimizer, src::MOI.ModelLike)

Copy the source model to the optimizer.

# Arguments
- `model::Optimizer`: The optimizer instance.
- `src::MOI.ModelLike`: The source model to be copied.

# Returns
- `Nothing`
"""
function MOI.copy_to(model::Optimizer, src::MOI.ModelLike)
    return MOIU.default_copy_to(model, src)
end

"""
    MOI.optimize!(model::Optimizer)

Optimize the model using the optimizer.

# Arguments
- `model::Optimizer`: The optimizer instance.

# Returns
- `Nothing`
"""
MOI.optimize!(optimizer::Optimizer) = solve!(optimizer.solver)

"""
    DiscreteSet(values)

Create a discrete set of values.

# Arguments
- `values::Vector{T}`: A vector of values to include in the set.

# Returns
- `DiscreteSet{T}`: A discrete set containing the specified values.
"""
struct DiscreteSet{T <: Number} <: MOI.AbstractScalarSet
    values::Vector{T}
end
DiscreteSet(values) = DiscreteSet(collect(values))
DiscreteSet(values::T...) where {T <: Number} = DiscreteSet(collect(values))

"""
    Base.copy(set::DiscreteSet)

Copy a discrete set.

# Arguments
- `set::DiscreteSet`: The discrete set to be copied.

# Returns
- `DiscreteSet`: A copy of the discrete set.
"""
Base.copy(set::DiscreteSet) = DiscreteSet(copy(set.values))

"""
    MOI.empty!(opt)

Empty the optimizer.

# Arguments
- `opt::Optimizer`: The optimizer instance.

# Returns
- `Nothing`
"""
MOI.empty!(opt) = empty!(opt)

"""
    MOI.is_valid(optimizer::Optimizer, index::CI{VI, MOI.Integer})

Check if an index is valid for the optimizer.

# Arguments
- `optimizer::Optimizer`: The optimizer instance.
- `index::CI{VI, MOI.Integer}`: The index to be checked.

# Returns
- `Bool`: True if the index is valid, false otherwise.
"""
function MOI.is_valid(optimizer::Optimizer, index::CI{VI, MOI.Integer})
    return index.value ∈ optimizer.int_vars
end

"""
    Base.copy(op::F) where {F <: Function}

Copy a function.

# Arguments
- `op::F`: The function to be copied.

# Returns
- `F`: The copied function.
"""
Base.copy(op::F) where {F <: Function} = op

"""
    Base.copy(::Nothing)

Copy a `Nothing` value.

# Arguments
- `::Nothing`: The `Nothing` value to be copied.

# Returns
- `Nothing`: The copied `Nothing` value.
"""
Base.copy(::Nothing) = nothing

"""
    Moi.get(::Optimizer, ::MOI.SolverVersion)

Get the version of the solver, here `LocalSearchSolvers.jl`.
"""
function MOI.get(::Optimizer, ::MOI.SolverVersion)
    deps = Pkg.dependencies()
    local_search_solver_uuid = Base.UUID("2b10edaa-728d-4283-ac71-07e312d6ccf3")
    return "v" * string(deps[local_search_solver_uuid].version)
end

MOI.get(opt::Optimizer, ::MOI.NumberOfVariables) = LS.length_vars(opt)
