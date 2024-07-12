@testset "Aqua.jl" begin
    import Aqua
    import CBLS
    import JuMP
    import MathOptInterface

    # TODO: Fix the broken tests and remove the `broken = true` flag
    Aqua.test_all(
        CBLS;
        ambiguities = (broken = true,),
        deps_compat = false,
        piracies = (broken = true,),
        unbound_args = (broken = false)
    )

    @testset "Ambiguities: CBLS" begin
        # Aqua.test_ambiguities(CBLS;)
    end

    @testset "Piracies: CBLS" begin
        Aqua.test_piracies(CBLS;
            # Check with JuMP-dev
            treat_as_own = [JuMP.build_variable, Base.copy, MathOptInterface.empty!]
        )
    end

    @testset "Dependencies compatibility (no extras)" begin
        Aqua.test_deps_compat(
            CBLS;
            check_extras = false            # ignore = [:Random]
        )
    end

    @testset "Unbound type parameters" begin
        # Aqua.test_unbound_args(CBLS;)
    end
end
