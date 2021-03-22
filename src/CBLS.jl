module CBLS

using Constraints
using JuMP
using Lazy
using LocalSearchSolvers
using MathOptInterface

# Const
const LS = LocalSearchSolvers
const MOI = MathOptInterface
const MOIU = MOI.Utilities

# MOI functions
const SVF = MOI.SingleVariable
const VOV = MOI.VectorOfVariables
const OF = MOI.ObjectiveFunction

# MOI indices
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex

# MOI types
const VAR_TYPES = Union{MOI.ZeroOne, MOI.Integer}

# Export
export DiscreteSet, Predicate, Error, ScalarFunction, AllDifferent, AllEqual
export AllEqualParam, Eq, DistDifferent, AlwaysTrue, Ordered
# export CBLS

# Include
include("MOI_wrapper.jl")
include("attributes.jl")
include("variables.jl")
include("constraints.jl")
include("objectives.jl")
include("results.jl")

end
