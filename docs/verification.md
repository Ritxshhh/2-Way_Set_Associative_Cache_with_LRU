# Verification — 2026-11-16

Tool: Icarus Verilog 13.0. Command: `make test`. All checks passed.

| Test | Expected and observed |
| --- | --- |
| Set 0 full fill | CAFE0000000000000000000000000000, tag 123456 |
| Set 5 full fill | 11112222333344445555666677778888, tag 234567 |
| Set isolation | Set 0 retains original data/tag after set 5 write |
| Asynchronous reads | Both sets read correctly without a clock edge |
| Partial write 0001 | Set 5 becomes 111122223333444455556666DEADBEEF; tag unchanged |
| Write disabled / zero mask | Existing data and tag retained |
| Read address 12B | A5A50012 repeated four times (offset ignored) |
| Write address 12F, read 120 | 0123456789ABCDEFFEDCBA9876543210 |
| Memory latency | Exactly 6 edges after acceptance; also passed parameters 1 and 3 |
| Ready pulse | High for exactly one cycle after each read/write |
| Latched request | Changing address/data while busy does not alter result |

Existing `tb_cache_2way_smoke` compiled using real `rtl/*.v` and passed:
MISS,HIT,MISS,HIT,HIT,MISS; final victim Way-0. It uses inline memory.
Top-level wiring was adjusted to the actual Member 3 interfaces as well as
new RAM ports. No FSM behavior changed.

Icarus warns that RTL modules omit explicit time units; these modules use no
simulation delays. Testbenches specify 1ns/1ps. No Vivado synthesis or full
cache comparison was performed.

The specified module tests are complete. External handoff delivery, unknown
profile/video links, and each teammate's future personal pushes remain team actions.
