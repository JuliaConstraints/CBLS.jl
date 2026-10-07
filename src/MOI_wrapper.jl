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
    backend_model::LS._Model
    int_vars::Set{Int}
    compare_vars::Set{Int}
    registry::Dict{Any, Tuple{Any, Any}}
    variable_names::Dict{VI, String}
    constraint_names::Dict{Any, String}
    objective::Any
    objective_sense::MOI.OptimizationSense
    model_name::String
    silent::Bool
    optimized::Bool
    lifecycle::LS.ModelLifecycle
end

"Serialize edits with preparation and reject them during optimization."
macro optimizer_edit(def)
    signature=def.args[1]
    signature.head==:where && (signature=signature.args[1])
    firstarg=signature.args[2]
    variable=firstarg isa Symbol ? firstarg : firstarg.args[1]
    body=def.args[2]
    def.args[2]=:(LS._edit_model!(() -> LS._edit_model!(() -> $body,$variable.backend_model),$variable))
    esc(def)
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
    initial_objective = LS.is_sat(model) ? nothing : ScalarFunction(LS.get_objective(model, 1).f)
    initial_sense = isnothing(initial_objective) ? MOI.FEASIBILITY_SENSE :
        LS.sense(model) == 1 ? MOI.MIN_SENSE : MOI.MAX_SENSE
    return Optimizer(
        solver(model, options = options),
        model,
        Set{Int}(),
        Set{Int}(), Dict{Any, Tuple{Any, Any}}(), Dict{VI, String}(), Dict{Any, String}(),
        initial_objective, initial_sense, "", false, false,LS.ModelLifecycle()
    )
end

# forward functions from Solver
@forward Optimizer.solver LS.variable!, LS._set_domain!, LS.constraint!, LS.solution
@forward Optimizer.solver LS.max_domains_size, LS.objective!, LS._inc_cons!
@forward Optimizer.solver LS._best_bound, LS.best_value, LS.is_sat, LS.get_value
@forward Optimizer.solver LS.domain_size, LS.best_values, LS._max_cons, LS.update_domain!
@forward Optimizer.solver LS.get_variable, LS.has_solution, LS.sense, LS.sense!
@forward Optimizer.solver LS.time_info, LS.status, LS.length_vars

# forward functions from Solver (from Options)
@forward Optimizer.solver LS.set_option!, LS.get_option

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
@optimizer_edit function MOI.set(opt::Optimizer, ::MOI.Silent, value::Bool)
    opt.silent = value
    set_option!(opt, "print_level", value ? :silent : :minimal)
    set_option!(opt, "log_mode", value ? :silent : :minimal)
    return nothing
end
MOI.supports(::Optimizer, ::MOI.Silent) = true
MOI.get(opt::Optimizer, ::MOI.Silent) = opt.silent

"""
    MOI.is_empty(model::Optimizer)

Check if the model is empty.

# Arguments
- `model::Optimizer`: The optimizer instance.

# Returns
- `Bool`: True if the model is empty, false otherwise.
"""
MOI.is_empty(model::Optimizer) = LS._is_empty(model.solver) && isempty(model.registry) &&
    isnothing(model.objective) && model.objective_sense == MOI.FEASIBILITY_SENSE && isempty(model.model_name)

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
function MOI.optimize!(optimizer::Optimizer)
    lease=LS._lease_model!(optimizer;exclusive=true)
    backend_lease=nothing
    try
        backend_lease=LS._lease_model!(optimizer.backend_model;exclusive=true)
        _optimize_owned!(optimizer)
    finally
        backend_lease===nothing || LS._release_model!(backend_lease)
        LS._release_model!(lease)
    end
end
function _optimize_owned!(optimizer::Optimizer)
    optimizer.optimized = false
    # Preserve the editable model across solver specialization and repeated runs.
    for variable in MOI.get(optimizer, MOI.ListOfVariableIndices())
        d = _variable_domain(optimizer, variable)
        if isnothing(d)
            isempty(LS.get_variable(optimizer.backend_model, variable.value)) &&
                throw(ArgumentError("CBLS requires an explicit finite domain for variable $(variable.value)"))
        elseif isempty(d)
            optimizer.solver = LS.solver(optimizer.backend_model; options = optimizer.solver.options,
                strategies = optimizer.solver.strategies)
            optimizer.solver.status = :infeasible
            optimizer.optimized = true
            return nothing
        end
    end
    search_model = deepcopy(optimizer.backend_model)
    _prepare_xcsp3_domains!(optimizer, search_model)
    optimizer.solver = LS.solver(search_model;
        options = optimizer.solver.options, strategies = deepcopy(optimizer.solver.strategies))
    solve!(optimizer.solver)
    optimizer.optimized = true
    return nothing
end

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
DiscreteSet(first::T,rest::T...) where {T <: Number} = DiscreteSet(T[first,rest...])

function JuMP.build_variable(::Function, info::JuMP.VariableInfo, set::DiscreteSet)
    return JuMP.VariableConstrainedOnCreation(JuMP.ScalarVariable(info), set)
end

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
@optimizer_edit function MOI.empty!(opt::Optimizer)
    opt.backend_model = LS.model()
    opt.solver = LS.solver(opt.backend_model; options = opt.solver.options,
        strategies = opt.solver.strategies)
    empty!(opt.int_vars)
    empty!(opt.compare_vars)
    empty!(opt.registry)
    empty!(opt.variable_names)
    empty!(opt.constraint_names)
    opt.objective = nothing
    opt.objective_sense = MOI.FEASIBILITY_SENSE
    opt.model_name = ""
    opt.optimized = false
    return nothing
end
Base.empty!(opt::Optimizer) = MOI.empty!(opt)

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
    return haskey(optimizer.registry, index)
end

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
