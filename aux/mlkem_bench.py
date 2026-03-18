#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
Collects cycle counts from mlkem bazel test logs, computes averages,
and prints a comparison table (masked vs unmasked, slowdown factors).

Requires: pip install tabulate
"""

import re
import sys
from pathlib import Path
from tabulate import tabulate

# ── Configuration ────────────────────────────────────────────────────────────

BASE_DIR = Path("bazel-testlogs/sw/acc/crypto/tests/mlkem")
SIZES = [512, 768, 1024]
NUM_TESTS = 10               # test indices 0 … 9
CYCLE_LINE = 6               # 0-based index of "ACC executed … in N cycles."
CYCLE_RE = re.compile(r"in\s+([\d,]+)\s+cycles", re.IGNORECASE)


# ── Helpers ──────────────────────────────────────────────────────────────────

def parse_cycles(log_path: Path) -> int:
    """Return the cycle count from a test.log file, or raise on failure."""
    lines = log_path.read_text(errors="replace").splitlines()
    if len(lines) <= CYCLE_LINE:
        raise ValueError(f"File too short ({len(lines)} lines): {log_path}")
    m = CYCLE_RE.search(lines[CYCLE_LINE])
    if not m:
        raise ValueError(f"Cycle pattern not found on line {CYCLE_LINE + 1}: {log_path}")
    return int(m.group(1).replace(",", ""))


def fmt(v: float) -> str:
    return f"{v:,.0f}".replace(",", " ")


def collect_avg(pattern: str, size: int) -> tuple[float, list[int]]:
    """Collect cycle counts for all NUM_TESTS runs and return (average, raw list)."""
    counts = []
    for i in range(NUM_TESTS):
        log = BASE_DIR / pattern.format(size=size, idx=i) / "test.log"
        if not log.exists():
            print(f"  [WARN] Missing: {log}", file=sys.stderr)
            continue
        try:
            counts.append(parse_cycles(log))
        except ValueError as e:
            print(f"  [WARN] {e}", file=sys.stderr)
    if not counts:
        raise RuntimeError(f"No valid logs found for size={size}, pattern='{pattern}'")
    return sum(counts) / len(counts), counts


# ── Collect data ─────────────────────────────────────────────────────────────

MASKED_NOBS_PAT = "mlkem{size}_non_bs_decap_test{idx}_2shares"
MASKED_BS_PAT = "mlkem{size}_decap_test{idx}_2shares"
UNMASKED_PAT = "mlkem{size}_decap_test{idx}_1shares"

rows = []
for size in SIZES:
    masked_bs_avg, masked_bs_raw = collect_avg(MASKED_BS_PAT, size)
    masked_nobs_avg, masked_nobs_raw = collect_avg(MASKED_NOBS_PAT, size)
    unmasked_avg, unmasked_raw = collect_avg(UNMASKED_PAT, size)

    slowdown_nobs_vs_bs = masked_nobs_avg / unmasked_avg if unmasked_avg else float("nan")
    slowdown_bs_vs_plain = masked_bs_avg / unmasked_avg if unmasked_avg else float("nan")

    rows.append({
        "name": f"mlkem{size}",
        "masked_bs": masked_bs_avg,
        "masked_nobs": masked_nobs_avg,
        "unmasked": unmasked_avg,
        "sd_nobs_vs_bs": slowdown_nobs_vs_bs,
        "sd_bs_vs_plain": slowdown_bs_vs_plain,
        "masked_bs_raw": masked_bs_raw,
        "masked_nobs_raw": masked_nobs_raw,
        "unmasked_raw": unmasked_raw,
    })

# ── Build table data ──────────────────────────────────────────────────────────

HEADERS = [
    "Algorithm",
    "Masked non-BS (cycles)",
    "Masked BS (cycles)",
    "Unmasked (cycles)",
    "Slowdown non-BS / unmasked",
    "Slowdown BS / unmasked",
]

table_data = [
    [
        r["name"],
        fmt(r['masked_nobs']),
        fmt(r['masked_bs']),
        fmt(r['unmasked']),
        f"{r['sd_nobs_vs_bs']:.2f}×",
        f"{r['sd_bs_vs_plain']:.2f}×",
    ]
    for r in rows
]

# ── Print terminal table ──────────────────────────────────────────────────────

print("\n=== mlkem decap cycle count comparison ===\n")
print(tabulate(table_data, headers=HEADERS, tablefmt="rounded_outline", colalign=(
    "left", "right", "right", "right", "center", "center"
)))

# ── Print markdown table ──────────────────────────────────────────────────────

# Flatten multi-line headers for markdown (no newlines in md table cells)
MD_HEADERS = [h.replace("\n", " ") for h in HEADERS]

print("\n\n## Markdown\n")
print(tabulate(table_data, headers=MD_HEADERS, tablefmt="github", colalign=(
    "left", "right", "right", "right", "center", "center"
)))

# ── Per-run breakdown ─────────────────────────────────────────────────────────

print("\n\n## Per-run breakdown\n")
for r in rows:
    breakdown = [
        [
            "masked BS",
            len(r["masked_bs_raw"]),
            ", ".join(fmt(v) for v in r["masked_bs_raw"]),
            fmt(r['masked_bs']),
        ],
        [
            "masked non-BS",
            len(r["masked_nobs_raw"]),
            ", ".join(fmt(v) for v in r["masked_nobs_raw"]),
            fmt(r['masked_nobs']),
        ],
        [
            "unmasked",
            len(r["unmasked_raw"]),
            ", ".join(fmt(v) for v in r["unmasked_raw"]),
            fmt(r['unmasked']),
        ],
    ]
    print(f"{r['name']}:")
    print(tabulate(breakdown, headers=["variant", "n", "raw values", "average"],
                   tablefmt="simple", colalign=("left", "center", "left", "right")))
    print()
