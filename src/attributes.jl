struct PrintLevel <: MOI.AbstractOptimizerAttribute end

MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true

"""
    MOI.set(model::Optimizer, ::MOI.RawParameter, value)
Set the time limit
"""
function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing,Float64})
    set_option!(model, "time_limit", value === nothing ? Inf : value)
end
MOI.get(model::Optimizer, ::MOI.TimeLimitSec) = get_option(model, "time_limit")

"""
    MOI.set(model::Optimizer, p::MOI.RawParameter, value)
Set a RawParameter to `value`
"""
MOI.set(model::Optimizer, p::MOI.RawParameter, value) = set_option!(model, p.name, value)
MOI.get(model::Optimizer, p::MOI.RawParameter) = get_option(model, p.name)
