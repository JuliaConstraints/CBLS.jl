struct PrintLevel <: MOI.AbstractOptimizerAttribute end

MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.NumberOfThreads) = true

"""
    MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing,Float64})
Set the time limit
"""
function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing, Float64})
    set_option!(model, "time_limit", isnothing(value) ? Inf : value)
end
function MOI.get(model::Optimizer, ::MOI.TimeLimitSec)
    tl = get_option(model, "time_limit")
    return isinf(tl) ? nothing : tl
end

"""
    MOI.set(model::Optimizer, p::MOI.RawOptimizerAttribute, value)
Set a RawOptimizerAttribute to `value`
"""
MOI.set(model::Optimizer, p::MOI.RawOptimizerAttribute, value) = set_option!(
    model, p.name, value)
MOI.get(model::Optimizer, p::MOI.RawOptimizerAttribute) = get_option(model, p.name)

function MOI.set(model::Optimizer, ::MOI.NumberOfThreads, value::Int)
    set_option!(model, "threads", value)
end
function MOI.set(
        model::Optimizer, ::MOI.NumberOfThreads, value::Union{AbstractVector, AbstractDict})
    set_option!(model, "process_threads_map", value)
end

function MOI.get(model::Optimizer, ::MOI.NumberOfThreads)
    ptm = get_option(model, "process_threads_map")
    if length(ptm) == 0 || (haskey(ptm, 1) && length(ptm) == 1)
        nt = get_option(model, "threads")
        return nt == typemax(0) ? nothing : nt
    end
    return ptm
end
