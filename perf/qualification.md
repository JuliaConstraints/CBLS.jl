# Sum keyword allocation qualification — 8 October 2026

Baseline: CBLS `3687ece072aa2dc17f4eee87eadd706d97ab6752`,
LocalSearchSolvers `57c5aaff0c2714e42e3c2a4335617354d08120ef`,
MetaStrategist `3c6ad5b057af4910bed99412ba24f7bc8d329587`.

The Sum adapter now owns a concrete evaluator and fixed keyword tuple. Fixed
keywords still override incoming keywords. It retains the original full-cost
evaluation contract; no learned truth, penalty, validator, or incremental policy
was replaced. MOI still copies parameter arrays before handing them to the adapter.

`core_scenarios.jl` supplies independent ring-sum/objective oracles, real MOI
optimization, two private typed MetaStrategist units, and 1,024 rejected and 1,024
accepted eight-variable MetaMoves (plus 1,024 zero-state restoration commits).
The fixed-work limit is independent of an unlimited wall-time budget.

Julia 1.13.1; CPU affinity 0,2 (two distinct physical cores); Julia threads 2,
GC threads 1, BLAS/OpenMP threads 1, precompile tasks 1. Tools were added offline
to a separate temporary diagnostic environment. The frozen solver environment
and benchmark worktree were read-only. The tool resolver selected Parsers 2.8.8
in this environment; before/after used the same resolved solver dependencies.

| Warm operation | Before bytes / objects | After bytes / objects | Before seconds (3 samples) | After seconds (3 samples) |
|---|---:|---:|---|---|
| initialize 32 variables / 32 constraints | 168,280 / 2,457 | 39,720 / 696 | .000190145, .000162997, .000162611 | .000128514, .000088613, .000085611 |
| CBLS 256 steps | 15,913,584 / 246,177 | 1,403,296 / 34,415 | .009244760, .009393605, .009207122 | .001109156, .001097674, .001070165 |
| two typed units, 256 steps each | 31,267,888 / 480,284 | 2,450,704 / 59,847 | .009219535, .009365314, .008797275 | .001172043, .001216401, .001150298 |
| 1,024 MetaMove trials | 79,626,240 / 1,208,320 | 6,160,384 / 155,648 | .060862276, .041892570, .041759782 | .001558501, .001565423, .002634752 |

Object counts are `@timed.gcstats.poolalloc + bigalloc`. The warm samples above
reported zero compile time, zero measured GC time, and zero lock conflicts.
Two-worker cold observations had one lock conflict. These are operational
matched-work measurements on a machine running other work, not controlled
scaling evidence or a comparative benchmark campaign.

Cold CBLS first-operation scope excluded fixture construction: before 3.718 s,
877.7 MB; after 4.337 s, 954.7 MB. Compilation dominated; no cold-latency
improvement is claimed. PerfChecker's separate latency lifecycle observation
afterwards was 1.997 s source loading, 9.974 s first full case, .001526 s warm
full case. These scopes and instrumentation differ.

Validation: 2,378 keyword/original-truth/ownership checks and 45,825 checks in
the CBLS moi/core regression run passed. All four operation oracles passed.
PerfChecker benchmark, CPU-profile and full allocation-profile collectors
completed with passing correctness oracles. Chairmarks was installed in the
diagnostic environment and remained to be exercised at this increment.

PerfChecker 1.0.0 analyzer inventory: JET, AllocCheck, Aqua, SnoopCompile,
latency, GC, locks, memory, heap. JET 0.12.3 and AllocCheck 0.2.6 executed the
solve specialization: 645 inference findings and 625 possible-allocation
findings, including cold MOI registry/lifecycle dispatch and runtime internals.
This is not inference-clean or statically allocation-free. SnoopCompile 3.2.9
measured 46.258 s inclusive first-lifecycle inference under instrumentation.
GC, locks, latency and memory completed with passing correctness; three warm
GC/lock samples had no collection or lock conflict. Reachable optimizer state
was 55,645 bytes before solving and 107,160 bytes afterwards. Heap was
available but not captured: operation allocation stacks identified the adapter
without a process-wide snapshot. Aqua executed and reported a package-quality
failure; its exact existing check is investigated in the next increment.

Remaining measured costs include Constraints-owned sum temporaries, cold MOI
registry dispatch, repeated initialization input vectors, receipt serialization
and repeated evaluator-type display during prepared-unit reset. Raw stacks and
bulk reports are not committed.

## Subsequent analyzer qualification

The Aqua failure was missing compatibility bounds for the existing Aqua, Test
and TestItemRunner extras. Bounds were added; full Aqua checks then passed.
All four PerfChecker collectors (BenchmarkTools, Chairmarks, CPU profile and
allocation profile) were exercised on the LocalSearchSolvers owned-unit/reset
cases. All nine native analyzers were exercised across the solver and receipt
cases. The receipt heap analyzer captured a redacted process snapshot in a
temporary reports directory, which was removed after recording aggregate size
and digest. This does not imply the CBLS hot loop is inference-clean.

The installed PerfChecker catalog also lists external and GPU integrations as
candidates. They are not native qualified collectors. GPU/accelerator tools do
not apply to these CPU workloads. Linux `perf` is installed but its task-clock
probe failed with no supported events; `perf_event_paranoid` is 4. No system
security settings were changed. Valgrind and heaptrack are absent. Runtime
instrumentation findings are scoped to the operation each tool actually ran.

## Six additional fixed-keyword adapters

AllDifferent, AllEqual, Ordered, Element, Minimum and Maximum now use the same
concrete full-cost wrapper as Sum. Empty Ordered offsets are still omitted;
empty AllDifferent exclusions and Element index zero still map to `nothing`.
Fixed parameters continue to override caller parameters. MOI array ownership,
model copying, validators, numerical scores and incremental-policy selection
are preserved.

`adapter_scenarios.jl` evaluates all six real registered MOI adapters on two
inputs, 1,024 times (12,288 evaluations), with independent truth oracles. Its
24-variable mixed solver case repeats four constraints in each of six disjoint
groups and runs exactly 128 steps. Each operation restores the initial strategy
snapshot before resetting seed 41, preventing previous solves from changing the
work trajectory. Final assignments were identical before and after.

The isolated adapter baseline used CBLS `3687ece072aa2dc17f4eee87eadd706d97ab6752`
with LocalSearchSolvers `a6d1c608dfb5bdec73425da5596c15b94fade7e8` and
MetaStrategist `3d891e069e0e9993c7239e3b7091833b6756529c`. Only CBLS's source path
changed in the after environment; tools and solver dependencies match.

| Warm matched work | Before bytes / objects | After bytes / objects | Before seconds (3 samples) | After seconds (3 samples) |
|---|---:|---:|---|---|
| 12,288 adapter evaluations | 25,165,872 / 366,594 | 1,998,912 / 53,251 | .012853894, .012713952, .012804797 | .000653554, .000639375, .000656320 |
| mixed MOI solve, 128 steps | 8,665,024 / 131,577 | 295,680 / 6,634 | .006043716, .005970325, .006013204 | .001216014, .000996157, .001214122 |

Warm samples had zero measured compile and collection time. Other machine work
continued; these are operational fixed-work observations, not a comparative
campaign or scaling result. Residual evaluation allocations include original
Constraints-owned temporary arrays, rather than per-call parameter dictionaries.

All 62,799 CBLS moi/core checks passed, including 16,962 new independent
exhaustive truth checks and 12 array ownership/deepcopy checks. Full Aqua checks
passed. PerfChecker BenchmarkTools, Chairmarks, CPU profile and full allocation
profile collectors all completed the evaluation case with passing oracles.
They measured approximately 1,998,848–1,998,864 bytes / 53,248–53,249 objects;
allocation profiling sampled both evaluations and records their weight separately.

Concrete evaluation-operation JET findings fell from 19 to zero. AllocCheck
findings fell from 8 to 6, including possible original truth-evaluator temporary
allocations; no static allocation-free claim is made. SnoopCompile inclusive
inference was 4.944 s for this case. Separate latency source/first/warm scopes
were 1.945/2.529/.000957 s. Three GC and lock samples had no collection,
compilation or lock conflicts. Reachable fixture size stayed 1,320 bytes, with
1,328 bytes including its scalar result. Raw reports remain uncommitted.

## Structural and scheduling keyword adapters

Channel, Circuit, Cumulative, Instantiation, Extension, Supports, Conflicts,
Regular and MDD now bind their original evaluator and keyword tuple once.
Circuit's zero target still becomes the variable count; Channel's zero index
still becomes `nothing`. Empty cumulative task data is omitted, so a caller's
task data can still supply that optional parameter. Full-cost policy, scores,
keyword precedence and MOI ownership remain unchanged.

`structural_scenarios.jl` supplies independent inverse-channel, single-cycle,
half-open task-load, tuple-membership and language oracles. It evaluates fourteen
registered variants on two inputs, 1,024 times (28,672 evaluations). Its mixed
56-variable model repeats four constraints per group and solves exactly 128
steps with the same restored strategy and seed before each observation. Final
assignments were identical before and after. The evaluation harness maps each
callback's two scalar scores before reducing them, avoiding inference recursion
across fourteen heterogeneous callback types.

The baseline is CBLS `3687ece072aa2dc17f4eee87eadd706d97ab6752`, with the same
LocalSearchSolvers `35671c8daba2a293dd431dfe80f59da73bc7596d`, MetaStrategist
`3d891e069e0e9993c7239e3b7091833b6756529c` and resolved diagnostic dependencies
as the after environment. Only CBLS's source path differs. Resource limits are
the two-core limits above. Collection was requested before, outside each timed
sample; all listed operations had zero measured compilation and collection.

| Warm matched work | Before bytes / objects | After bytes / objects | Before seconds (3 samples) | After seconds (3 samples) |
|---|---:|---:|---|---|
| 28,672 structural evaluations | 55,541,808 / 742,402 | 3,113,024 / 57,347 | .029098418, .029425364, .029602653 | .001676185, .001681670, .001702936 |
| mixed MOI solve, 128 steps | 14,518,904 / 208,711 | 774,288 / 18,379 | .013249530, .012802723, .013258374 | .002598206, .002343664, .002331589 |

These are operational fixed-work observations on a shared machine. The solve
baseline also observed 14,453,328 bytes / 208,710 objects in earlier samples;
this one-object variation does not affect the assignment or work count.

All 33,947 new checks passed against both source versions, including exhaustive
original-truth checks, fractional and zero-duration scheduling, default/override
precedence and mutation of caller-owned arrays and language tables after MOI
registration. All 96,746 CBLS moi/core regression checks and full Aqua passed.
All four PerfChecker collectors passed. BenchmarkTools and Chairmarks measured
3,112,960–3,112,976 bytes / 57,344–57,345 objects for the evaluation operation;
the full allocation profile agreed with those independent operation totals.

JET optimization findings fell from 27 to zero for the final concrete operation.
AllocCheck reported 14 possible allocations, including the original truth
evaluators' temporary arrays; this operation is not allocation-free. Inclusive
SnoopCompile inference was 6.389 s. Separate source/first/warm latency scopes
were 1.810/5.422/.002294 s. Three GC and lock samples had no collection,
compilation or conflicts. Reachable fixture state stayed 21,112 bytes, or 21,120
bytes with its scalar result. Raw instrumentation reports are not committed.

## Distance-difference evaluator binding

The distance-difference adapter now obtains its original evaluator once during
registration. It retains full-cost policy and its historical behavior of
ignoring every caller keyword, including `X`. `distance_scenarios.jl` checks
2,048 registered evaluations against an independent absolute-distance oracle
and a 32-variable, eight-group model with exactly 128 solver steps. Each solve
restores the strategy and seed 41; final assignments match exactly.

The baseline is CBLS `0c3618f2c32115a95e839b5c2b88e0bce1abeaf1`, with unchanged
LocalSearchSolvers `d26a070f8d87176a8f8bc9c172c59c683b3c2bd5`, MetaStrategist
`f64bfa4d68f3f80b08eee473a3bfc90f56e0fb5d` and resolved dependencies. Before and
after samples use the same two-core limits. Collection occurs outside each
timed sample; measured compilation and collection time are zero.

| Warm matched work | Before bytes / objects | After bytes / objects | Before seconds (3 samples) | After seconds (3 samples) |
|---|---:|---:|---|---|
| 2,048 registered evaluations | 65,584 / 4,098 | 64 / 3 | .000077193, .000086076, .000099779 | .000004448, .000004458, .000003431 |
| MOI solve, 128 steps | 542,016 / 22,569 | 208,480 / 4,768 | .001453672, .001444935, .001395475 | .000879004, .000703786, .000798982 |

These are fixed-work operational observations on a shared machine. All 97,459
CBLS moi/core checks and full Aqua pass, including 713 new checks covering
integer and fractional truth, ignored keywords, unchanged borrowed storage,
input shape behavior and model cloning. All four PerfChecker collectors pass.
BenchmarkTools records 16 bytes / one scalar-result object; Chairmarks and the
full allocation profile record zero bytes / objects for the evaluation case.

JET optimization findings fall from two to zero; AllocCheck findings fall from
three to zero for the concrete evaluation operation. Three GC and lock samples
show only the constant scalar-result object, with no compilation, collection
or conflicts. Reachable fixture state remains 1,240 bytes, or 1,248 bytes with
its result. Raw reports are not committed.

## Prepared XCSP3 expression operators

Prepared expression nodes now specialize their operator while retaining its
symbol as metadata. The existing shared arithmetic implementation is inlined
at the call site. Conditional expressions return from explicit lazy branches,
so indexing a heterogeneous argument tuple no longer boxes its selected entry.
Short-circuit behavior, original scores, undefined-arithmetic penalties,
argument order and ownership remain unchanged. Prepared evaluator type names
include the operator parameter; receipts describing their actual types change
accordingly. This does not change the canonical encoding implementation.

`expression_scenarios.jl` registers five three-variable expression trees through
MOI: addition equality, quadratic inequality, mixed integer/Boolean conditional,
guarded remainder and implication. Each operation performs 6,144 evaluations
against independent truth functions. The solve case combines all five trees in
eight groups and runs exactly 128 steps with restored strategy and seed 41.
Its final assignment and error 26 match before and after; it does not find a
feasible solution. Three separate audit runs with seeds 41–43 preserve all
3,563 events, candidate scores, final assignments and subsequent 64-word RNG
samples exactly. Clocks and process identifiers are excluded from trace hashes.

The isolated baseline is CBLS `2c453ddee7f3af7433573969916caec1918fe8d4`, with
unchanged LocalSearchSolvers `bcc516b6fa1d3edc9732bebb38a009719491c8d1`,
MetaStrategist `ba019deede736e436e893be187e517fd5a1ce23c`, frozen shared constraint
packages and resolved diagnostic dependencies. Only the CBLS source path differs.
Both environments use CPUs 0 and 2, two Julia threads, one GC thread and one
BLAS/OpenMP worker. Five warmed observations per case collect outside the timed
operation; measured compilation and GC time are zero.

| Warm matched work | Before bytes / objects | After bytes / objects |
|---|---:|---:|
| 6,144 addition-equality evaluations | 589,840 / 30,721 | 32 / 2 |
| 6,144 quadratic-inequality evaluations | 786,448 / 36,865 | 32 / 2 |
| 6,144 conditional evaluations | 1,245,200 / 40,961 | 32 / 2 |
| 6,144 guarded-remainder evaluations | 524,304 / 28,673 | 32 / 2 |
| 6,144 implication evaluations | 458,768 / 26,625 | 32 / 2 |
| mixed MOI solve, 128 steps | 1,169,616 / 46,620 | 257,104 / 5,346 |

Observed conditional-operation times span .001672–.001726 s before and
.0000692–.0000739 s after. The solve spans .003622–.007415 s before and
.001100–.001136 s after. These are operational fixed-work observations on a
shared machine, with no controlled throughput or search-quality claim.

All 102,727 CBLS moi/core regressions and full Aqua pass. The 5,268 new checks
also pass against the prior source version: all 28 operators have independent
integer and fractional value oracles, registered truth covers lazy branches,
and ownership checks cover caller mutation, repeated variable scopes, model
copies and fresh positional arrays. Arithmetic errors retain their penalty;
shape and programming errors still propagate.

All four native PerfChecker collectors pass for all six scenarios. For each
evaluation operation, BenchmarkTools records one 16-byte scalar-result object;
Chairmarks and the full allocation profile record zero bytes and objects.
Fresh solve collector scopes record 257,328–260,048 bytes and 5,351–5,377
objects; profile allocation bytes are 260,048 with 5,351 recorded objects.
These fresh lifecycle scopes differ from the repeatedly warmed fixture above.
The solve and arbitrary expression lifecycles are not allocation-free.

JET findings fall from 23/29/30/36/36 to zero for the five concrete evaluation
operations. AllocCheck findings fall from 36/55/52/50/50 to zero. All nine native
diagnostic adapters complete; Aqua's adapter reports package quality separately
from scenario correctness. For the conditional case, inclusive SnoopCompile
inference is 3.047 s, and separate load/first-lifecycle/warm-lifecycle latency
scopes are 1.831/1.921/.000273 s. Three GC and lock observations have only the
16-byte result object, with no compilation, collection or observed conflicts.
Reachable fixture state stays 1,128 bytes, or 1,136 with its result. The redacted
heap snapshot is removed after inspection. Raw reports are not committed.
