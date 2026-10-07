@testset "Aqua.jl" begin
    import Aqua
    import CBLS
    import JuMP
    import MathOptInterface

    Aqua.test_all(
        CBLS;
        ambiguities = (broken = false,),
        deps_compat = false,
        piracies = (broken = false,),
        unbound_args = (broken = false)
    )

    @testset "Ambiguities: CBLS" begin
        # Aqua.test_ambiguities(CBLS;)
    end

    @testset "Piracies: CBLS" begin
        Aqua.test_piracies(CBLS)
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
