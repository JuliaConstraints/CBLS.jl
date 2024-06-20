"""
    MOIMultivaluedDecisionDiagram{L <: ConstraintCommons.AbstractMultivaluedDecisionDiagram} <: AbstractVectorSet

DOCSTRING
"""
struct MOIMultivaluedDecisionDiagram{L <:
                                     ConstraintCommons.AbstractMultivaluedDecisionDiagram} <:
       MOI.AbstractVectorSet
    language::L
    dimension::Int

    function MOIMultivaluedDecisionDiagram(language, dim = 0)
        return new{typeof(language)}(language, dim)
    end
end

function MOI.supports_constraint(::Optimizer,
        ::Type{VOV},
        ::Type{MOIMultivaluedDecisionDiagram{L}}) where {L <:
                                                         ConstraintCommons.AbstractMultivaluedDecisionDiagram}
    return true
end

function MOI.add_constraint(
        optimizer::Optimizer, vars::MOI.VectorOfVariables, set::MOIMultivaluedDecisionDiagram)
    function e(x; kwargs...)
        new_kwargs = merge(kwargs, Dict(:language => set.language))
        return error_f(USUAL_CONSTRAINTS[:mdd])(x; new_kwargs...)
    end
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV, MOIMultivaluedDecisionDiagram{typeof(set.language)}}(cidx)
end

function Base.copy(set::MOIMultivaluedDecisionDiagram)
    return MOIMultivaluedDecisionDiagram(deepcopy(set.language), copy(set.dimension))
end

"""
Multi-valued Decision Diagram (MDD) constraint.

The MDD constraint is a constraint that can be used to model a wide range of problems. It is a directed graph where each node is labeled with a value and each edge is labeled with a value. The constraint is satisfied if there is a path from the first node to the last node such that the sequence of edge labels is a valid sequence of the value labels.

```julia
@constraint(model, X in MDDConstraint(; language))
```
"""
struct MDDConstraint{L <: ConstraintCommons.AbstractMultivaluedDecisionDiagram} <:
       JuMP.AbstractVectorSet
    language::L

    function MDDConstraint(; language)
        return new{typeof(language)}(language)
    end
end

function JuMP.moi_set(set::MDDConstraint, dim::Int)
    return MOIMultivaluedDecisionDiagram(set.language, dim)
end

## SECTION - Test Items for MDD
@testitem "MDD" tags=[:usual, :constraints, :mdd] default_imports=false begin
    using CBLS
    using JuMP

    import ConstraintCommons: MDD

    model = Model(CBLS.Optimizer)

    states = [
        Dict( # level x1
            (:r, 0) => :n1,
            (:r, 1) => :n2,
            (:r, 2) => :n3
        ),
        Dict( # level x2
            (:n1, 2) => :n4,
            (:n2, 2) => :n4,
            (:n3, 0) => :n5
        ),
        Dict( # level x3
            (:n4, 0) => :t,
            (:n5, 0) => :t
        )
    ]

    @variable(model, 0≤X[1:3]≤2, Int)

    @constraint(model, X in MDDConstraint(; language = MDD(states)))

    optimize!(model)
    @info "MDD" value.(X)
    termination_status(model)
    @info solution_summary(model)
end
