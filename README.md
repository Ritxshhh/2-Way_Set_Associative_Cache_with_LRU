# 2-Way Set-Associative Cache with LRU

Modern Computer Architecture — Phase I project. We implement a 2-way set-associative
cache with LRU replacement in Verilog and compare it against a direct-mapped baseline
cache, using identical access traces, to show how associativity affects hit rate,
resource usage, and timing.

## Group Members

| Name | Role |
| --- | --- |
| Punit | Direct-mapped baseline cache; design-parameters doc |
| Yash Kumar | Way-0/Way-1 RAM; memory interface & model; repo lead |
| Dhruv Kumar | Valid bits & LRU state; tag comparators |
| Ritesh | Cache controller FSM; top-level integration; video lead |
| Parul | Verification (traces, testbench), synthesis, hit-rate analysis |

## Demo Video

[Prototype demo video (≤5 min)](<video-link-here>)

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

Full write-up: [`docs/design_parameters.md`](docs/design_parameters.md)

## Repository Structure

```
.
├── rtl/            Verilog sources (both caches + shared submodules)
├── tb/             Testbenches
├── sim/            Simulation scripts, waveforms, and sim/traces/ (access-trace files)
├── synth/          Synthesis utilization & timing reports
├── docs/           design_parameters.md, hit_rate_analysis.md, video_script.md
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

> Toolchain: Xilinx Vivado (WebPACK) for simulation + synthesis, or Icarus Verilog +
> GTKWave for simulation only. Replace the commands below with whichever your lab uses.

**Run a single testbench (Icarus Verilog):**

```sh
cd tb
iverilog -o sim_out tb_cache_2way_smoke.v ../rtl/*.v
vvp sim_out
gtkwave dump.vcd   # optional waveform viewing
```

**Regenerate access traces:**

```sh
cd sim
python3 gen_traces.py   # writes sim/traces/random.trc, locality.trc, conflict.trc
```

**Run the direct-mapped vs. 2-way comparison:**

```sh
cd tb
iverilog -o compare_out tb_compare.v ../rtl/*.v
vvp compare_out +trace=../sim/traces/conflict.trc
```

Hit-rate and resource results are written up in [`docs/hit_rate_analysis.md`](docs/hit_rate_analysis.md)
and [`synth/synthesis_summary.md`](synth/synthesis_summary.md).

**Re-run synthesis (Vivado, batch mode):**

```sh
cd synth
vivado -mode batch -source synth_direct_mapped.tcl
vivado -mode batch -source synth_cache_2way.tcl
```

## Report & Submission

- IEEE report: [`report/IEEE_report.pdf`](report/IEEE_report.pdf)
- Full task checklist and per-member task breakdown: see the project plan doc.