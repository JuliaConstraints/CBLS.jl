function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    TS = MOI.OPTIMIZE_NOT_CALLED
    ts = status(optimizer)
    if ts == :iteration_limit
        TS = MOI.ITERATION_LIMIT
    elseif ts == :time_limit
        TS = MOI.TIME_LIMIT
    elseif ts == :solution_limit
        TS = MOI.SOLUTION_LIMIT
    end
    return TS
end

function MOI.get(optimizer::Optimizer, ::MOI.PrimalStatus)
    return has_solution(optimizer) ? MOI.FEASIBLE_POINT : MOI.NO_SOLUTION
end

MOI.get(::Optimizer, ::MOI.DualStatus) = MOI.NO_SOLUTION

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    return is_sat(optimizer) ? 0 : best_value(optimizer)
end

MOI.get(optimizer::Optimizer, ::MOI.ObjectiveBound) = _best_bound(optimizer)
MOI.get(optimizer::Optimizer, ::MOI.ResultCount) = 1

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex)
    if has_solution(optimizer)
        return best_values(optimizer)[vi.value]
    else
        return get_value(optimizer, vi.value)
    end
end

MOI.get(optimizer::Optimizer, ::MOI.SolveTimeSec) = time_info(optimizer)[:total_run]

function MOI.get(optimizer::Optimizer, ::MOI.RawStatusString)
    return has_solution(optimizer) ? "Satisfying solution" : "No solutions"
end
