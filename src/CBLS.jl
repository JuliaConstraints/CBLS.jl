module CBLS

using Constraints
using ConstraintDomains
using Intervals
using JuMP
using Lazy
using LocalSearchSolvers
using MathOptInterface
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
export AllDifferent
export AllEqual
export Cardinality
export CardinalityClosed
export CardinalityOpen
export Channel
export Circuit

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

include("objectives.jl")
include("results.jl")

end
