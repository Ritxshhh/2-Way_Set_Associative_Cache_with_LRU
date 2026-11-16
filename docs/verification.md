# Verification & Testbench Report

**Date:** 2026-11-16  
**Simulator:** Icarus Verilog v13.0 / vvp  
**Test Suite:** `make test`  
**Overall Result:** **ALL TESTS PASSED** (0 failures, 0 functional mismatches)

---

## 1. Unit & Submodule Test Suite Summary

All unit testbenches and smoke tests execute without errors:

| Testbench | Component / Focus | Checks & Observations | Status |
|:---|:---|:---|:---:|
| `tb_way_ram.v` | Way-0/Way-1 data & tag RAMs | Asynchronous read, synchronous write, partial word enables (`0001`), set isolation, mask disable | **PASS** (8/8) |
| `tb_valid_lru.v` | Valid bits & LRU replacement state | Per-set valid bit asserting/clearing, LRU bit toggling upon `touch` / `touch_way` | **PASS** (7/7) |
| `tb_tag_comparator.v` | Parallel tag comparator | Both invalid, Way-0 match, Way-1 match, neither match, simultaneous match warning | **PASS** (6/6) |
| `tb_mem_model.v` | Main memory model | Tested latencies 1, 3, and 6 cycles; exact single-cycle ready pulse; request latching | **PASS** (18/18) |
| `tb_direct_mapped_smoke.v` | Direct-mapped cache | Compulsory miss, hit, dirty write, tag conflict miss, dirty writeback | **PASS** (5/5) |
| `tb_cache_2way_smoke.v` | Integrated 2-way cache | Compulsory miss, hit, Way-1 allocation, hit, eviction of LRU Way-0 | **PASS** (6/6) |
| `tb_dm_vs_2way.v` | Head-to-head conflict test | Direct-mapped thrashes (M-M-M-M-M); 2-way retains both lines (M-M-H-H-H) | **PASS** |
| `tb_cache_2way_writeback.v` | Writeback data integrity | Dirty line eviction triggers correct memory writeback before line refill | **PASS** |

---

## 2. Trace-Driven Comparative Verification (`tb_compare.v`)

Both `direct_mapped_cache` and `cache_2way_top` were driven in lockstep with $2{,}000$ operations per trace ($6{,}000$ operations total).

### A. Golden Reference Model Functional Verification
The comparison testbench `tb/tb_compare.v` integrates a cycle-accurate golden reference memory model tracking expected contents of all 16,384 words (64 KB).
- On every write operation, the golden model is updated with written data.
- On every read operation, the data returned by `direct_mapped_cache` (`dm_rdata`) and `cache_2way_top` (`sa_rdata`) are compared against the golden reference model.
- **Results:**
  - `random.trc` (2,000 accesses): **0 mismatches** (DM: 0, 2W: 0)
  - `locality.trc` (2,000 accesses): **0 mismatches** (DM: 0, 2W: 0)
  - `conflict.trc` (2,000 accesses): **0 mismatches** (DM: 0, 2W: 0)
  - **Overall Status:** **PASSED (100% Data Integrity Verified)**

---

## 3. Manual LRU Trace Analysis (Set 0, 11 Consecutive Accesses)

To rigorously verify the replacement policy of `lru_state.v` and the controller FSM victim selection, 11 consecutive accesses to **Set 0** (`addr[9:4] = 6'b000000`) were extracted from the benchmark workload and traced by hand against simulation outputs.

### Hardware State Definitions (`lru_state.v`):
- `lru_bit[set] == 0`: **Way-0 is LRU** (Way-0 will be selected as the eviction victim next).
- `lru_bit[set] == 1`: **Way-1 is LRU** (Way-1 will be selected as the eviction victim next).
- Update rule: On access to way $W$, `touch = 1, touch_way = W` $\implies$ `lru_bit[set] <= ~W`.

### Access-by-Access Trace Table:

| Step | Trace Op & Address | Set | Tag | Way-0 State (Pre) | Way-1 State (Pre) | LRU (Pre) | Result | Eviction / Action | Way-0 State (Post) | Way-1 State (Post) | LRU (Post) |
|:---:|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---|:---:|:---:|:---:|
| **Init** | Reset | 0 | - | Empty (`V=0`) | Empty (`V=0`) | **0** | - | Reset initialized | Empty (`V=0`) | Empty (`V=0`) | **0 (Way-0)** |
| **1** | R `0x00005000` | 0 | `0x14` | Empty (`V=0`) | Empty (`V=0`) | **0** | **MISS** | Fills Way-0 (clean) | Tag `0x14`, `V=1, D=0` | Empty (`V=0`) | **1 (Way-1)** |
| **2** | W `0x00008400` | 0 | `0x21` | Tag `0x14`, `V=1` | Empty (`V=0`) | **1** | **MISS** | Fills Way-1 (dirty) | Tag `0x14`, `V=1, D=0` | Tag `0x21`, `V=1, D=1` | **0 (Way-0)** |
| **3** | R `0x0000A000` | 0 | `0x28` | Tag `0x14`, `V=1` | Tag `0x21`, `V=1` | **0** | **MISS** | **Evicts Way-0** (clean) | Tag `0x28`, `V=1, D=0` | Tag `0x21`, `V=1, D=1` | **1 (Way-1)** |
| **4** | R `0x0000E400` | 0 | `0x39` | Tag `0x28`, `V=1` | Tag `0x21`, `V=1` | **1** | **MISS** | **Evicts Way-1** (WB dirty $0x21$) | Tag `0x28`, `V=1, D=0` | Tag `0x39`, `V=1, D=0` | **0 (Way-0)** |
| **5** | R `0x00000000` | 0 | `0x00` | Tag `0x28`, `V=1` | Tag `0x39`, `V=1` | **0** | **MISS** | **Evicts Way-0** (clean) | Tag `0x00`, `V=1, D=0` | Tag `0x39`, `V=1, D=0` | **1 (Way-1)** |
| **6** | R `0x00002C00` | 0 | `0x0B` | Tag `0x00`, `V=1` | Tag `0x39`, `V=1` | **1** | **MISS** | **Evicts Way-1** (clean) | Tag `0x00`, `V=1, D=0` | Tag `0x0B`, `V=1, D=0` | **0 (Way-0)** |
| **7** | R `0x00000C00` | 0 | `0x03` | Tag `0x00`, `V=1` | Tag `0x0B`, `V=1` | **0** | **MISS** | **Evicts Way-0** (clean) | Tag `0x03`, `V=1, D=0` | Tag `0x0B`, `V=1, D=0` | **1 (Way-1)** |
| **8** | R `0x00008000` | 0 | `0x20` | Tag `0x03`, `V=1` | Tag `0x0B`, `V=1` | **1** | **MISS** | **Evicts Way-1** (clean) | Tag `0x03`, `V=1, D=0` | Tag `0x20`, `V=1, D=0` | **0 (Way-0)** |
| **9** | R `0x00004C00` | 0 | `0x13` | Tag `0x03`, `V=1` | Tag `0x20`, `V=1` | **0** | **MISS** | **Evicts Way-0** (clean) | Tag `0x13`, `V=1, D=0` | Tag `0x20`, `V=1, D=0` | **1 (Way-1)** |
| **10** | W `0x0000D400` | 0 | `0x35` | Tag `0x13`, `V=1` | Tag `0x20`, `V=1` | **1** | **MISS** | **Evicts Way-1** (dirty) | Tag `0x13`, `V=1, D=0` | Tag `0x35`, `V=1, D=1` | **0 (Way-0)** |
| **11** | R `0x0000A400` | 0 | `0x29` | Tag `0x13`, `V=1` | Tag `0x35`, `V=1` | **0** | **MISS** | **Evicts Way-0** (clean) | Tag `0x29`, `V=1, D=0` | Tag `0x35`, `V=1, D=1` | **1 (Way-1)** |

### Verification Confirmation:
1. Every victim chosen by `cache_fsm.v` exactly matched `lru_way` output from `lru_state.v`.
2. Clean lines were overwritten without writeback; dirty lines (such as Tag `0x21` at step 4) triggered an explicit `WRITE_BACK` bus transaction before line refill.
3. Every step observed in simulation identically matched the predicted hand calculations.
