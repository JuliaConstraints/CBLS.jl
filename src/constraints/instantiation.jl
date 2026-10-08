"""
    MOIInstantiation{T <: Number, V <: Vector{T}} <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIInstantiation{T <: Number, V <: Vector{T}} <:
       MOI.AbstractVectorSet
    pair_vars::V
    dimension::Int

    function MOIInstantiation(pair_vars, dim = 0)
        return new{eltype(pair_vars), typeof(pair_vars)}(pair_vars, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIInstantiation{T, V}}) where {
        T <: Number, V <: Vector{T}}
    return true
end

function _add_constraint_backend!(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIInstantiation)
    e = FixedKeywordError(error_f(USUAL_CONSTRAINTS[:instantiation]),(;pair_vars=set.pair_vars))
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIInstantiation{eltype(set.pair_vars), typeof(set.pair_vars)}}(cidx)
end

function Base.copy(set::MOIInstantiation)
    return MOIInstantiation(deepcopy(set.pair_vars), copy(set.dimension))
end

"""
The instantiation constraint is a global constraint used in constraint programming that ensures that a list of variables takes on a specific set of values in a specific order.
"""
struct Instantiation{T <: Number, V <: Vector{T}} <: JuMP.AbstractVectorSet
    pair_vars::V

    function Instantiation(; pair_vars)
        return new{eltype(pair_vars), typeof(pair_vars)}(pair_vars)
    end
end

function JuMP.moi_set(set::Instantiation, dim::Int)
    return MOIInstantiation(set.pair_vars, dim)
end

## SECTION - Test Items
@testitem "Instantiation" tags=[:usual, :constraints, :instantiation] default_imports=false begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:5]≤6, Int)
    @variable(model, 1≤Y[1:5]≤6, Int)

    @constraint(model, X in Instantiation(; pair_vars = [1, 2, 3, 4, 5]))
    @constraint(model, Y in Instantiation(; pair_vars = [1, 2, 3, 4, 6]))

    optimize!(model)
    @info "Instantiation" value.(X) value.(Y)
    termination_status(model)
    @info solution_summary(model)
end
