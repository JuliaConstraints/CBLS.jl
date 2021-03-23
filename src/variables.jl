
"""
    MOI.add_variable(model::Optimizer) = begin

DOCSTRING
"""
MOI.add_variable(model::Optimizer) = VI(variable!(model))
MOI.add_variables(model::Optimizer, n::Int) = [MOI.add_variable(model) for i in 1:n]

MOI.supports_constraint(::Optimizer, ::Type{SVF}) = true

function MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{MOI.EqualTo{T}}
) where {T <: Real}
    return true
end

function MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{MOI.Interval{T}}
) where {T <: Real}
    return true
end

function MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{MOI.LessThan{T}}
) where {T <: Real}
    return true
end

function MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{MOI.GreaterThan{T}}
) where {T <: Real}
    return true
end

MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{DiscreteSet{T}}) where {T <: Number} = true

"""
    MOI.add_constraint(optimizer::Optimizer, v::SVF, set::DiscreteSet{T}) where T <: Number

DOCSTRING

# Arguments:
- `optimizer`: DESCRIPTION
- `v`: DESCRIPTION
- `set`: DESCRIPTION
"""
function MOI.add_constraint(optimizer::Optimizer, v::SVF, set::DiscreteSet{T}
) where {T <: Number}
    vidx = MOI.index_value(v.variable)
    _set_domain!(optimizer, vidx, set.values)
    return CI{SVF,DiscreteSet{T}}(vidx)
end

function MOI.add_constraint(optimizer::Optimizer, v::SVF, lt::MOI.LessThan{T}
) where {T <: AbstractFloat}
    vidx = MOI.index_value(v.variable)
    a = (-Inf, false)
    b = (lt.upper, true)
    _set_domain!(optimizer, vidx, a, b)
    return CI{SVF,MOI.LessThan{T}}(vidx)
end

function MOI.add_constraint(optimizer::Optimizer, v::SVF, gt::MOI.GreaterThan{T}
) where {T <: AbstractFloat}
    vidx = MOI.index_value(v.variable)
    a = (gt.upper, true)
    b = (Inf, false)
    _set_domain!(optimizer, vidx, a, b)
    return CI{SVF,MOI.GreaterThan{T}}(vidx)
end

make_set_domain(opt, id, a, b, ::Val{:range}) = _set_domain!(opt, id, a:b)
make_set_domain(opt, id, a, b, ::Val{:inter}) = _set_domain!(opt, id, (a, true), (b, true))

function MOI.add_constraint(optimizer::Optimizer, v::SVF, i::MOI.Interval{T}
) where {T <: Real}
    @info "interval MOI " i
    vidx = MOI.index_value(v.variable)
    @warn "test index"  MOI.is_valid(optimizer, CI{SVF, MOI.Integer}(vidx))
    is_int = MOI.is_valid(optimizer, CI{SVF, MOI.Integer}(vidx))
    make_set_domain(optimizer, vidx, i.lower, i.upper, Val(is_int ? :range : :inter))
    return CI{SVF,MOI.Interval{T}}(vidx)
end

function MOI.add_constraint(optimizer::Optimizer, v::SVF, et::MOI.EqualTo{T}
) where {T <: Number}
    vidx = MOI.index_value(v.variable)
    _set_domain!(optimizer, vidx, et.value)
    return CI{SVF,MOI.EqualTo{T}}(vidx)
end

"""
Binary/Integer variable support
"""
# MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{<:VAR_TYPES}) = true
MOI.supports_constraint(::Optimizer, ::Type{SVF}, ::Type{<:MOI.Integer}) = true

function MOI.add_constraint(optimizer::Optimizer, v::SVF, ::MOI.Integer)
    vidx = MOI.index_value(v.variable)
    push!(optimizer.int_vars, vidx)
    @info "integer " v MOI.ConstraintIndex{SVF,MOI.Integer}(vidx)
    return MOI.ConstraintIndex{SVF,MOI.Integer}(vidx)
end
