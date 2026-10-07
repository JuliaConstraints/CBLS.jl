@testitem "MOI registry copy, ownership and unsupported mutations" tags=[:moi, :core] default_imports=false begin
    import CBLS
    import MathOptInterface as MOI
    import ConstraintProgrammingExtensions as CPE
    import Test: @test, @test_throws
    opt = CBLS.Optimizer()
    x = MOI.add_variables(opt, 3)
    sets = [MOI.Integer(), MOI.Interval(1.0, 7.0), CPE.Domain(Set([1,3,7]))]
    for v in x, s in sets
        ci = MOI.add_constraint(opt, v, s)
        @test ci.value == v.value
        @test MOI.is_valid(opt, ci)
        @test MOI.get(opt, MOI.ConstraintFunction(), ci) == v
    end
    f = MOI.VectorOfVariables(copy(x))
    s = CPE.XCSP3AllDifferent(3; except = [0])
    ci = MOI.add_constraint(opt, f, s)
    MOI.set(opt, MOI.Name(), "registry")
    MOI.set(opt, MOI.VariableName(), x[1], "x")
    MOI.set(opt, MOI.ConstraintName(), ci, "distinct")
    f.variables[1] = x[3]
    s.except[1] = 8
    @test MOI.get(opt, MOI.ConstraintFunction(), ci).variables == x
    @test MOI.get(opt, MOI.ConstraintSet(), ci).except == [0]
    retrieved = MOI.get(opt, MOI.ConstraintFunction(), ci)
    retrieved.variables[1] = x[3]
    @test MOI.get(opt, MOI.ConstraintFunction(), ci).variables == x
    @test !MOI.is_valid(opt, MOI.VariableIndex(0))
    @test !MOI.is_valid(opt, typeof(ci)(ci.value + 1))
    @test !MOI.is_valid(opt, MOI.ConstraintIndex{MOI.VariableIndex,MOI.ZeroOne}(1))
    @test_throws MOI.InvalidIndex MOI.add_constraint(opt, MOI.VariableIndex(99), MOI.Integer())
    @test_throws MOI.DeleteNotAllowed MOI.delete(opt, ci)
    @test_throws MOI.DeleteNotAllowed MOI.delete(opt, x[1])
    @test_throws MOI.SetAttributeNotAllowed MOI.set(opt, MOI.ConstraintSet(), ci, copy(s))
    @test_throws MOI.ModifyConstraintNotAllowed MOI.modify(opt, ci, MOI.ScalarConstantChange(0.0))
    dest = CBLS.Optimizer()
    mapping = MOI.copy_to(dest, opt)
    @test MOI.get(dest, MOI.NumberOfVariables()) == 3
    bounded = CBLS.Optimizer()
    v = MOI.add_variable(bounded)
    MOI.add_constraint(bounded, v, MOI.GreaterThan(0.0))
    @test_throws MOI.LowerBoundAlreadySet MOI.add_constraint(bounded,v,MOI.EqualTo(1.0))
    MOI.add_constraint(bounded,v,MOI.LessThan(3.0))
    @test_throws MOI.UpperBoundAlreadySet MOI.add_constraint(bounded,v,MOI.LessThan(4.0))
    @test MOI.get(dest, MOI.Name()) == "registry"
    @test MOI.get(dest, MOI.ConstraintName(), mapping[ci]) == "distinct"
    for (F,S) in MOI.get(opt, MOI.ListOfConstraintTypesPresent())
        @test MOI.get(dest, MOI.NumberOfConstraints{F,S}()) == MOI.get(opt, MOI.NumberOfConstraints{F,S}())
        @test all(i -> MOI.is_valid(dest,i), MOI.get(dest, MOI.ListOfConstraintIndices{F,S}()))
    end
    MOI.empty!(opt)
    @test MOI.is_empty(opt)
    @test !MOI.is_valid(opt, ci)
    @test !MOI.is_valid(opt, x[1])
    @test isempty(MOI.get(opt, MOI.ListOfConstraintTypesPresent()))
    @test MOI.get(dest, MOI.NumberOfVariables()) == 3
end

@testitem "MOI finite domains, repeated solve and objective replacement" tags=[:moi, :core] default_imports=false begin
    import CBLS
    import MathOptInterface as MOI
    import ConstraintProgrammingExtensions as CPE
    import Test: @test, @test_throws
    for reverse_order in (false,true)
        opt = CBLS.Optimizer()
        x = MOI.add_variable(opt)
        sets = [MOI.Integer(), MOI.GreaterThan(1.5), MOI.LessThan(7.0), CPE.Domain(Set([1.0,3.0,7.0,7.5]))]
        for set in (reverse_order ? reverse(sets) : sets)
            MOI.add_constraint(opt, x, set)
        end
        @test Set(CBLS.LS.get_domain(opt.solver, 1)) == Set([3,7])
    end
    opt = CBLS.Optimizer()
    MOI.set(opt, MOI.Silent(), true)
    MOI.set(opt, MOI.NumberOfThreads(), 1)
    MOI.set(opt, MOI.RawOptimizerAttribute("iteration"), 10)
    MOI.set(opt, MOI.TimeLimitSec(), 2.0)
    x,y = MOI.add_variables(opt,2)
    MOI.add_constraint(opt,x,MOI.EqualTo(2.0))
    MOI.add_constraint(opt,y,MOI.EqualTo(5.0))
    @test MOI.get(opt,MOI.ResultCount()) == 0
    @test_throws MOI.ResultIndexBoundsError MOI.get(opt,MOI.VariablePrimal(),x)
    # The subset must be read from the candidate, not the solver's current state.
    custom = CBLS.ScalarFunction(v -> v[1] - 2v[2], MOI.VectorOfVariables([y,x]))
    @test CBLS._objective_value(custom,[8,3]) == -13
    MOI.set(opt,MOI.ObjectiveSense(),MOI.MIN_SENSE)
    for objective in (custom, x, MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(3.0,y)], 1.0))
        MOI.set(opt,MOI.ObjectiveFunction{typeof(objective)}(),objective)
        @test CBLS.LS.length_objs(opt.backend_model) == 1
        MOI.optimize!(opt)
        @test MOI.get(opt,MOI.ResultCount()) == 1
        @test MOI.get(opt,MOI.ObjectiveValue()) == CBLS._objective_value(objective,[2,5])
        @test MOI.get(opt,MOI.PrimalStatus(2)) == MOI.NO_SOLUTION
        @test_throws MOI.ResultIndexBoundsError MOI.get(opt,MOI.ObjectiveValue(2))
    end
    z = MOI.add_variable(opt)
    MOI.add_constraint(opt,z,MOI.EqualTo(9.0))
    MOI.set(opt,MOI.ObjectiveSense(),MOI.FEASIBILITY_SENSE)
    MOI.optimize!(opt)
    @test MOI.get(opt,MOI.VariablePrimal(),z) == 9
    @test MOI.get(opt,MOI.ObjectiveValue()) == 0
    MOI.empty!(opt)
    @test MOI.get(opt,MOI.ResultCount()) == 0
    @test MOI.get(opt,MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
    @test MOI.get(opt,MOI.ObjectiveSense()) == MOI.FEASIBILITY_SENSE
    @test MOI.get(opt,MOI.Silent())
    x = MOI.add_variable(opt)
    MOI.add_constraint(opt,x,MOI.Integer())
    @test_throws ArgumentError MOI.optimize!(opt)
    MOI.add_constraint(opt,x,MOI.Interval(0.2,0.8))
    MOI.optimize!(opt)
    @test MOI.get(opt,MOI.TerminationStatus()) == MOI.INFEASIBLE
    @test MOI.get(opt,MOI.ResultCount()) == 0
end

@testitem "Legacy backend objective survives MOI wrapping" tags=[:moi, :core] default_imports=false begin
    import CBLS
    import MathOptInterface as MOI
    import Test: @test
    backend = CBLS.LS.model()
    CBLS.LS.variable!(backend,[3])
    CBLS.LS.objective!(backend,x -> 2x[1])
    opt = CBLS.Optimizer(backend)
    MOI.set(opt,MOI.Silent(),true)
    MOI.set(opt,MOI.NumberOfThreads(),1)
    MOI.set(opt,MOI.RawOptimizerAttribute("iteration"),2)
    MOI.optimize!(opt)
    @test MOI.get(opt,MOI.ObjectiveValue()) == 6
    @test MOI.get(opt,MOI.ObjectiveSense()) == MOI.MIN_SENSE
end

@testitem "Official MOI attribute and model interface tests" tags=[:moi, :core] default_imports=false begin
    import CBLS
    import MathOptInterface as MOI
    # No stochastic optimization or unsupported deletion/modification is hidden
    # behind an unconstrained all-tests invocation. These are MOI's own tests.
    selected = ["test_model_default_", "test_model_VariableName",
        "test_model_VariableIndex_ConstraintName", "test_model_ScalarAffineFunction_ConstraintName",
        "test_model_Name", "test_model_empty",
        "test_model_copy_to_Unsupported",
        "test_model_LowerBoundAlreadySet", "test_model_UpperBoundAlreadySet",
        "test_attribute_NumberThreads", "test_attribute_Silent", "test_attribute_SolverName",
        "test_attribute_SolverVersion", "test_attribute_TimeLimitSec", "test_attribute_after_empty",
        "test_attribute_unsupported_constraint"]
    MOI.Test.runtests(CBLS.Optimizer(), MOI.Test.Config(exclude = Any[MOI.delete, MOI.optimize!]);
        include = selected, exclude = ["test_model_Name_VariableName_ConstraintName"], verbose = true)
    # MOI's supports_constraint_*_EqualTo fixtures assume UInt8 is unsupported.
    # CBLS deliberately accepts Real-valued bounds; test that broader contract.
    opt = CBLS.Optimizer()
    x = MOI.add_variable(opt)
    ci = MOI.add_constraint(opt, x, MOI.EqualTo(UInt8(3)))
    @assert MOI.is_valid(opt, ci)
end
