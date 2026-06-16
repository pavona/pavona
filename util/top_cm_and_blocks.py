#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Either check countermeasures of each IP block or list all IP blocks within a
given top (from the complete config)."""
import argparse
import logging as log
from pathlib import Path
from typing import Dict
from basegen.typing import ConfigT
from topgen.typing import IpBlocksT
from topgen.lib import load_cfg, get_ip_hjson_path, get_top_reggen_modules, get_ipgen_modules
from reggen.countermeasure import CounterMeasure
from reggen.ip_block import IpBlock


REPO_TOP = Path(__file__).parents[1].resolve()


def check_countermeasures(completecfg: ConfigT, name_to_block: IpBlocksT,
                          name_to_hjson: Dict[str, Path], args: argparse.Namespace) -> bool:
    success = True
    for name, hjson_path in name_to_hjson.items():
        log.debug("name %s, hjson %s", name, hjson_path)
        sv_files = (hjson_path.parents[1] / 'rtl').glob('*.sv')
        rtl_names = CounterMeasure.search_rtl_files(sv_files)
        log.debug("Checking countermeasures for %s.", name)
        success &= name_to_block[name].check_cm_annotations(
            rtl_names, hjson_path.name)
        success &= name_to_block[name].check_regwens()
    if success:
        log.info("All Hjson declared countermeasures are implemented in RTL.")
    else:
        log.error("Countermeasure checks failed.")
    return success


def get_blocks(completecfg: ConfigT, name_to_block: IpBlocksT,
               name_to_hjson: Dict[str, Path], args: argparse.Namespace) -> bool:
    print("\n".join(name_to_block.keys()))
    return True


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()
    cm = subparsers.add_parser("check_cm",
                               help="Check countermeasures of all modules in"
                               " the top config. All countermeasures declared"
                               " in the module's hjson file should be"
                               " implemented in the RTL, and the RTL should"
                               " only contain countermeasures declared there.")
    cm.set_defaults(func=check_countermeasures)

    gb = subparsers.add_parser("get_blocks",
                               help="Print the list of IP blocks.")
    gb.set_defaults(func=get_blocks)

    parser.add_argument("--completecfg", "-t",
                        type=Path,
                        required=True,
                        help="Complete top configuration Hjson file.")
    parser.add_argument("--filter", "-f",
                        type=str,
                        default=None,
                        nargs="?",
                        choices={"top-only", "ipgen", "generic"},
                        help="Filter output. Must be one of 'top-only', 'ipgen', or 'generic'.")
    parser.add_argument("--verbose", "-v", action="store_true")
    args = parser.parse_args()

    if args.verbose:
        log.basicConfig(format="%(levelname)s: %(message)s",
                        level=log.DEBUG)
    else:
        log.basicConfig(format="%(levelname)s: %(message)s",
                        level=log.INFO)

    completecfg = load_cfg(args.completecfg)
    if args.filter:
        top_reggen = get_top_reggen_modules(completecfg)
        top_ipgen = get_ipgen_modules(completecfg)

    name_to_block = {}
    name_to_hjson = {}
    for module in completecfg["module"]:
        block_type = module["type"]

        block_filtered_out = (
            (args.filter == "top-only" and block_type not in top_reggen)
            or (args.filter == "ipgen" and block_type not in top_ipgen)
            or (args.filter == "generic" and block_type in top_reggen + top_ipgen))
        if block_filtered_out:
            continue

        ip_hjson = get_ip_hjson_path(block_type, completecfg, REPO_TOP)
        name_to_block[block_type] = IpBlock.from_path(str(ip_hjson), [])
        name_to_hjson[block_type] = ip_hjson

    success = args.func(completecfg, name_to_block, name_to_hjson, args)
    exit(0 if success else 1)


if __name__ == "__main__":
    main()
