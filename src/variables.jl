
"""
    MOI.add_variable(model::Optimizer) = begin

DOCSTRING
"""
MOI.add_variable(model::Optimizer) = VI(variable!(model))
MOI.add_variables(model::Optimizer, n::Int) = [MOI.add_variable(model) for _ in 1:n]

MOI.supports_constraint(::Optimizer, ::Type{VI}) = true

function MOI.supports_constraint(::Optimizer, ::Type{VI}, ::Type{MOI.EqualTo{T}}
) where {T <: Real}
    return true
end

function MOI.supports_constraint(::Optimizer, ::Type{VI}, ::Type{MOI.Interval{T}}
) where {T <: Real}
    return true
end

function MOI.supports_constraint(::Optimizer, ::Type{VI}, ::Type{MOI.LessThan{T}}
) where {T <: Real}
    return true
end

function MOI.supports_constraint(::Optimizer, ::Type{VI}, ::Type{MOI.GreaterThan{T}}
) where {T <: Real}
    return true
end

function MOI.supports_constraint(
        ::Optimizer, ::Type{VI}, ::Type{DiscreteSet{T}}) where {T <: Number}
    true
end

"""
    MOI.add_constraint(optimizer::Optimizer, v::VI, set::DiscreteSet{T}) where T <: Number

DOCSTRING

# Arguments:
- `optimizer`: DESCRIPTION
- `v`: DESCRIPTION
- `set`: DESCRIPTION
"""
function MOI.add_constraint(optimizer::Optimizer, v::VI, set::DiscreteSet{T}
) where {T <: Number}
    vidx = v.value
    _set_domain!(optimizer, vidx, set.values)
    return CI{VI, DiscreteSet{T}}(vidx)
end

# function MOI.add_constraint(optimizer::Optimizer, v::VI, lt::MOI.LessThan{T}
# ) where {T <: AbstractFloat}
#     vidx = v.value
#     d = make_domain(typemin(Int), lt.upper, Val(:range))
#     update_domain!(optimizer, vidx, d)
#     return CI{VI,MOI.LessThan{T}}(vidx)
# end

# function MOI.add_constraint(optimizer::Optimizer, v::VI, gt::MOI.GreaterThan{T}
# ) where {T <: AbstractFloat}
#     vidx = v.value
#     d = make_domain(gt.lower, typemax(Int), Val(:range))
#     update_domain!(optimizer, vidx, d)
#     return CI{VI,MOI.GreaterThan{T}}(vidx)
# end

# make_domain(a, b, ::Val{:range}) = domain(Int(a):Int(b))
# make_domain(a, b, ::Val{:inter}) = domain((a, true), (b, true))

function MOI.add_constraint(optimizer::Optimizer, v::VI, lt::MOI.LessThan{T}
) where {T <: AbstractFloat}
    vidx = v.value
    push!(optimizer.compare_vars, vidx)
    if vidx ∈ optimizer.int_vars
        d = domain(Int(typemin(Int)), Int(lt.upper))
    else
        a = Float64(-floatmax(Float32))
        d = domain(Interval{Open, Closed}(a, lt.upper))
    end
    update_domain!(optimizer, vidx, d)
    return CI{VI, MOI.LessThan{T}}(vidx)
end

function MOI.add_constraint(optimizer::Optimizer, v::VI, gt::MOI.GreaterThan{T}
) where {T <: AbstractFloat}
    vidx = v.value
    push!(optimizer.compare_vars, vidx)
    if vidx ∈ optimizer.int_vars
        d = domain(Int(gt.lower):Int(typemax(Int)))
    else
        b = Float64(floatmax(Float32))
        d = domain(Interval{Closed, Open}(gt.lower, b))
    end
    update_domain!(optimizer, vidx, d)
    return CI{VI, MOI.GreaterThan{T}}(vidx)
end

function MOI.add_constraint(optimizer::Optimizer, v::VI, i::MOI.Interval{T}
) where {T <: Real}
    vidx = v.value
    is_int = MOI.is_valid(optimizer, CI{VI, MOI.Integer}(vidx))
    d = make_domain(i.lower, i.upper, Val(is_int ? :range : :inter))
    _set_domain!(optimizer, vidx, d)
    return CI{VI, MOI.Interval{T}}(vidx)
end

function MOI.add_constraint(optimizer::Optimizer, v::VI, et::MOI.EqualTo{T}
) where {T <: Number}
    vidx = v.value
    _set_domain!(optimizer, vidx, et.value)
    return CI{VI, MOI.EqualTo{T}}(vidx)
end

"""
Binary/Integer variable support
"""
# MOI.supports_constraint(::Optimizer, ::Type{VI}, ::Type{<:VAR_TYPES}) = true
MOI.supports_constraint(::Optimizer, ::Type{VI}, ::Type{<:MOI.Integer}) = true

function MOI.add_constraint(optimizer::Optimizer, v::VI, ::MOI.Integer)
    vidx = v.value
    push!(optimizer.int_vars, vidx)
    if vidx ∈ optimizer.compare_vars
        x = get_variable(optimizer, vidx)
        _set_domain!(optimizer, vidx, convert(RangeDomain, x.domain))
    end
    return MOI.ConstraintIndex{VI, MOI.Integer}(vidx)
end
