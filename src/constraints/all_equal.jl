"""
    MOIAllEqual <: MOI.AbstractVectorSet

DOCSTRING
"""
struct MOIAllEqual <: MOI.AbstractVectorSet
    dimension::Int

    MOIAllEqual(dim=0) = new(dim)
end
MOI.supports_constraint(::Optimizer, ::Type{VOV}, ::Type{MOIAllEqual}) = true
function MOI.add_constraint(optimizer::Optimizer, vars::MOI.VectorOfVariables, ::MOIAllEqual)
    #max_dom_size = max_domains_size(optimizer, map(x -> x.value, vars.variables))
    e = (x; kargs...) -> error_f(
        USUAL_CONSTRAINTS[:all_equal])(x; kargs...)
    cidx = constraint!(optimizer, e, map(x -> x.value, vars.variables))
    return CI{VOV,MOIAllEqual}(cidx)
end

Base.copy(set::MOIAllEqual) = MOIAllEqual(copy(set.dimension))

"""
Global constraint ensuring that all the values of `X` are all equal.

```julia
@constraint(model, X in AllEqual())
```
"""
struct AllEqual <: JuMP.AbstractVectorSet end
JuMP.moi_set(::AllEqual, dim::Int) = MOIAllEqual(dim)
