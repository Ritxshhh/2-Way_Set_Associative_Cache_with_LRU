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
| Parul | Verification (traces, testbench), synthesis, hit-rate analysis |

## Demo Video

Demo video pending recording/upload. Parul’s GitHub profile is pending confirmation.

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

Install Icarus Verilog (macOS: `brew install icarus-verilog`), then from the repo root:

```sh
make test
```

This runs `tb_way_ram` and `tb_mem_model` (memory latencies 6, 1, and 3).
Every check prints PASS or terminates with a nonzero failure. See
[verification results](docs/verification.md) for tested values and timing.

Run the existing integrated smoke test with the real modules:

```sh
mkdir -p sim/build
iverilog -g2012 -s tb_cache_2way_smoke -o sim/build/cache.vvp rtl/*.v tb/tb_cache_2way_smoke.v
vvp sim/build/cache.vvp
```

Do not compile `tb/stubs/submodule_stubs.v` with real RTL: module names overlap.
The smoke test uses its own inline memory; the dedicated memory test verifies
`rtl/mem_model.v`. See the [Member 3 and 4 port handoff](docs/member_handoff.md)
for interfaces, memory range, request protocol, and personal commit instructions.

`sim/traces`, `synth`, and `docs` are present for later trace analysis,
synthesis reports, and documentation. Trace generation, cache comparison,
and Vivado synthesis scripts are pending their owners' contributions.

## Contributing

Repository: [Ritxshhh/2-Way_Set_Associative_Cache_with_LRU](https://github.com/Ritxshhh/2-Way_Set_Associative_Cache_with_LRU).
Each teammate must commit and push their own work using their own GitHub account.
This change is authored as Yash Kumar. GitHub contributor records verify
`drv-01` and `PunitYadavRao`; the repository owner is `Ritxshhh`.
The local authenticated account is `hypnoastic`. Other teammates' future pushes
must be completed by those teammates; this repository cannot enforce their identity.

## Report & Submission

- IEEE report: [`report/IEEE_report.pdf`](report/IEEE_report.pdf)
- RAM/memory integration and ownership: [member handoff](docs/member_handoff.md).
