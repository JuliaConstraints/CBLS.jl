@testitem "Independent structural core exhaustive oracles" tags=[:core, :xcsp3] default_imports=false begin
    import CBLS
    import ConstraintProgrammingExtensions as CPE
    import Test: @test, @test_throws
    P,V,E,C = CPE.XCSP3Position,CPE.XCSP3Positions,CPE.XCSP3Expression,CPE.XCSP3Condition
    fixtures = [
        (CPE.XCSP3Ordered(3; list=V(1:3), lengths=[1,1]), x -> x[1]+1<=x[2] && x[2]+1<=x[3]),
        (CPE.XCSP3Precedence(3; list=V(1:3), values=[0,1,2]), x -> all(v -> !(v in x) || (v-1 in x && findfirst(==(v-1),x)<findfirst(==(v),x)), 1:2)),
        (CPE.XCSP3Regular(3; list=V(1:3), transitions=[(0,0,0),(0,1,1),(1,1,1)], start=0,final=[1]), x -> all(v->v in (0,1),x) && x[end]==1 && issorted(x)),
        (CPE.XCSP3MDD(3; list=V(1:3), transitions=[(0,0,1),(0,1,1),(1,1,2),(2,2,3)]), x -> x[1] in (0,1) && x[2]==1 && x[3]==2),
        (CPE.XCSP3AllDifferentLists(3; lists=(V([1]),V([2]),V([3])), except=([0],)), x -> count(==(1),x)<=1 && count(==(2),x)<=1),
        (CPE.XCSP3BinPacking(3; list=V(1:3),sizes=[1,2,3],conditions=[C(:le,3),C(:le,3),C(:le,3)],start_index=0), x -> all(bin -> sum((i for i in 1:3 if x[i]==bin);init=0)<=3,0:2)),
        (CPE.XCSP3Knapsack(3; list=V(1:3),weights=[1,2,3],profits=[3,2,1],weight_condition=C(:le,5),profit_condition=C(:ge,3)), x -> x[1]+2x[2]+3x[3]<=5 && 3x[1]+2x[2]+x[3]>=3),
        (CPE.XCSP3Core{:sum}(3; list=[E(:abs,E(:sub,P(1),P(2))),P(3)],condition=C(:eq,2)), x -> abs(x[1]-x[2])+x[3]==2),
        (CPE.XCSP3Core{:count}(3; list=[E(:abs,E(:sub,P(1),P(2))),P(3)], values=[1,1],condition=C(:eq,1)), x -> (abs(x[1]-x[2])==1)+(x[3]==1)==1),
        (CPE.XCSP3Core{:nvalues}(3; list=[P(1),E(:add,P(2),1),P(3)],except=[0],condition=C(:eq,2)), x -> length(Set(filter(!iszero,[x[1],x[2]+1,x[3]])))==2),
        (CPE.XCSP3Core{:all_different}(3; list=[E(:add,P(1),1),P(2),P(3)]), x -> length(Set([x[1]+1,x[2],x[3]]))==3),
    ]
    for (set,oracle) in fixtures
        f = CBLS._xcsp3_evaluator(set)
        for tuple in Iterators.product(0:2,0:2,0:2)
            x = collect(tuple)
            @test iszero(f(x)) == oracle(x)
            @test iszero(f(Float64.(x))) == oracle(x)
        end
    end
    for dim in (1,2), zero_ignored in (false,true)
        n = 2dim
        f = CBLS._xcsp3_evaluator(CPE.XCSP3NoOverlap(2n;
            origins=V(reshape(1:n,dim,2)),lengths=V(reshape((n+1):2n,dim,2)),zero_ignored))
        for values in Iterators.product(ntuple(_->0:1,2n)...)
            x = collect(values); origins=reshape(x[1:n],dim,2); lengths=reshape(x[n+1:end],dim,2)
            ignored = zero_ignored && (any(iszero,lengths[:,1]) || any(iszero,lengths[:,2]))
            expected = ignored || any(k -> origins[k,1]+lengths[k,1]<=origins[k,2] || origins[k,2]+lengths[k,2]<=origins[k,1],1:dim)
            @test iszero(f(x)) == expected
        end
    end
    f = CBLS._xcsp3_evaluator(CPE.XCSP3Cumulative(6; origins=V(1:2),lengths=V(3:4),heights=V(5:6),condition=C(:le,1)))
    for tuple in Iterators.product(ntuple(_->0:2,6)...)
        x = collect(tuple)
        expected = all(t -> sum((x[i+4] for i in 1:2 if x[i]<=t<x[i]+x[i+2]);init=0)<=1, -1:5)
        @test iszero(f(x)) == expected
    end
    # The reference XCSP3 parser stops from the first list and wraps subsequent lists.
    for circular in (false,true)
        template = CPE.XCSP3Intension(2; expression=E(:ne,P(1),P(2)))
        f = CBLS._xcsp3_evaluator(CPE.XCSP3Slide(5; lists=(V(1:3),V(4:5)),offsets=[1,1],collects=[1,1],circular,template))
        @test f([0,1,2,1,0]) == 0
        @test f([0,1,1,1,0]) > 0 # violation only in third window
    end
    @test_throws DimensionMismatch CBLS._xcsp3_evaluator(CPE.XCSP3NoOverlap(2;origins=V(1:2),lengths=[1]))([0,2])
    # Shared compiled metadata must retain nondeterminism and be task-safe.
    language = CPE.XCSP3Regular(2; list=V(1:2), transitions=[(0,1,1),(0,1,2),(1,2,3),(2,3,3)],start=0,final=[3])
    evaluator = CBLS._xcsp3_evaluator(language)
    words = [[1,2],[1,3],[1,1],[2,3]]
    tasks = [Threads.@spawn evaluator(word) for word in repeat(words,8)]
    @test iszero.(fetch.(tasks)) == repeat([true,true,false,false],8)
end
