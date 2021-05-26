struct PrintLevel <: MOI.AbstractOptimizerAttribute end

MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.NumberOfThreads) = true

"""
    MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing,Float64})
Set the time limit
"""
function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing,Float64})
    set_option!(model, "time_limit", isnothing(value) ? Inf : value)
end
function MOI.get(model::Optimizer, ::MOI.TimeLimitSec)
    tl = get_option(model, "time_limit")
    return isinf(tl) ? nothing : tl
end

"""
    MOI.set(model::Optimizer, p::MOI.RawParameter, value)
Set a RawParameter to `value`
"""
MOI.set(model::Optimizer, p::MOI.RawParameter, value) = set_option!(model, p.name, value)
MOI.get(model::Optimizer, p::MOI.RawParameter) = get_option(model, p.name)


function MOI.set(model::Optimizer, ::MOI.NumberOfThreads, value)
    set_option!(model, "threads", isnothing(value) ? typemax(0) : value)
end
function MOI.get(model::Optimizer, ::MOI.NumberOfThreads)
    nt = get_option(model, "threads")
    return nt == typemax(0) ? nothing : nt
end