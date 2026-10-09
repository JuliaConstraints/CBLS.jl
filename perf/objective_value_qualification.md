# Default-Float64 JuMP objective reporting qualification

This is a reporting correctness repair on a separate development branch. It is
not part of the frozen FINAL cohort and is not an optimization of Li-Lim search.
The added conversion has measured allocation, dispatch and execution costs.

## Source and contract

Baseline CBLS is `8d5e87717cdd5ad92d7617c724e55c07a481960f`; the qualified
runtime and regression source is `5129774cede7b855445d10f7cc300eada72a5e6f`.
The getter in the pre-performance handoff `3687ece072aa2dc17f4eee87eadd706d97ab6752`
is identical to the baseline getter. The defect predates this performance work.

The original ConstraintModels QAP callback returns an Int64. MOI accepts real
objective values, but JuMP's default Float64 model returns
`Union{Float64,Vector{Float64}}`. Its return conversion cannot convert the
Int64 to that union. JuMP's solution summary catches that exception and replaces
the objective with `missing`; printing a summary alone therefore missed it.

Only `MOI.get(::CBLS.Optimizer, ::MOI.ObjectiveValue)` converts its reported
scalar to Float64. Result-index checking and feasibility short-circuiting retain
their order. Native callback evaluation, objective installation, candidate
scoring, objective sense and incumbent selection are unchanged.

This intentionally changes the raw MOI reporting type. Integers above 2^53 may
round in the reported Float64; the raw callback still returns its exact integer.
Broader `JuMP.GenericModel{T}` and arbitrary-precision reporting are not qualified.

The actual Li-Lim and reproduction routing adapters install Float64 objectives
and consume LocalSearchSolvers incumbents directly. Their search loop does not
use this result getter. This repair supplies no routing throughput, scaling,
search-quality, convergence or global-optimality claim.

## Environment and regression evidence

Julia 1.13.1; Linux affinity CPUs 8,10; at most two Julia threads, one GC thread,
one BLAS thread and one OpenMP/native thread. Julia jobs run sequentially.
Fixtures and regression solves explicitly use one solver worker.

Both environments derive from the FINAL dependency lock. All 148 existing
manifest entries retain their version, source-tree hash and repository revision.
Only CBLS's checkout path differs between the matched environments.

Relevant frozen sources:

| Package | Commit |
| --- | --- |
| LocalSearchSolvers | `94fd347d5366d45cc345ad2ec723347c116e50ad` |
| ConstraintModels | `b7d7aaa6d00591e171a4d75c13ce9079f43beeaa` |
| Constraints | `476cf1751ad3d2ea2360522826bd8a778902116b` |
| ConstraintDomains | `508f4560880cf2c445008816571aecc1f6f3951b` |
| ConstraintCommons | `98cb9470250aa55ed19e35b78c133a98b56b5bdb` |
| ConstraintProgrammingExtensions | `9e6faf40ca3eb8c3399a50f68332708058150feb` |

JuMP 1.32.0, MathOptInterface 1.54.0, Parsers 3.0.0, Aqua 0.8.18,
TestItemRunner 1.3.2, BenchmarkTools 1.7.0, Chairmarks 1.3.1,
JET 0.12.3 and AllocCheck 0.2.6.

The three prepared test items pass all 280 assertions: original QAP callbacks
with and without a variable subset, cached and direct JuMP models, raw callback
type and value, one callback invocation per getter, objective summaries, signed
zero, Float32 conversion, large-integer reporting, min/max sense, feasibility,
result-index bounds, and variable/affine/quadratic objective replacement.

The unchanged standard suite plus these 280 assertions passes all **103,116**
assertions, including Aqua, through offline
`Pkg.test("CBLS"; allow_reresolve=false)`. The test child uses two Julia threads
and one GC thread. Existing example-log exceptions for absent solutions remain
visible; they are not test failures and are not changed by this branch.

A separate bounded control calls the actual
`ConstraintModels.qap(12, qap_weights, qap_distances)` constructor using its
original test matrices. Additional singleton domains fix the identity
permutation; this removes convergence as a prerequisite. Its objective is 1874.
Six control assertions pass on each source: before, the MOI value is Int64,
JuMP's getter raises MethodError and the summary reports missing; after, both
getters and the summary report 1874.0. This is not a QAP optimality claim.

The focused test items can be rerun with
`TestItemRunner.run_tests(pkgdir(CBLS); filter=t -> :objective_results in t.tags)`
in an environment resolving this branch and the stated dependency versions.

## Bounded getter observations

`perf/objective_value_scenarios.jl` constructs and solves fixed two-variable
fixtures outside measurement. Each operation reads the public MOI getter
128 times into preallocated output. The retained case uses Vector{Any}; the
typed case uses Vector{Float64}. Verification checks all reported values and
types and re-evaluates the raw callback without changing it.

Three warmups precede five native timed observations per case. All five have
zero measured compilation, recompilation and GC time. BenchmarkTools and
Chairmarks each use five samples and one evaluation. A full-sampling
Profile.Allocs capture is bounded to one 128-read operation.

All ten cases complete and verify on both sources with all four collectors:
80 collector/case/source combinations. Native, BenchmarkTools and Chairmarks
allocation totals agree. The table gives bytes / objects per 128 reads.

| Objective | Output | Before | After |
| --- | --- | ---: | ---: |
| Integer QAP | retained | 4,096 / 128 | 6,144 / 256 |
| Integer QAP | typed | 6,144 / 256 | 6,144 / 256 |
| Integer above 2^53 | retained | 6,144 / 256 | 8,192 / 384 |
| Integer above 2^53 | typed | 8,192 / 384 | 8,192 / 384 |
| Float32 | retained | 4,096 / 128 | 6,144 / 256 |
| Float32 | typed | 6,144 / 256 | 6,144 / 256 |
| Float64 | retained | 4,096 / 128 | 4,096 / 128 |
| Float64 | typed | 4,096 / 128 | 4,096 / 128 |
| Feasibility | retained | 0 / 0 | 0 / 0 |
| Feasibility | typed | 0 / 0 | 0 / 0 |

Profile.Allocs object counts agree in every case. Its byte accounting differs
for the large integer: retained 5,120 -> 7,168 bytes and typed 7,168 -> 7,168,
rather than the native table's 6,144 -> 8,192 and 8,192 -> 8,192. These profile
totals are retained separately; they are not substituted for GC-accounted bytes.
The other eight profile byte totals agree with the table.

Native elapsed ranges, in microseconds per 128 reads:

| Objective | Output | Before | After |
| --- | --- | ---: | ---: |
| Integer QAP | retained | 6.988–7.385 | 14.935–18.133 |
| Integer QAP | typed | 15.879–19.179 | 14.790–18.243 |
| Integer above 2^53 | retained | 4.547–5.559 | 12.875–13.900 |
| Integer above 2^53 | typed | 14.665–17.794 | 13.314–36.460 |
| Float32 | retained | 3.524–4.618 | 13.909–17.154 |
| Float32 | typed | 13.357–15.788 | 13.773–16.909 |
| Float64 | retained | 3.525–4.528 | 12.600–14.998 |
| Float64 | typed | 4.430–5.263 | 12.207–15.095 |
| Feasibility | retained | 1.466–1.791 | 1.333–1.445 |
| Feasibility | typed | 1.491–1.808 | 1.406–1.968 |

The correction is slower in several measured getter cases. For retained QAP,
BenchmarkTools/Chairmarks minima change from 5.901/5.827 to 14.393/14.398 us;
for retained Float64, from 3.583/3.709 to 11.892/11.414 us. Shared-machine,
bounded microbenchmarks do not establish application timing. No speedup is claimed.

## Static checks and limitations

The same public getter and retained/typed operation signatures complete direct
JET and AllocCheck analysis on both sources. Findings are possible static
issues, not measured allocations or failing regression assertions.

| Signature | JET before -> after | AllocCheck before -> after |
| --- | ---: | ---: |
| Public getter | 1 -> 1 | 3 -> 4 |
| Retained operation | 1 -> 1 | 3 -> 4 |
| Typed operation | 1 -> 1 | 4 -> 5 |

Each JET result contains one BuiltinErrorReport. All AllocCheck findings are
DynamicDispatch sites with `ignore_throw=true`; conversion adds one finding.
Getter return inference remains Any on both sources. Operation returns remain
Vector{Any} and Vector{Float64}, respectively. There is no inference improvement
or allocation-free-getter claim.

PerfChecker 1.0.0 could not be resolved while preserving Parsers 3.0.0: its cached
CSV dependency requires the earlier Parsers line. No dependency was downgraded.
The bounded native collectors and direct analyzers above were run instead;
PerfChecker's adapter suite is not claimed here.

The frozen FINAL and published performance branch remain unchanged. Only this
separate development branch contains the reporting repair and this receipt.
Disposable qualification environments and diagnostic data are removed after
publication; the committed tests and fixture remain for reproduction.
