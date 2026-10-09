"Bounded reporting-only fixtures; model construction and solving are outside the measured operation."
module ObjectiveValueScenarios

import CBLS
import MathOptInterface as MOI

struct Fixture{A,T}
    optimizer::CBLS.Optimizer
    output::A
    raw::T
end

function fixture(kind::Symbol; retained=true, repetitions=128)
    repetitions > 0 || throw(ArgumentError("positive repetitions required"))
    opt = CBLS.Optimizer()
    MOI.set(opt, MOI.Silent(), true)
    MOI.set(opt, MOI.NumberOfThreads(), 1)
    MOI.set(opt, MOI.RawOptimizerAttribute("iteration"), 2)
    MOI.set(opt, MOI.TimeLimitSec(), 2.0)
    x = MOI.add_variables(opt, 2)
    for (i, variable) in enumerate(x)
        MOI.add_constraint(opt, variable, MOI.Integer())
        MOI.add_constraint(opt, variable, MOI.EqualTo(Float64(i)))
    end
    raw, callback = if kind === :qap
        W = [0 2; 3 0]
        D = [0 5; 7 0]
        (Int64(31), v -> sum(sum(W[v[i], v[j]] * D[i, j] for j in 1:2) for i in 1:2))
    elseif kind === :large_integer
        score = Int64(2)^53 + 1
        (score, _ -> score)
    elseif kind === :float32
        (Float32(1.5), _ -> Float32(1.5))
    elseif kind === :float64
        (1.5, _ -> 1.5)
    elseif kind === :feasibility
        (0.0, _ -> 0.0)
    else
        throw(ArgumentError("unknown reporting fixture"))
    end
    objective = CBLS.ScalarFunction(callback)
    MOI.set(opt, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.set(opt, MOI.ObjectiveFunction{typeof(objective)}(), objective)
    kind === :feasibility && MOI.set(opt, MOI.ObjectiveSense(), MOI.FEASIBILITY_SENSE)
    MOI.optimize!(opt)
    MOI.get(opt, MOI.ResultCount()) == 1 || error("fixed fixture has no result")
    output = retained ? Vector{Any}(undef, repetitions) : Vector{Float64}(undef, repetitions)
    Fixture(opt, output, raw)
end

function read_objectives!(f::Fixture)
    for i in eachindex(f.output)
        f.output[i] = MOI.get(f.optimizer, MOI.ObjectiveValue())
    end
    f.output
end

function verify(f::Fixture; reported_float=true)
    raw = CBLS._objective_value(f.optimizer.objective, CBLS.best_values(f.optimizer))
    raw === f.raw || error("native callback result changed")
    expected = eltype(f.output) === Float64 || reported_float ? Float64(f.raw) : f.raw
    all(value -> value === expected, f.output) || error("reported value or type changed")
    true
end

end
