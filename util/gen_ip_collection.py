#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
gen_ip_collection.py
Collects IP and top-level sim cfg files and generates batch hjson files.
Usage:
    ./gen_ip_collection.py --flow uvm_dv --tops top_earlgrey top_darjeeling
"""
import argparse
import glob
import os
from pathlib import Path

COPYRIGHT_HEADER = """\
// Copyright zeroRISC Inc.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0"""

# =============================
#   Specific to uvm_dv flow
# =============================

def collect_uvm_dv(tops):
    """
    Collect all sim_cfg hjson files into two buckets:
      - ip_cfgs:  shared across all tops (hw/ip/... and hw/dv/...)
      - top_cfgs: dict keyed by topname, each containing top-specific cfgs
    """
    ip_cfgs = []
    top_cfgs = {top: [] for top in tops}

    def skip(sim_name):
        return "base" in sim_name

    # ---- IP bucket ----

    # Pattern 1: hw/ip/{ip_name}/dv/{sim_cfg}
    for cfg in sorted(glob.glob("hw/ip/*/dv/*_sim_cfg.hjson")):
        sim_name = Path(cfg).stem.replace("_sim_cfg", "")
        if skip(sim_name):
            continue
        ip_cfgs.append(cfg)

    # Pattern 2: hw/ip/{ip_name}/dv/uvm/{sim_cfg}
    for cfg in sorted(glob.glob("hw/ip/*/dv/uvm/*_sim_cfg.hjson")):
        sim_name = Path(cfg).stem.replace("_sim_cfg", "")
        if skip(sim_name):
            continue
        ip_cfgs.append(cfg)

    # Pattern 3: hw/ip/prim/dv/{prim_variant}/{sim_cfg}
    for cfg in sorted(glob.glob("hw/ip/prim/dv/*/*_sim_cfg.hjson")):
        sim_name = Path(cfg).stem.replace("_sim_cfg", "")
        if skip(sim_name):
            continue
        ip_cfgs.append(cfg)

    # Pattern 4: tl_agent
    for cfg in sorted(glob.glob("hw/dv/sv/*/*/*_sim_cfg.hjson")):
        ip_cfgs.append(cfg)

    # ---- Top-specific bucket ----

    for top in tops:
        # Pattern 5: hw/{top}/ip_autogen/{ip_name}/dv/{sim_cfg}
        for cfg in sorted(glob.glob(f"hw/{top}/ip_autogen/*/dv/*_sim_cfg.hjson")):
            sim_name = Path(cfg).stem.replace("_sim_cfg", "")
            if skip(sim_name):
                continue
            top_cfgs[top].append(cfg)

        # Pattern 6: hw/{top}/ip_autogen/{ip_name}/dv/{subdir}/{sim_cfg}
        for cfg in sorted(glob.glob(f"hw/{top}/ip_autogen/*/dv/*/*_sim_cfg.hjson")):
            sim_name = Path(cfg).stem.replace("_sim_cfg", "")
            if skip(sim_name):
                continue
            top_cfgs[top].append(cfg)

        # Pattern 7: hw/{top}/ip/{xbar_name}/dv/autogen/{sim_cfg}
        for cfg in sorted(glob.glob(f"hw/{top}/ip/*/dv/autogen/*_sim_cfg.hjson")):
            top_cfgs[top].append(cfg)

        # Pattern 8: hw/{top}/dv/{sim_cfg} (chip-level)
        for cfg in sorted(glob.glob(f"hw/{top}/dv/*_sim_cfg.hjson")):
            top_cfgs[top].append(cfg)

    return ip_cfgs, top_cfgs


def format_use_cfgs(cfgs, indent=13):
    """Format a list of cfg paths as hjson use_cfgs entries."""
    lines = []
    pad = " " * indent
    for cfg in cfgs:
        lines.append(f'{pad}"{{proj_root}}/{cfg}",')
    return "\n".join(lines)


def generate_top_hjson(top, ip_cfgs, top_specific_cfgs):
    """Generate hjson for a single top: hw/{top}/dv/{top}_sim_cfgs.hjson"""
    all_cfgs = ip_cfgs + top_specific_cfgs

    # Split into comment sections for readability
    tl_agent_cfgs = [c for c in all_cfgs if "hw/dv/sv/" in c]
    pure_ip_cfgs  = [c for c in all_cfgs if "hw/ip/" in c]
    autogen_cfgs  = [c for c in all_cfgs if f"hw/{top}/ip_autogen/" in c
                                         or f"hw/{top}/ip/" in c]
    chip_cfgs     = [c for c in all_cfgs if f"hw/{top}/dv/" in c]

    sections = []
    if tl_agent_cfgs:
        sections.append(
            "             // Unit tests for UVCs.\n" +
            format_use_cfgs(tl_agent_cfgs)
        )
    if pure_ip_cfgs:
        sections.append(
            "             // IPs.\n" +
            format_use_cfgs(pure_ip_cfgs)
        )
    if autogen_cfgs:
        sections.append(
            "             // Top level IPs.\n" +
            format_use_cfgs(autogen_cfgs)
        )
    if chip_cfgs:
        sections.append(
            "             // Top level.\n" +
            format_use_cfgs(chip_cfgs)
        )

    use_cfgs_body = "\n".join(sections)

    return f"""{COPYRIGHT_HEADER}
{{
  // This is a cfg hjson group for DV simulations. It includes ALL individual DV simulation
  // cfgs of the IPs and the full chip used in {top}. This enables the common
  // regression sets to be run in one shot.
  name: {top}_batch_sim
  import_cfgs: [// Project wide common cfg file
                "{{proj_root}}/hw/data/common_project_cfg.hjson"]
  flow: sim
  rel_path: "hw/{top}/dv/summary"
  // Maintain alphabetical order below.
  use_cfgs: [
{use_cfgs_body}
            ]
}}
"""


def generate_global_hjson(ip_cfgs, top_cfgs, tops):
    """Generate hw/dv/top_sim_cfgs.hjson containing everything."""
    sections = []

    tl_agent_cfgs = [c for c in ip_cfgs if "hw/dv/sv/" in c]
    pure_ip_cfgs  = [c for c in ip_cfgs if "hw/ip/" in c]

    if tl_agent_cfgs:
        sections.append(
            "             // Unit tests for UVCs.\n" +
            format_use_cfgs(tl_agent_cfgs)
        )
    if pure_ip_cfgs:
        sections.append(
            "             // IPs.\n" +
            format_use_cfgs(pure_ip_cfgs)
        )

    for top in tops:
        cfgs = top_cfgs[top]
        autogen_cfgs = [c for c in cfgs if f"hw/{top}/ip_autogen/" in c
                                        or f"hw/{top}/ip/" in c]
        chip_cfgs    = [c for c in cfgs if f"hw/{top}/dv/" in c]

        if autogen_cfgs:
            sections.append(
                f"             // {top} IPs.\n" +
                format_use_cfgs(autogen_cfgs)
            )
        if chip_cfgs:
            sections.append(
                f"             // {top} chip.\n" +
                format_use_cfgs(chip_cfgs)
            )

    use_cfgs_body = "\n".join(sections)

    return f"""{COPYRIGHT_HEADER}
{{
  // This is a cfg hjson group for DV simulations. It includes ALL individual DV simulation
  // cfgs across all IPs and tops in the project.
  name: all_tops_batch_sim
  import_cfgs: [// Project wide common cfg file
                "{{proj_root}}/hw/data/common_project_cfg.hjson"]
  flow: sim
  rel_path: "hw/dv/summary"
  // Maintain alphabetical order below.
  use_cfgs: [
{use_cfgs_body}
            ]
}}
"""


def write_file(path, content, dry_run):
    if dry_run:
        print(f"\n{'=' * 60}")
        print(f"Would write: {path}")
        print('=' * 60)
        print(content)
    else:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(content)
        print(f"Written: {path}")


def run_uvm_dv(tops, dry_run):
    print("Collecting uvm_dv sim_cfg files...")
    ip_cfgs, top_cfgs = collect_uvm_dv(tops)

    print(f"  Found {len(ip_cfgs)} shared IP cfgs")
    for top, cfgs in top_cfgs.items():
        print(f"  Found {len(cfgs)} cfgs for {top}")

    # Per-top hjson files
    for top in tops:
        content = generate_top_hjson(top, ip_cfgs, top_cfgs[top])
        out_path = f"hw/{top}/dv/{top}_sim_cfgs.hjson"
        write_file(out_path, content, dry_run)

    # Global hjson file
    content = generate_global_hjson(ip_cfgs, top_cfgs, tops)
    write_file("hw/dv/top_sim_cfgs.hjson", content, dry_run)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate repo-wide IP collection files.",
    )
    parser.add_argument(
        "--flow",
        required=True,
        choices=["uvm_dv"],
        help="Flow type to collect for. Currently supported: uvm_dv",
    )
    parser.add_argument(
        "--tops",
        required=True,
        nargs="+",
        metavar="TOP",
        help="One or more tops to collect for (e.g. --tops top_earlgrey top_darjeeling)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be generated without writing files",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    if args.flow == "uvm_dv":
        run_uvm_dv(args.tops, args.dry_run)
    else:
        print(f"Unknown flow: {args.flow}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
