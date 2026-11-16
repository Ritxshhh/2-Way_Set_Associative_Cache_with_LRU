#!/usr/bin/env python3
"""
sim/gen_traces.py - Access trace generator for cache benchmark comparison.
Python 3, standard library only.

Generates three access trace workloads:
  1. random.trc   - Uniformly distributed random addresses (low locality)
  2. locality.trc - 90% accesses to a fixed 8-block working set, 10% random
  3. conflict.trc - Two colliding addresses alternating (worst-case for direct-mapped)

Output format per line:
  R 0xXXXXXXXX
  W 0xXXXXXXXX
"""

import os
import random
from collections import Counter

# 4096 blocks of 16 bytes = 64 KB memory space (0x00000000 to 0x0000FFF0)
MAX_BLOCK_IDX = 0x0FFF  # 4095
ADDR_MASK = MAX_BLOCK_IDX


def gen_random(n=2000, seed=42):
    """
    1. gen_random(n=2000) -> sim/traces/random.trc:
       Each addr = uniformly random value masked to sensible range, shifted so it's
       block-aligned (addr = random.randint(0, 0xFFFF) << 4 masked to 4096 blocks).
       About 20% writes, 80% reads, chosen randomly per access.
    """
    if seed is not None:
        random.seed(seed)
    accesses = []
    for _ in range(n):
        is_write = (random.random() < 0.20)
        # Block-aligned address within backing store range
        addr = (random.randint(0, 0xFFFF) & ADDR_MASK) << 4
        accesses.append((is_write, addr))
    return accesses


def gen_locality(n=2000, seed=123):
    """
    2. gen_locality(n=2000) -> sim/traces/locality.trc:
       Pick a fixed working set of 8 block-aligned addresses once at the start;
       90% of accesses pick randomly from that set of 8,
       10% pick a fresh random address from the full range (not added to the set).
       About 20% writes, 80% reads.
    """
    if seed is not None:
        random.seed(seed)
    # Pick 8 distinct block-aligned addresses
    working_set = []
    while len(working_set) < 8:
        cand = (random.randint(0, 0xFFFF) & ADDR_MASK) << 4
        if cand not in working_set:
            working_set.append(cand)

    accesses = []
    for _ in range(n):
        is_write = (random.random() < 0.20)
        if random.random() < 0.90:
            addr = random.choice(working_set)
        else:
            addr = (random.randint(0, 0xFFFF) & ADDR_MASK) << 4
        accesses.append((is_write, addr))
    return accesses


def gen_conflict(n=2000):
    """
    3. gen_conflict(n=2000) -> sim/traces/conflict.trc:
       Pick two addresses that collide in the direct-mapped cache's index
       (same addr[10:4]) but differ in tag (addr[31:11]) -- e.g. 0x00000000
       and 0x00000800, the exact pair Member 1 used in their smoke test --
       and alternate A, B, A, B, ... for the whole trace.
    """
    addr_A = 0x00000000
    addr_B = 0x00000800
    accesses = []
    for i in range(n):
        addr = addr_A if (i % 2 == 0) else addr_B
        # Alternate reads between colliding addresses
        accesses.append((False, addr))
    return accesses


def write_trace(filepath, accesses):
    """Write accesses to a file with exact format: R 0xXXXXXXXX or W 0xXXXXXXXX."""
    os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
    with open(filepath, "w") as f:
        for is_write, addr in accesses:
            op = "W" if is_write else "R"
            f.write(f"{op} 0x{addr:08X}\n")


def print_summary(trace_name, accesses):
    """Print unique address count and top 5 most-repeated addresses."""
    counts = Counter(addr for _, addr in accesses)
    print(f"=== Summary for {trace_name} ({len(accesses)} accesses) ===")
    print(f"  Unique address count: {len(counts)}")
    print("  Top 5 most-repeated addresses:")
    for rank, (addr, count) in enumerate(counts.most_common(5), 1):
        pct = (count / len(accesses)) * 100.0
        print(f"    {rank}. 0x{addr:08X}: {count} accesses ({pct:.2f}%)")
    print()


def main():
    trace_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "traces")
    os.makedirs(trace_dir, exist_ok=True)

    # 1. Random trace
    random_path = os.path.join(trace_dir, "random.trc")
    random_acc = gen_random(n=2000)
    write_trace(random_path, random_acc)
    print_summary("random.trc", random_acc)

    # 2. Locality trace
    locality_path = os.path.join(trace_dir, "locality.trc")
    locality_acc = gen_locality(n=2000)
    write_trace(locality_path, locality_acc)
    print_summary("locality.trc", locality_acc)

    # 3. Conflict trace
    conflict_path = os.path.join(trace_dir, "conflict.trc")
    conflict_acc = gen_conflict(n=2000)
    write_trace(conflict_path, conflict_acc)
    print_summary("conflict.trc", conflict_acc)


if __name__ == "__main__":
    main()
