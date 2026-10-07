@optimizer_edit function MOI.add_variable(model::Optimizer)
    model.optimized = false
    model.solver.model = model.backend_model
    return VI(variable!(model))
end
@optimizer_edit function MOI.add_variables(model::Optimizer, n::Int)
    n >= 0 || throw(ArgumentError("negative variable count"))
    return [MOI.add_variable(model) for _ in 1:n]
end

const NumericBoundSet = Union{MOI.EqualTo{<:Real}, MOI.LessThan{<:Real},
    MOI.GreaterThan{<:Real}, MOI.Interval{<:Real}}
const VariableSet = Union{NumericBoundSet, MOI.Integer, MOI.ZeroOne, DiscreteSet{<:Real}, CPE.Domain{<:Real}}
MOI.supports_constraint(::Optimizer, ::Type{VI}, ::Type{<:VariableSet}) = true

function _variable_domain(opt, variable, new_set = nothing)
    sets = Any[set for (function_, set) in values(opt.registry) if function_ == variable]
    isnothing(new_set) || push!(sets, new_set)
    lower, upper = -Inf, Inf
    integer = false
    enumeration = nothing
    for set in sets
        if set isa Union{MOI.Integer, MOI.ZeroOne}
            integer = true
            if set isa MOI.ZeroOne
                lower, upper = max(lower, 0), min(upper, 1)
            end
        elseif set isa Union{CPE.Domain, DiscreteSet}
            enumeration = isnothing(enumeration) ? collect(set.values) : intersect(enumeration, set.values)
        elseif set isa MOI.EqualTo
            lower, upper = max(lower, set.value), min(upper, set.value)
        elseif set isa MOI.GreaterThan
            lower = max(lower, set.lower)
        elseif set isa MOI.LessThan
            upper = min(upper, set.upper)
        elseif set isa MOI.Interval
            lower, upper = max(lower, set.lower), min(upper, set.upper)
        end
    end
    if !isnothing(enumeration)
        filter!(x -> lower <= x <= upper && (!integer || isinteger(x)), enumeration)
        return integer ? Int.(enumeration) : enumeration
    end
    if isfinite(lower) && isfinite(upper)
        if integer
            return ceil(Int, lower):floor(Int, upper)
        end
        return lower > upper ? Float64[] : lower == upper ? [lower] :
            domain(Intervals.Interval{Intervals.Closed, Intervals.Closed}(lower, upper))
    end
    # No artificial finite truncation of an unbounded integer domain.
    return nothing
end

function _add_constraint_backend!(opt::Optimizer, variable::VI, set::VariableSet)
    values = _variable_domain(opt, variable, set)
    if !isnothing(values)
        _set_domain!(opt, variable.value, values)
    end
    set isa Union{MOI.Integer, MOI.ZeroOne} && push!(opt.int_vars, variable.value)
    return CI{VI, typeof(set)}(variable.value)
end

## SECTION - Test Items
@testitem "Variable Index" begin
    using CBLS
    using JuMP

    model = Model(CBLS.Optimizer)

    @variable(model, 1≤X[1:4]≤4, Int)
    # @variable(model, Y[1:4], Bin)

    optimize!(model)
end


@testitem "CPE finite domain" tags=[:cpe, :moi] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import MathOptInterface as MOI
    import Test: @test

    optimizer = CBLS.Optimizer()
    variable = MOI.add_variable(optimizer)
    set = CPE.Domain(Set([1, 3, 7]))
    @test MOI.supports_constraint(optimizer, MOI.VariableIndex, typeof(set))
    MOI.add_constraint(optimizer, variable, set)
    @test Set(CBLS.LS.get_domain(optimizer.solver, variable.value)) == set.values
end
