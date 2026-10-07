"Explicit supported constraint pairs; backend capabilities are checked as well."
struct FacadeContract{P<:Tuple}
    id::String
    version::String
    constraints::P
end
function FacadeContract(id::AbstractString, pairs::Tuple; version="1")
    for (F,S) in pairs
        F <: MOI.AbstractFunction && S <: MOI.AbstractSet || throw(ArgumentError("invalid MOI constraint pair"))
    end
    length(unique(pairs))==length(pairs) || throw(ArgumentError("duplicate MOI constraint pair"))
    FacadeContract(String(id),String(version),pairs)
end
abstract type AbstractStrategyOptimizer <: MOI.AbstractOptimizer end
struct StrategyOptimizer{B<:MOI.AbstractOptimizer,C<:FacadeContract,F} <: AbstractStrategyOptimizer
    backend::B
    contract::C
    configure::F
end
StrategyOptimizer(backend::MOI.AbstractOptimizer, contract::FacadeContract;configure=identity) =
    StrategyOptimizer(backend,contract,configure)

"Declare a named solver family using the shared protocol, with no per-HPO-value methods."
macro optimizer_family(name)
    name isa Symbol || throw(ArgumentError("optimizer family needs a type name"))
    esc(quote
        struct $name{B<:$(MOI.AbstractOptimizer),C<:$(FacadeContract),F} <: $(AbstractStrategyOptimizer)
            backend::B
            contract::C
            configure::F
        end
        $name(backend::$(MOI.AbstractOptimizer),contract::$(FacadeContract);configure=identity) =
            $name(backend,contract,configure)
    end)
end

MOI.supports_constraint(m::AbstractStrategyOptimizer,::Type{F},::Type{S}) where {F<:MOI.AbstractFunction,S<:MOI.AbstractSet} =
    (F,S) in m.contract.constraints && MOI.supports_constraint(m.backend,F,S)
function MOI.add_constraint(m::AbstractStrategyOptimizer,f::F,s::S) where {F<:MOI.AbstractFunction,S<:MOI.AbstractSet}
    MOI.supports_constraint(m,F,S) || throw(MOI.UnsupportedConstraint{F,S}())
    MOI.add_constraint(m.backend,f,s)
end
MOI.add_variable(m::AbstractStrategyOptimizer) = MOI.add_variable(m.backend)
MOI.supports_incremental_interface(m::AbstractStrategyOptimizer) = MOI.supports_incremental_interface(m.backend)
MOI.copy_to(m::AbstractStrategyOptimizer,src::MOI.ModelLike) = MOIU.default_copy_to(m,src)
MOI.empty!(m::AbstractStrategyOptimizer) = MOI.empty!(m.backend)
MOI.is_empty(m::AbstractStrategyOptimizer) = MOI.is_empty(m.backend)
MOI.is_valid(m::AbstractStrategyOptimizer,i::Union{VI,CI}) = MOI.is_valid(m.backend,i)
MOI.delete(m::AbstractStrategyOptimizer,i::Union{VI,CI}) = MOI.delete(m.backend,i)
MOI.delete(m::AbstractStrategyOptimizer,is::Vector{<:Union{VI,CI}}) = MOI.delete(m.backend,is)
MOI.modify(m::AbstractStrategyOptimizer,i::CI,change::MOI.AbstractFunctionModification) = MOI.modify(m.backend,i,change)
function MOI.optimize!(m::AbstractStrategyOptimizer)
    # Configuration runs outside the solver hot loop on the editable model.
    m.configure(m.backend)
    MOI.optimize!(m.backend)
end
MOI.get(m::AbstractStrategyOptimizer,::MOI.SolverName) = m.contract.id
for A in (MOI.AbstractOptimizerAttribute,MOI.AbstractModelAttribute)
    @eval begin
        MOI.get(m::AbstractStrategyOptimizer,a::$A) = MOI.get(m.backend,a)
        MOI.set(m::AbstractStrategyOptimizer,a::$A,value) = MOI.set(m.backend,a,value)
        MOI.supports(m::AbstractStrategyOptimizer,a::$A) = MOI.supports(m.backend,a)
    end
end
for (A,I) in ((MOI.AbstractVariableAttribute,VI),(MOI.AbstractConstraintAttribute,CI))
    @eval begin
        MOI.get(m::AbstractStrategyOptimizer,a::$A,i::$I) = MOI.get(m.backend,a,i)
        MOI.set(m::AbstractStrategyOptimizer,a::$A,i::$I,value) = MOI.set(m.backend,a,i,value)
        MOI.supports(m::AbstractStrategyOptimizer,a::$A,::Type{I}) where {I<:$I} = MOI.supports(m.backend,a,I)
    end
end
MOI.get(m::AbstractStrategyOptimizer,::Type{VI},name::String)=MOI.get(m.backend,VI,name)
MOI.get(m::AbstractStrategyOptimizer,::Type{I},name::String) where {I<:CI}=MOI.get(m.backend,I,name)
