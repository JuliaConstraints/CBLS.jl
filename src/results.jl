MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus) = optimizer.status

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    return is_sat(optimizer) ? _values(optimizer) : _solution(optimizer)
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

# function set_status!(optimizer::Optimizer, status::Symbol)
#     if status == :Solved
#         optimizer.status = MOI.OPTIMAL
#     elseif status == :Infeasible
#         optimizer.status = MOI.INFEASIBLE
#     elseif status == :Time
#         optimizer.status = MOI.TIME_LIMIT
#     else
#         optimizer.status = MOI.OTHER_LIMIT
#     end
# end

MOI.get(optimizer::Optimizer, ::MOI.SolveTime) = time_info(optimizer)[:total_run]