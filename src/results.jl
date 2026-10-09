function MOI.get(opt::Optimizer, ::MOI.TerminationStatus)
    opt.optimized || return MOI.OPTIMIZE_NOT_CALLED
    ts = status(opt)
    ts == :infeasible && return MOI.INFEASIBLE
    ts == :iteration_limit && return MOI.ITERATION_LIMIT
    ts == :time_limit && return MOI.TIME_LIMIT
    ts == :solution_limit && return MOI.SOLUTION_LIMIT
    return has_solution(opt) ? MOI.LOCALLY_SOLVED : MOI.OTHER_LIMIT
end
MOI.get(opt::Optimizer, ::MOI.ResultCount) =
    Int(opt.optimized && status(opt) != :infeasible && has_solution(opt))
function MOI.get(opt::Optimizer, attr::MOI.PrimalStatus)
    return 1 <= attr.result_index <= MOI.get(opt, MOI.ResultCount()) ? MOI.FEASIBLE_POINT : MOI.NO_SOLUTION
end
MOI.get(::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION
function MOI.get(opt::Optimizer, attr::MOI.VariablePrimal, variable::VI)
    _valid!(opt, variable)
    MOI.check_result_index_bounds(opt, attr)
    return best_values(opt)[variable.value]
end
function MOI.get(opt::Optimizer, attr::MOI.ConstraintPrimal, index::CI)
    _valid!(opt, index)
    MOI.check_result_index_bounds(opt, attr)
    return MOIU.eval_variables(v -> best_values(opt)[v.value], opt.registry[index][1])
end
function MOI.get(opt::Optimizer, attr::MOI.ObjectiveValue)
    MOI.check_result_index_bounds(opt, attr)
    # JuMP's default model expects a Float64 result; keep native callback
    # arithmetic in _objective_value and convert only at the result boundary.
    return opt.objective_sense == MOI.FEASIBILITY_SENSE || isnothing(opt.objective) ?
        0.0 : Float64(_objective_value(opt.objective, best_values(opt)))
end
# A heuristic incumbent is not a proven global objective bound.
MOI.get(opt::Optimizer, ::MOI.ObjectiveBound) = opt.objective_sense == MOI.MAX_SENSE ? Inf : -Inf
MOI.get(opt::Optimizer, ::MOI.SolveTimeSec) = opt.optimized && status(opt) != :infeasible ? time_info(opt)[:total_run] : 0.0
MOI.get(opt::Optimizer, ::MOI.RawStatusString) = opt.optimized ? string(status(opt)) : "optimize not called"
