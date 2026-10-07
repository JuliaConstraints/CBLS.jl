struct PrintLevel <: MOI.AbstractOptimizerAttribute end

MOI.supports(::Optimizer, ::MOI.RawOptimizerAttribute) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.NumberOfThreads) = true

"""
    MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing,Float64})
Set the time limit
"""
@optimizer_edit function MOI.set(model::Optimizer, ::MOI.TimeLimitSec, value::Union{Nothing, Float64})
    set_option!(model, "time_limit", isnothing(value) ? Inf : value)
end

_attribute_value(value::Tuple{Bool, T}) where {T} = last(value)
_attribute_value(value) = value

function MOI.get(model::Optimizer, ::MOI.TimeLimitSec)
    tl = _attribute_value(get_option(model, "time_limit"))
    return isinf(tl) ? nothing : tl
end

"""
    MOI.set(model::Optimizer, p::MOI.RawOptimizerAttribute, value)
Set a RawOptimizerAttribute to `value`
"""
@optimizer_edit function MOI.set(model::Optimizer, p::MOI.RawOptimizerAttribute, value)
    set_option!(
        model, p.name, value)
end
function MOI.get(model::Optimizer, p::MOI.RawOptimizerAttribute)
    _attribute_value(get_option(model, p.name))
end

@optimizer_edit function MOI.set(model::Optimizer, ::MOI.NumberOfThreads, value::Int)
    value > 0 || throw(ArgumentError("NumberOfThreads must be positive"))
    set_option!(model, "threads", value)
end
@optimizer_edit function MOI.set(model::Optimizer, ::MOI.NumberOfThreads, ::Nothing)
    set_option!(model,"threads",typemax(Int))
end
@optimizer_edit function MOI.set(
        model::Optimizer, ::MOI.NumberOfThreads, value::Union{AbstractVector, AbstractDict})
    set_option!(model, "process_threads_map", value)
end

function MOI.get(model::Optimizer, ::MOI.NumberOfThreads)
    ptm = _attribute_value(get_option(model, "process_threads_map"))
    if length(ptm) == 0 || (haskey(ptm, 1) && length(ptm) == 1)
        nt = _attribute_value(get_option(model, "threads"))
        return nt == typemax(0) ? nothing : nt
    end
    return ptm
end

@testitem "MOI optimizer attributes expose public values" default_imports = false begin
    import CBLS
    import MathOptInterface as MOI
    import Test: @test

    model = CBLS.Optimizer()

    iterations = MOI.RawOptimizerAttribute("iteration")
    MOI.set(model, iterations, 100)
    @test MOI.get(model, iterations) == 100

    MOI.set(model, MOI.TimeLimitSec(), 5.0)
    @test MOI.get(model, MOI.TimeLimitSec()) == 5.0

    MOI.set(model, MOI.TimeLimitSec(), nothing)
    @test isnothing(MOI.get(model, MOI.TimeLimitSec()))
end
