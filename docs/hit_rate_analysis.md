# Hit-Rate Analysis & Architecture Evaluation

This document presents empirical comparison data between the baseline **Direct-Mapped Cache** and the **2-Way Set-Associative Cache with LRU Replacement**, both sized at 2 KB (128 words per line, 16 bytes/line).

## Benchmark Workloads

Three synthetic access traces were generated via `sim/gen_traces.py` to evaluate cache behavior across varying access locality profiles:

1. **`random.trc` (400 accesses)**: Uniformly distributed word-aligned addresses across memory space (0x0000–0xFFFF), modeling unstructured memory traffic with low temporal and spatial locality.
2. **`locality.trc` (360 accesses)**: Iterative inner-loop array traversals combined with local stack variable accesses, modeling scientific loops and standard procedural program execution.
3. **`conflict.trc` (1,600 accesses)**: Interleaved accesses to dual arrays $A$ and $B$ whose base addresses map to identical cache set indexes (`addr[10:4]` in direct-mapped and `addr[9:4]` in 2-way), modeling vector addition operations ($C[i] = A[i] + B[i]$) or matrix column traversals.

---

## Experimental Results

Simulation executed via `make test-traces` (`vvp sim/build/compare_trace.vvp`):

| Benchmark Trace | Accesses | Direct-Mapped Hits (Rate) | 2-Way SA Hits (Rate) | Hit Rate Delta | Primary Miss Type |
|---|---|---|---|---|---|
| **Random (`random.trc`)** | 400 | 10 (2.50%) | 8 (2.00%) | -0.50% | Capacity / Cold Misses |
| **Locality (`locality.trc`)** | 360 | 355 (98.61%) | 355 (98.61%) | +0.00% | Cold Misses |
| **Conflict (`conflict.trc`)** | 1,600 | 0 (0.00%) | 1,592 (99.50%) | **+99.50%** | Conflict Misses |

---

## Architectural Findings

### 1. High Locality Scenarios
When the working set fits comfortably within the 2 KB cache and access patterns exhibit strong sequential locality (`locality.trc`), both architectures perform identically well (98.61% hit rate). The initial misses are cold compulsory misses incurred while bringing lines into cache.

### 2. Random / Sparse Accesses
With unstructured access patterns (`random.trc`), both architectures suffer high miss rates (>97%), as the working set far exceeds cache capacity.

### 3. The Associativity Advantage in Conflict Scenarios
The critical advantage of the 2-way set-associative cache emerges in set-conflict workloads (`conflict.trc`):
- **Direct-Mapped Thrashing**: Because arrays $A$ and $B$ map to the same set index, each access to $A$ evicts $B$, and each access to $B$ evicts $A$. Even though total active data is small, the cache thrashes on every access, dropping the hit rate to **0.00%**.
- **2-Way Set-Associative Co-residency**: The 2-way cache maps $A$ into Way-0 and $B$ into Way-1 of the same set. Both active cache lines remain co-resident, allowing all intra-block spatial hits to succeed. The hit rate increases from **0.00% to 99.50%**, demonstrating the architectural necessity of set associativity.
