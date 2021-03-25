
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

# function MOI.add_constraint(optimizer::Optimizer, v::SVF, lt::MOI.LessThan{T}
# ) where {T <: AbstractFloat}
#     vidx = MOI.index_value(v.variable)
#     d = make_domain(typemin(Int), lt.upper, Val(:range))
#     update_domain!(optimizer, vidx, d)
#     return CI{SVF,MOI.LessThan{T}}(vidx)
# end

# function MOI.add_constraint(optimizer::Optimizer, v::SVF, gt::MOI.GreaterThan{T}
# ) where {T <: AbstractFloat}
#     vidx = MOI.index_value(v.variable)
#     d = make_domain(gt.lower, typemax(Int), Val(:range))
#     update_domain!(optimizer, vidx, d)
#     return CI{SVF,MOI.GreaterThan{T}}(vidx)
# end

# make_domain(a, b, ::Val{:range}) = domain(Int(a):Int(b))
# make_domain(a, b, ::Val{:inter}) = domain((a, true), (b, true))

function MOI.add_constraint(optimizer::Optimizer, v::SVF, lt::MOI.LessThan{T}
    ) where {T <: AbstractFloat}
        vidx = MOI.index_value(v.variable)
        if MOI.is_valid(optimizer, CI{SVF, MOI.Integer}(vidx))
            d = make_domain(typemin(Int), lt.upper, Val(:range))
        else
            a = (-Inf, false)
            b = (lt.upper, true)
            d = make_domain(a, b, Val(:inter))
        end
        update_domain!(optimizer, vidx, d)
        return CI{SVF,MOI.LessThan{T}}(vidx)
    end
    
    function MOI.add_constraint(optimizer::Optimizer, v::SVF, gt::MOI.GreaterThan{T}
    ) where {T <: AbstractFloat}
        vidx = MOI.index_value(v.variable)
        @info "is_int" MOI.is_valid(optimizer, CI{SVF, MOI.Integer}(vidx))
        if MOI.is_valid(optimizer, CI{SVF, MOI.Integer}(vidx))
            d = make_domain(gt.lower, typemax(Int), Val(:range))
        else
            a = (gt.lower, true)
            b = (Inf, false)
            d = make_domain(a, b, Val(:inter))
        end
        update_domain!(optimizer, vidx, d)
        return CI{SVF,MOI.GreaterThan{T}}(vidx)
    end
    
    make_domain(a, b, ::Val{:range}) = domain(Int(a):Int(b))
    make_domain(a::Real, b::Real, ::Val{:inter}) = domain((a, true), (b, true))
    make_domain(a::Tuple, b::Tuple, ::Val{:inter}) = domain(a, b)


function MOI.add_constraint(optimizer::Optimizer, v::SVF, i::MOI.Interval{T}
) where {T <: Real}
    vidx = MOI.index_value(v.variable)
    is_int = MOI.is_valid(optimizer, CI{SVF, MOI.Integer}(vidx))
    d = make_domain(i.lower, i.upper, Val(is_int ? :range : :inter))
    _set_domain!(optimizer, vidx, d)
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
    return MOI.ConstraintIndex{SVF,MOI.Integer}(vidx)
end
