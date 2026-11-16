# Prototype Demo Video — Script

**Limit:** 5:00 hard cap. Aim for about 4:30 so there's slack.
**Format:** screen recording (slides or the IEEE report PDF, plus a terminal), with each member speaking their own part.
**Rubric checklist:** project idea ✔ (0:00), all 5 names ✔ (0:00), Verilog and block diagrams ✔ (1:00–2:45), working prototype ✔ (2:45–4:15).

---

## 0:00–0:35 — Introduction (Ritesh)

**Show:** title slide or the first page of `report/IEEE_report.pdf`.

> "Hi, we're Group ___. Our Phase I project is a 2-way set-associative cache with
> LRU replacement, written in Verilog, which we compare against a direct-mapped
> cache of the same 2 KB size.
> The team is Punit Yadav, Yash Kumar, Dhruv Kumar, Parul Nehra, and me, Ritesh.
> Each of us will walk through the part we built."

## 0:35–1:00 — The problem (Punit)

**Show:** the design-parameters table (Table I in the report, or the README).

> "A direct-mapped cache gives every memory block exactly one place to live. Two
> addresses that share an index keep evicting each other, even if the rest of
> the cache is empty. These are conflict misses. Both of our caches hold 2 KB in
> 16-byte blocks: the direct-mapped one has 128 lines, and the 2-way one has
> 64 sets of two ways, so any difference comes from associativity, not size.
> I built the direct-mapped baseline we compare against."

## 1:00–2:00 — Architecture and modules (Yash, Dhruv)

**Show:** Fig. 1 (block diagram), then briefly open `rtl/way_data_ram.v` and `rtl/lru_state.v`.

**Yash (~30 s):**
> "Each way has its own data RAM and tag RAM: 64 lines of 128 bits, with
> per-word write enables so a store updates one word and a fill writes the whole
> line. I also wrote the main-memory model with a configurable latency, which
> both caches talk to."

**Dhruv (~30 s):**
> "Two valid bits per set say which ways hold real data. The tag comparator
> checks both ways in parallel and reports hit and which way hit. For two ways,
> true LRU needs only one bit per set: every hit or fill marks that way as most
> recently used, so the bit always points at the way to evict next."

## 2:00–2:45 — Controller FSM and integration (Ritesh)

**Show:** Table II (state table), then `rtl/cache_fsm.v` and `rtl/cache_2way_top.v`.

> "The controller is a seven-state FSM. On a request it latches the address and
> checks both tags. A hit returns or updates the word and marks that way most
> recently used. On a miss, it reads the LRU bit to pick a victim, writes it
> back to memory only if it's dirty, fetches the new block, fills the victim
> way, and retries, so the retry is a guaranteed hit. The dirty bits live in the
> FSM. `cache_2way_top` wires all of these modules together, behind exactly
> the same ports as the direct-mapped cache, so one testbench drives both."

## 2:45–4:15 — Live demo (Parul, with Ritesh at the keyboard)

**Show:** a terminal at the repo root. Run each command live; the output appears in a few seconds.

1. `make test-2way` (~20 s)
   > "Our smoke test does six reads to the same set. Watch steps 3 and 4: after
   > address 0x400 comes in, 0x000 still hits, because the two blocks sit in
   > different ways. On step 6 the set is full, and the FSM evicts exactly the
   > way the LRU bit predicts: Way-0."

2. `make test-compare` (~25 s)
   > "Now both caches get the same alternating addresses, 0x000 and 0x800. The
   > direct-mapped cache misses all five times; it thrashes. The 2-way cache
   > misses only on the two cold fills, then hits every time."

3. `make test-traces` (~35 s; scroll to the three summary boxes)
   > "Finally, 2,000-access traces with a golden model checking every read.
   > Zero data mismatches for both caches. On the conflict trace the
   > direct-mapped hit rate is 0% and the 2-way is 99.9%. On the locality trace
   > the 2-way cache cuts average access time from 3.06 to 1.90 cycles. On
   > purely random addresses neither cache helps much, which is what we expect."

4. *(Optional, if time allows)* open `dump.vcd` from `make test-2way` in GTKWave, with `clk`, `cpu_addr`, `cpu_ready`, `mem_re`, `dut.u_fsm.state` and `dut.lru_way`, and point at a miss followed by a hit.

5. `make test` (~10 s, just show the end)
   > "The full suite — every module, both caches, write-back, and the traces —
   > passes: 63 checks, zero failures."

## 4:15–4:35 — Wrap-up (Parul)

**Show:** Table III in the report, or the README.

> "So the 2-way cache keeps both conflicting blocks where the direct-mapped
> cache can't. In the next phase we'll report FPGA area and timing for both
> designs, so the hit-rate gain can be weighed against the hardware it costs.
> Everything is in our GitHub repository. Thanks for watching."

---

## Recording checklist

- [ ] Run `make clean` first, so each command's output looks fresh on screen.
- [ ] Use a large terminal font (≥ 18 pt) and a cleared terminal before each command.
- [ ] Do one dry run with a timer; cut words, not demo steps, if it runs over 4:45.
- [ ] Every member's name is said aloud in the intro.
- [ ] Upload the video, then replace "Demo video pending recording/upload." in `README.md` with the link.
