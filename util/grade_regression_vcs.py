#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
grade_regression_vcs.py — fetch the URG gradedtests.txt and uniquetests.txt
reports and writes an output hjson file with the corresponding reseed
optimization for the latest run.

For each <unit>-sim-vcs/cov_report it:
  1. Parses the resulting gradedtests.txt and uniquetests.txt
  2. Computes per-test targetcount using
        targetcount = ceil( (1 + A * uniquecount / gradedcount) * gradedcount
                            + basecount )
     with defaults A = 0.5, basecount = 2 per the Test Grading guide.
  3. Writes a combined hjson file with the corresponding reseeds.

Usage:
    ./grade_regression_vcs.py <regression_root> [-o out.hjson] [-A 0.5] [-b 2]
                          [--force] [--skip-csv] [--dry-run]

--force         re-run urg even if grade_report/gradedtests.txt or cov_report/ already exists
--skip-csv      do not generate csv outputs
--dry-run       print urg commands without executing, skip aggregation
"""

from __future__ import annotations
import argparse
import csv
import math
import re
import shutil
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path
import logging as log
import hjson

LICENSE_HEADER = ("Copyright zeroRISC Inc.\n"
                  "Licensed under the Apache License, Version 2.0, see LICENSE for details.\n"
                  "SPDX-License-Identifier: Apache-2.0\n")


def discover_units(root: Path):
    """Yield (unit, cov_merge_dir) for every <unit>-sim-vcs under root."""
    for child in sorted(root.iterdir()):
        if not child.is_dir() or not child.name.endswith("-sim-vcs"):
            continue
        unit = child.name[: -len("-sim-vcs")]
        yield unit, child / "cov_merge"


def run_urg_grade(unit: str, merged: Path, report: Path, dry_run: bool) -> tuple[int, float]:
    """Runs `urg -full64 -dir <merged.vdb> -grade testfile cost cputime
          -report <unit>-sim-vcs/cov_merge/grade_report`
        for the corresponding merged.vdb passed.
    """
    cmd = [
        "urg", "-full64",
        "-dir", str(merged),
        "-grade", "testfile", "cost", "cputime",
        "-report", str(report),
    ]
    if dry_run:
        log.info(f"[{unit}] would run: {' '.join(cmd)}")
        return 0, 0.0

    try:
        report.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        log.error("Failed to create report directory %s: %s", report, e)
        sys.exit(1)

    log_path = report / "urg_grade.log"
    start = time.time()
    try:
        with log_path.open("w") as log_file:
            log_file.write(f"$ {' '.join(cmd)}\n\n")
            log_file.flush()
            proc = subprocess.run(cmd, stdout=log_file, stderr=subprocess.STDOUT)
    except OSError as e:
        log.error("Failed to write to log file %s: %s", log_path, e)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        log.error("Subprocess failed (exit code %d): %s", e.returncode, e)
        sys.exit(1)
    return proc.returncode, time.time() - start


def parse_test_file(path: Path) -> Counter:
    """
    Parses the corresponding graded file and counts the instances of a test
    within that file.
    """
    INDEX_PREFIX_RE = re.compile(r"^\d+\.")  # leading run index
    SEED_SUFFIX_RE = re.compile(r"\.\d+$")   # trailing seed
    counts: Counter = Counter()
    if not path.is_file():
        return counts
    try:
        with path.open() as fh:
            for raw in fh:
                line = raw.strip()
                if not line or line.startswith("#") or line.startswith("//"):
                    continue
                token = line.split()[0]
                name = token.rsplit("/", 1)[-1]
                name = INDEX_PREFIX_RE.sub("", name, 1)
                name = SEED_SUFFIX_RE.sub("", name)
                counts[name] += 1
    except OSError as e:
        log.error("Failed to open graded file %s: %s", path, e)
        sys.exit(1)
    return counts


def compute_targetcount(graded: int, unique: int, A: float, basecount: int) -> int:
    """
    Computes the targetcount based on the following formula:
        targetcount = (1 + A*(uniquecount/gradecount)) * gradecount + basecount
    Rounds up to nearest integer.
    """
    if graded <= 0:
        return basecount
    multiplier = 1.0 + A * (unique / graded)
    return int(math.ceil(multiplier * graded + basecount))


def find_variants(test_list: list[dict]) -> list[dict]:
    """
    Detects and extracts variants from test_list entries.

    Rules:
    1. Explicit "_top_" → always split
    2. Otherwise → split only if prefix (stem) appears multiple times
    """
    # Get top_level variants first
    for entry in test_list:
        name = entry["name"]
        if "_top_" in name:
            base, variant = name.split("_top_", 1)
            entry["name"] = base
            entry["variant"] = variant

    # Count repetitions of stems
    units = {test_dict["name"] for test_dict in test_list}
    prefix_counts = Counter()
    for unit in units:
        parts = unit.split("_")
        for i in range(1, len(parts)):
            prefix = "_".join(parts[:i])
            prefix_counts[prefix] += 1

    # Only consider stems that have been repeated
    valid_stems = {p for p, count in prefix_counts.items() if count > 1}
    for entry in test_list:
        if "variant" in entry:
            continue

        unit = entry["name"]
        parts = unit.split("_")

        # Get the longest stem and treat it as the name
        best_stem = None
        for i in range(1, len(parts)):
            prefix = "_".join(parts[:i])
            if prefix in valid_stems:
                best_stem = prefix

        if best_stem:
            variant = unit[len(best_stem) + 1:]
            entry["name"] = best_stem
            entry["variant"] = variant

    return test_list


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("root", type=Path, help="Regression root (contains <unit>-sim-vcs dirs)")
    ap.add_argument("-o", "--output", type=Path, default=Path("grading_report.hjson"),
                    help="Combined Hjson output path (default: grading_report.hjson)")
    ap.add_argument("-A", type=float, default=0.5, help="Multiplier coefficient A (default: 0.5)")
    ap.add_argument("-b", "--basecount", type=int, default=2, help="Base count (default: 2)")
    ap.add_argument("--force", action="store_true",
                    help="Re-run urg even if grade_report/ or cov_report/ already exists")
    ap.add_argument("--skip-csv", action="store_true",
                    help="Do not generate CSV outputs")
    ap.add_argument("--dry-run", action="store_true",
                    help="Print urg commands without executing; skip aggregation")
    args = ap.parse_args()

    log.basicConfig(format="%(levelname)s: %(message)s", level=log.INFO)

    if not args.root.is_dir():
        log.error(f"{args.root} is not a directory")
        sys.exit(1)

    # -------- Phase 1: Run urg --------
    if args.force:
        if not args.dry_run and shutil.which("urg") is None:
            log.error("`urg` not found on PATH. Source your VCS setup first.")
            sys.exit(1)

        todo, no_vdb, already = [], [], []
        for unit, cov_merge in discover_units(args.root):
            merged = cov_merge / "merged.vdb"
            report = cov_merge / "grade_report"
            if not merged.exists():
                no_vdb.append(unit)
                continue
            todo.append((unit, merged, report))

        log.info(f"Found {len(todo)} unit(s) to grade "
                 f"(skipped {len(no_vdb)} without merged.vdb, "
                 f"{len(already)} already graded)")

        failed = []
        for unit, merged, report in todo:
            log.info(f"[{unit}] urg -grade ...")
            rc, elapsed = run_urg_grade(unit, merged, report, args.dry_run)
            if args.dry_run:
                continue
            if rc == 0:
                log.info(f"[{unit}] ok ({elapsed:.1f}s)")
            else:
                log.warning(f"[{unit}] FAILED rc={rc} (see {report/'urg_grade.log'})")
                failed.append(unit)

        if no_vdb:
            log.warning(f"No merged.vdb for: {', '.join(no_vdb)}")
        if failed:
            log.warning(f"urg failed for {len(failed)} unit(s); continuing to aggregate the rest")

        if args.dry_run:
            sys.exit()

    # -------- Phase 2: Aggregate --------
    rows = []
    per_unit_summary = []
    missing = []
    hjson_entries = []

    for unit, cov_merge in discover_units(args.root):
        if args.force:
            grade_dir = cov_merge / "grade_report"
            graded_path = grade_dir / "gradedtests.txt"
            unique_path = grade_dir / "uniquetests.txt"
        else:
            grade_dir = cov_merge.parent / "cov_report"
            graded_path = grade_dir / "gradedtests.txt"
            unique_path = grade_dir / "uniquetests.txt"

        if not graded_path.is_file():
            missing.append((unit, "gradedtests.txt missing"))
            continue

        graded = parse_test_file(graded_path)
        unique = parse_test_file(unique_path) if unique_path.is_file() else Counter()

        # Sanity check, uniquecount must be smaller or equal to gradecount
        for test in unique:
            if unique[test] > graded.get(test, 0):
                log.error(f"{unit}:{test} uniquecount ({unique[test]}) > "
                          f"gradedcount ({graded.get(test, 0)})")
                sys.exit()

        for test in sorted(graded):
            g = graded[test]
            u = unique.get(test, 0)
            t = compute_targetcount(g, u, args.A, args.basecount)
            hjson_entries.append({
                "test": test,
                "name": unit,
                "reseed": t
            })
            rows.append({
                "unit": unit, "test": test,
                "gradedcount": g, "uniquecount": u, "targetcount": t,
            })

        per_unit_summary.append({
            "unit": unit,
            "num_tests": len(graded),
            "num_unique_contributors": sum(1 for t in graded if unique.get(t, 0) > 0),
            "total_graded_runs": sum(graded.values()),
            "total_unique_runs": sum(unique.values()),
            "total_target_runs": sum(
                compute_targetcount(graded[t], unique.get(t, 0), args.A, args.basecount)
                for t in graded
            ),
        })

    if not args.skip_csv:
        try:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            csv_path = args.output.with_name(args.output.stem + ".hjson")
            with csv_path.open("w", newline="") as fh:
                for line in LICENSE_HEADER.splitlines():
                    fh.write(f"# {line}\n")
                w = csv.DictWriter(fh, fieldnames=["unit", "test", "gradedcount",
                                                   "uniquecount", "targetcount"])
                w.writeheader()
                w.writerows(rows)

            summary_path = args.output.with_name(args.output.stem + "_summary.csv")
            with summary_path.open("w", newline="") as fh:
                for line in LICENSE_HEADER.splitlines():
                    fh.write(f"# {line}\n")
                w = csv.DictWriter(fh, fieldnames=[
                    "unit", "num_tests", "num_unique_contributors",
                    "total_graded_runs", "total_unique_runs", "total_target_runs",
                ])
                w.writeheader()
                w.writerows(per_unit_summary)

            log.info(f"  combined report : {args.output}")
            log.info(f"  per-unit summary: {summary_path}")
        except OSError as e:
            log.error("Failed to write CSV output: %s", e)
            sys.exit(1)

    # -------- Phase 3: Write HJSON --------
    hjson_entries = find_variants(hjson_entries)
    cfg = {
        "reseed": 1,
        "tests": hjson_entries
    }

    hjson_path = args.output.with_name(args.output.stem + ".hjson")
    try:
        with hjson_path.open("w") as fh:
            fh.write("// " + LICENSE_HEADER.replace("\n", "\n// ").rstrip("/ ") + "\n")
            fh.write(hjson.dumps(cfg).rstrip("\n") + "\n")
        log.info(f"  combined reseed hjson: {hjson_path}")
    except OSError as e:
        log.error("Failed to write HJSON output: %s", e)
        sys.exit(1)

    log.info(f"   Aggregated {len(per_unit_summary)} units, {len(rows)} test entries")
    if missing:
        log.warning(f"  skipped {len(missing)} unit(s) with no grade_report:")
        for u, why in missing:
            log.warning(f"    {u}: {why}")


if __name__ == "__main__":
    main()
