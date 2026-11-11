#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0


import argparse
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, List, Optional, TextIO

from shared.testcase import AccTestCase
from sim.load_elf import load_elf
from sim.standalonesim import StandaloneSim
from sim.stats import ExecutionStatAnalyzer


@dataclass(frozen=True)
class SimOptions:
    elf: Path
    dump_stats: Optional[TextIO] = None
    dump_regs: Optional[TextIO] = None
    dump_dmem: Optional[BinaryIO] = None
    pqc: bool = False
    dump_rtl_sim: bool = False
    testcase: Optional[TextIO] = None
    verbose: bool = False


def standlone_sim(options: SimOptions) -> int:

    collect_stats = options.dump_stats is not None

    # Check if Bazel is requesting coverage output
    coverage_dat = os.environ.get("COVERAGE_OUTPUT_FILE", None)
    if coverage_dat:
        collect_stats = True

    sim = StandaloneSim(options.pqc)
    exp_end_addr = load_elf(sim, str(options.elf), options.dump_rtl_sim)

    testcase = None
    if options.testcase is not None:
        testcase = AccTestCase.from_hjson(options.testcase.read(), sim.symbols)

    key0 = int((str("deadbeef") * 12), 16)
    key1 = int((str("baadf00d") * 12), 16)
    sim.state.wsrs.set_sideload_keys(key0, key1)

    if testcase:
        sim.load_dmem_vars(testcase.input.dmem)
        sim.load_regs_vars(testcase.input.regs)

    sim.state.ext_regs.commit()

    sim.start(collect_stats)

    if testcase and testcase.entrypoint:
        sim.state.pc = testcase.entrypoint

    sim.run(verbose=options.verbose, dump_file=options.dump_regs)

    if exp_end_addr is not None:
        if sim.state.pc != exp_end_addr:
            print(
                "Run stopped at PC {:#x}, but _expected_end_addr was {:#x}.".format(
                    sim.state.pc, exp_end_addr
                ),
                file=sys.stderr,
            )
            return 1

    if options.dump_dmem is not None:
        options.dump_dmem.write(sim.dump_data())

    if collect_stats:
        assert sim.stats is not None
        stat_analyzer = ExecutionStatAnalyzer(sim.stats, str(options.elf))
        if options.dump_stats:
            options.dump_stats.write(stat_analyzer.dump())
        if coverage_dat:
            with open(coverage_dat, "w") as f:
                f.write(stat_analyzer.dump_lcov_coverage())
            print(f"Coverage dumped to {coverage_dat}")

    return 0


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("elf")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("--dump-rtl-sim", action="store_true")
    parser.add_argument(
        "--testcase",
        type=argparse.FileType("r"),
        metavar="FILE",
        help="Path to a testcase hjson file.",
    )
    parser.add_argument(
        "--dump-dmem",
        metavar="FILE",
        type=argparse.FileType("wb"),
        help=(
            "after execution, write the data memory contents to this file. "
            "Use '-' to write to STDOUT."
        ),
    )
    parser.add_argument(
        "--dump-regs",
        metavar="FILE",
        type=argparse.FileType("w"),
        help=(
            "after execution, write the GPR and WDR contents to this file. "
            "Use '-' to write to STDOUT."
        ),
    )
    parser.add_argument(
        "--dump-stats",
        metavar="FILE",
        type=argparse.FileType("w"),
        help=(
            "after execution, write execution statistics to this file. Use '-' to write to STDOUT."
        ),
    )
    parser.add_argument(
        "--pqc",
        type=bool,
        help=("set accsim to PQC feature mode for ML-KEM and ML-DSA."),
    )

    args = parser.parse_args(argv[1:])

    sim_options = SimOptions(
        dump_stats=args.dump_stats,
        dump_regs=args.dump_regs,
        dump_dmem=args.dump_dmem,
        pqc=args.pqc,
        elf=args.elf,
        dump_rtl_sim=args.dump_rtl_sim,
        testcase=args.testcase,
        verbose=args.verbose,
    )

    return standlone_sim(sim_options)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
