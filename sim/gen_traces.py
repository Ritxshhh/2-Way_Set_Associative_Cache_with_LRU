#!/usr/bin/env python3
"""
gen_traces.py - Access trace generator for cache benchmark comparison.

Generates three access trace workloads:
  1. random.trc   - Uniformly distributed random addresses (low locality)
  2. locality.trc - Loop-based accesses with high temporal and spatial locality
  3. conflict.trc - Stride-based accesses mapping to conflicting cache sets

Trace Format:
  <OP> <ADDR> <WDATA>
  where OP is 'R' (read) or 'W' (write),
  ADDR is 32-bit hex (word-aligned, low 2 bits = 00),
  WDATA is 32-bit hex (ignored for reads).
"""

import os
import random

TRACE_DIR = os.path.join(os.path.dirname(__file__), "traces")
os.makedirs(TRACE_DIR, exist_ok=True)

# Word alignment mask within 64 KB memory space (0x0000 to 0xFFFC)
MAX_BLOCK = 4095  # 4096 lines of 16 bytes = 65536 bytes
ADDR_MASK = 0x0000FFFC

def write_trace(filename, accesses):
    filepath = os.path.join(TRACE_DIR, filename)
    with open(filepath, "w") as f:
        for op, addr, wdata in accesses:
            f.write(f"{op} {addr:08x} {wdata:08x}\n")
    print(f"Generated {filepath} ({len(accesses)} operations)")

def gen_random(n=500, seed=42):
    random.seed(seed)
    accesses = []
    for _ in range(n):
        op = "W" if random.random() < 0.25 else "R"
        # Word aligned address in 0x0000..0xFFFC
        addr = (random.randint(0, MAX_BLOCK * 4) * 4) & ADDR_MASK
        wdata = random.randint(0, 0xFFFFFFFF) if op == "W" else 0
        accesses.append((op, addr, wdata))
    return accesses

def gen_locality(n_loops=10, loop_len=16, seed=123):
    """
    Simulates program execution:
    - Frequent sequential reads within a local array (spatial locality)
    - Repeated iterations over the same working set (temporal locality)
    - Occasional writes back to the working set
    """
    random.seed(seed)
    accesses = []
    base_array = 0x00000100
    stack_base = 0x00000800

    for _ in range(n_loops):
        # Sequential scan over small working set
        for i in range(loop_len):
            addr = (base_array + i * 4) & ADDR_MASK
            op = "W" if random.random() < 0.20 else "R"
            wdata = 0xA0000000 | i
            accesses.append((op, addr, wdata))

        # Access local stack variables
        for s in range(4):
            addr = (stack_base + s * 4) & ADDR_MASK
            accesses.append(("W", addr, 0x55550000 | s))
            accesses.append(("R", addr, 0))

    return accesses

def gen_conflict(n_reps=30, seed=999):
    """
    Adversarial conflict pattern:
    Models two interleaved arrays A and B that alias to the exact same cache sets.
    Array A: 0x00001000 .. (index 0 for DM and 2W)
    Array B: 0x00001800 .. (index 0 for DM and 2W)
    Each line holds 4 words. We access A[0], B[0], A[1], B[1], A[2], B[2], A[3], B[3].
    In Direct-Mapped:
      A and B alternate on the same single line, evicting each other on EVERY access!
      Result: 0% hit rate (thrashing).
    In 2-Way Set-Associative:
      A occupies Way-0, B occupies Way-1.
      Subsequent word accesses [1..3] hit in their respective ways!
      Result: ~75% hit rate.
    """
    random.seed(seed)
    accesses = []
    base_A = 0x00001000
    base_B = 0x00001800

    for rep in range(n_reps):
        # Scan 4 sets, with 4 words per set
        for s in range(4):
            set_offset = s * 16
            for w in range(4):
                word_offset = w * 4
                addr_A = (base_A + set_offset + word_offset) & ADDR_MASK
                addr_B = (base_B + set_offset + word_offset) & ADDR_MASK
                accesses.append(("R", addr_A, 0))
                accesses.append(("R", addr_B, 0))

    return accesses

if __name__ == "__main__":
    write_trace("random.trc", gen_random(400))
    write_trace("locality.trc", gen_locality(n_loops=15, loop_len=16))
    write_trace("conflict.trc", gen_conflict(n_reps=50))
