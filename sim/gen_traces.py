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

def gen_conflict(n_reps=40, seed=999):
    """
    Adversarial conflict pattern:
    Multiple addresses that map to the exact same cache set (same index bits [10:4] in DM, [9:4] in 2W).
    In DM: index = addr[10:4]. Stride of 0x0800 (2048 B) gives same index with differing tags.
    In 2W: index = addr[9:4]. Stride of 0x0400 (1024 B) gives same set index.
    Alternating between 3 conflicting tags on set 0 forces direct-mapped to thrash on every access,
    while 2-way LRU absorbs two active lines.
    """
    random.seed(seed)
    accesses = []
    # 3 addresses all mapping to set index 0:
    # Addr 0: 0x00000000 (tag 0)
    # Addr 1: 0x00000800 (DM tag 1, 2W set 0, 2W tag 2)
    # Addr 2: 0x00001000 (DM tag 2, 2W set 0, 2W tag 4)
    conflict_addrs = [0x00000000, 0x00000800, 0x00001000]

    for rep in range(n_reps):
        for idx, addr in enumerate(conflict_addrs):
            op = "W" if (rep % 4 == 0 and idx == 0) else "R"
            wdata = 0xDEAD0000 | rep
            accesses.append((op, addr, wdata))

    return accesses

if __name__ == "__main__":
    write_trace("random.trc", gen_random(400))
    write_trace("locality.trc", gen_locality(n_loops=15, loop_len=16))
    write_trace("conflict.trc", gen_conflict(n_reps=50))
