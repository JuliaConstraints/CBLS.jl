@testitem "DiscreteSet scalar construction binds its element type" tags=[:moi,:core] begin
    @test CBLS.DiscreteSet(3).values==[3]
    @test CBLS.DiscreteSet(1,3,5).values==[1,3,5]
    @test CBLS.DiscreteSet(1.0,3.0).values==[1.0,3.0]
    @test CBLS.DiscreteSet(Int[]).values==Int[]
    @test_throws MethodError CBLS.DiscreteSet()
end
