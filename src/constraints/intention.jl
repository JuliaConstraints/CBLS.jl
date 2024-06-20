# Intention constraints emcompass any generic constraint. DistDifferent is implemented as an example of an intensional constraint.

"""
    MOIDistDifferent <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIDistDifferent <: MOI.AbstractVectorSet
    dimension::Int

    function MOIDistDifferent(dim = 4)
        return new(dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIDistDifferent})
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIDistDifferent)
    function e(x; kwargs...)
        return error_f(USUAL_CONSTRAINTS[:dist_different])(x)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIDistDifferent}(cidx)
end

function Base.copy(set::MOIDistDifferent)
    return MOIDistDifferent(copy(set.dimension))
end

"""
A constraint ensuring that the distances between marks on the ruler are unique. Specifically, it checks that the distance between `x[1]` and `x[2]`, and the distance between `x[3]` and `x[4]`, are different. This constraint is fundamental in ensuring the validity of a Golomb ruler, where no two pairs of marks should have the same distance between them.
"""
struct DistDifferent <: JuMP.AbstractVectorSet end

function JuMP.moi_set(::DistDifferent, dim::Int)
    return MOIDistDifferent(dim)
end

## SECTION - Test Items
@testitem "Dist different (intension)" tags=[:usual, :constraints, :intension] begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:4]≤6, Int)

    @constraint(model, X in DistDifferent())

    optimize!(model)
    @info "Dist different (intension)" value.(X)
    termination_status(model)
    @info solution_summary(model)
end
