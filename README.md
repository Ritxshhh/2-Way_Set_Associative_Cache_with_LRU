# 2-Way Set-Associative Cache with LRU

Modern Computer Architecture — Phase I project. We implement a 2-way set-associative
cache with LRU replacement in Verilog and compare it against a direct-mapped baseline
cache, using identical access traces, to show how associativity affects hit rate,
resource usage, and timing.

## Group Members

| Name | Role |
| --- | --- |
| [Punit Yadav](https://github.com/PunitYadavRao) | Direct-mapped baseline cache; design-parameters doc |
| [Yash Kumar](https://github.com/hypnoastic) | Way-0/Way-1 RAM; memory interface & model; repo lead |
| [Dhruv Kumar](https://github.com/drv-01) | Valid bits & LRU state; tag comparators |
| [Ritesh](https://github.com/Ritxshhh) | Cache controller FSM; top-level integration; video lead |
| [Parul Nehra](https://github.com/parul-nehra) | Verification (traces, testbench), synthesis, hit-rate analysis |

## Demo Video

Watch the Phase I demo: [`report/MCA_Phase1.mov`](report/MCA_Phase1.mov).

## Design Parameters

Both caches hold the same 2 KB of data so the comparison is apples-to-apples.

| Parameter | Direct-mapped (baseline) | 2-way set-associative |
| --- | --- | --- |
| Address width | 32 bit | 32 bit |
| Block size | 16 bytes (4×32-bit words) | 16 bytes (4×32-bit words) |
| Total cache data | 2 KB | 2 KB |
| Lines / sets | 128 lines | 64 sets × 2 ways |
| Offset bits | 4 | 4 |
| Index bits | 7 | 6 |
| Tag bits | 21 | 22 |
| Replacement policy | n/a — one line per index | LRU, 1 bit per set |

The table above records the agreed design parameters.

## Repository Structure

```
.
├── rtl/            Verilog sources (both caches + shared submodules)
├── tb/             Testbenches
├── sim/            Simulation scripts, waveforms, and sim/traces/ (access-trace files)
├── synth/          Synthesis utilization & timing reports
├── docs/           hit_rate_analysis.md, verification.md, member_handoff.md, video_script.md
├── report/         IEEE report source + exported PDF
└── README.md
```

## RTL Modules

| File | Purpose |
| --- | --- |
| `rtl/direct_mapped_cache.v` | Baseline direct-mapped cache controller |
| `rtl/way_data_ram.v`, `rtl/way_tag_ram.v` | Per-way data & tag storage (instantiated twice: Way-0, Way-1) |
| `rtl/valid_bits.v` | Per-way valid bits (2 per set) |
| `rtl/lru_state.v` | Per-set LRU bit, updated on every hit and fill |
| `rtl/tag_comparator.v` | Tag match / hit-way select logic |
| `rtl/cache_fsm.v` | 2-way cache controller FSM |
| `rtl/mem_model.v` | Behavioral main-memory model with configurable fetch latency |
| `rtl/cache_2way_top.v` | Top-level 2-way set-associative cache (integrates all of the above) |

## Building & Running

Install Icarus Verilog (macOS: `brew install icarus-verilog`), then from the repo root:

```sh
# Run full verification suite (unit tests, memory tests, smoke tests, trace benchmarks):
make test
```

**Regenerate access traces:**

```sh
make traces
# Or directly: python3 sim/gen_traces.py
```

**Run trace-driven direct-mapped vs. 2-way comparison:**

```sh
make test-traces
```

Per-access logs are written to `sim/results_direct.log` and `sim/results_2way.log`. Detailed architectural findings and trade-offs are documented in [`docs/hit_rate_analysis.md`](docs/hit_rate_analysis.md) and [`synth/synthesis_summary.md`](synth/synthesis_summary.md).

**Re-run FPGA synthesis (Vivado batch mode):**

```sh
cd synth
vivado -mode batch -source synth_direct_mapped.tcl
vivado -mode batch -source synth_cache_2way.tcl
```

## Contributing

Repository: [Ritxshhh/2-Way_Set_Associative_Cache_with_LRU](https://github.com/Ritxshhh/2-Way_Set_Associative_Cache_with_LRU).
Each teammate commits and pushes their own work using their own GitHub account.

## Report & Submission

- IEEE report: [`report/IEEE_report.pdf`](report/IEEE_report.pdf)
- Verification report: [`docs/verification.md`](docs/verification.md)
- Hit-rate & architecture evaluation: [`docs/hit_rate_analysis.md`](docs/hit_rate_analysis.md)
- Synthesis summary: [`synth/synthesis_summary.md`](synth/synthesis_summary.md)
- RAM/memory integration and ownership: [member handoff](docs/member_handoff.md).
