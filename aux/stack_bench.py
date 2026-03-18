#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""
For each mlkem variant and size:
  - Resets stack_bench.txt, runs the bazel test, reads back the stack value
  - Runs `size` on the ELF, collects bss and data
  - Computes: data = data_from_elf - 16000, total = stack_bench + bss + data
  - Prints a table per variant + a combined summary

Requires: pip install tabulate
"""

import sys
import subprocess
from pathlib import Path
from tabulate import tabulate

# ── Configuration ─────────────────────────────────────────────────────────────

SIZES = [512, 768, 1024]
DATA_OFFSET = 16_000
LIMIT = 31 * 1024   # 31 KB
STACK_BENCH = Path("stack_bench.txt")
BASE_TARGET = "//sw/acc/crypto/tests/mlkem:"
BASE_ELF = Path("bazel-bin/sw/acc/crypto/tests/mlkem")

VARIANTS = [
    ("Masked non-BS", "mlkem{size}_non_bs_decap_test0_2shares"),
    ("Masked BS", "mlkem{size}_decap_test0_2shares"),
    ("Unmasked", "mlkem{size}_decap_test0_1shares"),
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def fmt(v: int, mark: bool = False) -> str:
    s = f"{v:,}".replace(",", " ")
    if mark and v > LIMIT:
        s += " ⚠"
    return s


def reset_and_run(target_name: str) -> int:
    """Zero stack_bench.txt, run bazel test, return the value written back."""
    STACK_BENCH.write_text("0\n")
    assert STACK_BENCH.read_text().strip() == "0", "stack_bench.txt failed to reset!"
    cwd = Path.cwd()
    cmd = [
        "./bazelisk.sh", "test",
        "--cache_test_results=no",
        f"--sandbox_writable_path={cwd}",
        f"{BASE_TARGET}{target_name}",
    ]
    print(f"    $ {' '.join(cmd)}")
    result = subprocess.run(cmd, text=True,)
    if result.returncode != 0:
        print(f"    [WARN] Test exited with code {result.returncode}", file=sys.stderr)
    raw = STACK_BENCH.read_text().strip()
    try:
        return int(raw)
    except ValueError:
        print(f"    [WARN] Could not parse stack_bench.txt: {raw!r}", file=sys.stderr)
        return 0


def read_elf_size(elf_path: Path) -> tuple[int, int]:
    """Run `size` on the ELF and return (data, bss)."""
    print(f"    $ size {elf_path}")
    result = subprocess.run(["size", str(elf_path)], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"`size` failed for {elf_path}:\n{result.stderr}")
    lines = result.stdout.strip().splitlines()
    if len(lines) < 2:
        raise ValueError(f"Unexpected `size` output:\n{result.stdout}")
    # header: text  data  bss  dec  hex  filename
    parts = lines[1].split()
    return int(parts[1]), int(parts[2])   # data, bss


# ── Collect data ──────────────────────────────────────────────────────────────

# results[variant_label][size] = {stack_bench, bss, data, total}
results: dict[str, dict[int, dict]] = {}

for variant_label, pattern in VARIANTS:
    results[variant_label] = {}
    print(f"\n{'─' * 60}")
    print(f"  Variant: {variant_label}")
    print(f"{'─' * 60}")
    for size in SIZES:
        target = pattern.format(size=size)
        elf = BASE_ELF / f"{target}.elf"
        print(f"\n  mlkem{size}:")

        stack_bench = reset_and_run(target)
        data_raw, bss = read_elf_size(elf)
        data = data_raw - DATA_OFFSET
        total = stack_bench + bss + data

        print(f"    stack_bench={fmt(stack_bench)}  bss={fmt(bss)}  "
              f"data={fmt(data_raw)}-{fmt(DATA_OFFSET)}={fmt(data)}  total={fmt(total)}")

        results[variant_label][size] = {
            "stack_bench": stack_bench,
            "bss": bss,
            "data": data,
            "total": total,
        }

# ── Per-variant tables ────────────────────────────────────────────────────────

PER_HEADERS = ["Algorithm", "Stack bench (B)", "BSS (B)", "Data (B)", "Total (B)"]
PER_METRICS = ("stack_bench", "bss", "data", "total")
PER_ALIGN = ("left", "right", "right", "right", "right")

print("\n\n" + "═" * 60)
print("  RESULTS")
print("═" * 60)

for variant_label, _ in VARIANTS:
    rows = [
        [
            f"mlkem{size}",
            *[fmt(results[variant_label][size][m], mark=(m == "total")) for m in PER_METRICS]
        ]
        for size in SIZES
    ]
    print(f"\n### {variant_label}\n")
    print(tabulate(rows, headers=PER_HEADERS, tablefmt="rounded_outline", colalign=PER_ALIGN))
    if any(results[variant_label][s]["total"] > LIMIT for s in SIZES):
        print("  ⚠ = exceeds 31 KB")

# ── Combined summary table ────────────────────────────────────────────────────

print("\n\n### Combined summary\n")

headers = ["Algorithm"]
for variant_label, _ in VARIANTS:
    short = variant_label.replace("Masked ", "")
    headers += [f"{short} stack bench (B)", f"{short} bss (B)",
                f"{short} data (B)", f"{short} total (B)"]

combined_rows = [
    [f"mlkem{size}"] + [
        fmt(results[vl][size][m], mark=(m == "total"))
        for vl, _ in VARIANTS
        for m in PER_METRICS
    ]
    for size in SIZES
]

print(tabulate(combined_rows,
               headers=headers,
               tablefmt="rounded_outline",
               colalign=("left",) + ("right",) * (len(headers) - 1)))
if any(results[vl][s]["total"] > LIMIT for vl, _ in VARIANTS for s in SIZES):
    print("  ⚠ = exceeds 31 KB")

# ── Markdown ──────────────────────────────────────────────────────────────────

print("\n\n### Markdown (combined)\n")
print(tabulate(combined_rows,
               headers=headers,
               tablefmt="github",
               colalign=("left",) + ("right",) * (len(headers) - 1)))
