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
