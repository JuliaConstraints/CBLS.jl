module CBLS

using ConstraintCommons
using ConstraintDomains
using Constraints
using Intervals
using JuMP
using Lazy
using LocalSearchSolvers
using MathOptInterface
using Pkg
using TestItems

# Const
const LS = LocalSearchSolvers
const MOI = MathOptInterface
const MOIU = MOI.Utilities

# MOI functions
const VOV = MOI.VectorOfVariables
const OF = MOI.ObjectiveFunction

# MOI indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# MOI types
const VAR_TYPES = Union{MOI.ZeroOne, MOI.Integer}

# Export: domain
export DiscreteSet

# Export: Constraints
export Error
export Intention, Predicate

export AllDifferent
export AllEqual
export Cardinality, CardinalityClosed, CardinalityOpen
export Channel
export Circuit
export Count, AtLeast, AtMost, Exactly
export Cumulative
export Element
export Extension, Supports, Conflicts
export Instantiation
export DistDifferent # Implementation of an intensional constraint
export Maximum
export MDDConstraint
export Minimum
export NValues
export NoOverlap#, NoOverlapNoZero, NoOverlapWithZero
export Ordered
export Regular
export Sum

#Export: Scalar objective function
export ScalarFunction

# Include
include("MOI_wrapper.jl")
include("attributes.jl")
include("variables.jl")

## Constraints
include("constraints.jl")
include("constraints/all_different.jl")
include("constraints/all_equal.jl")
include("constraints/cardinality.jl")
include("constraints/channel.jl")
include("constraints/circuit.jl")
include("constraints/count.jl")
include("constraints/cumulative.jl")
include("constraints/element.jl")
include("constraints/extension.jl")
include("constraints/instantiation.jl")
include("constraints/intention.jl")
include("constraints/maximum.jl")
include("constraints/mdd.jl")
include("constraints/minimum.jl")
include("constraints/n_values.jl")
include("constraints/no_overlap.jl")
include("constraints/ordered.jl")
include("constraints/regular.jl")
include("constraints/sum.jl")

include("objectives.jl")
include("results.jl")

end
