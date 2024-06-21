"""
    MOIRegular{L <: ConstraintCommons.AbstractAutomaton} <: AbstractVectorSet

DOCSTRING
"""
struct MOIRegular{L <: ConstraintCommons.AbstractAutomaton} <: MOI.AbstractVectorSet
    language::L
    dimension::Int

    function MOIRegular(language, dim = 0)
        return new{typeof(language)}(language, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIRegular{L}}) where {L <: ConstraintCommons.AbstractAutomaton}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIRegular)
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:language => set.language))
        return error_f(USUAL_CONSTRAINTS[:regular])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIRegular{typeof(set.language)}}(cidx)
end

function Base.copy(set::MOIRegular)
    return MOIRegular(deepcopy(set.language), copy(set.dimension))
end

"""
Ensures that a sequence `x` (interpreted as a word) is accepted by the regular language represented by a given automaton. This constraint verifies the compliance of `x` with the language rules encoded within the `automaton` parameter, which must be an instance of `<:AbstractAutomaton`.

```julia
@constraint(model, X in RegularConstraint(; language))
```
"""
struct Regular{L <: ConstraintCommons.AbstractAutomaton} <: JuMP.AbstractVectorSet
    language::L

    function Regular(; language)
        return new{typeof(language)}(language)
    end
end

function JuMP.moi_set(set::Regular, dim::Int)
    return MOIRegular(set.language, dim)
end

## SECTION - Test Items for Regular
@testitem "Regular" tags=[:usual, :constraints, :regular] default_imports=false begin
    using CBLS
    using JuMP

    import ConstraintCommons: Automaton

    states = Dict(
        (:a, 0) => :a,
        (:a, 1) => :b,
        (:b, 1) => :c,
        (:c, 0) => :d,
        (:d, 0) => :d,
        (:d, 1) => :e,
        (:e, 0) => :e
    )
    start = :a
    finish = :e
    a = Automaton(states, start, finish)

    model = Model(CBLS.Optimizer)

    @variable(model, 0≤X[1:9]≤1, Int)
    @constraint(model, X in Regular(; language = a))

    optimize!(model)
    @info "Regular" value.(X)
    termination_status(model)
    @info solution_summary(model)
end
