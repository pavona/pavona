#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""
gen_ip_collection.py
Collects IP and top-level sim cfg files and generates batch hjson files.
Usage:
    ./gen_ip_collection.py --flow sim_dv --tops top_earlgrey top_darjeeling
"""
import argparse
import glob
import os
from pathlib import Path

SEARCH_ROOT = Path(__file__).resolve().parents[1]
LOWRISC_COPYRIGHT_LINE = "// Copyright lowRISC contributors (OpenTitan project)."
ZERORISC_COPYRIGHT_LINE = "// Copyright zeroRISC Inc."
LICENSE_LINES = """\
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0"""

COPYRIGHT_HEADER_SOLO = f"{ZERORISC_COPYRIGHT_LINE}\n{LICENSE_LINES}"
COPYRIGHT_HEADER_JOINT = (
    f"{LOWRISC_COPYRIGHT_LINE}\n{ZERORISC_COPYRIGHT_LINE}\n{LICENSE_LINES}"
)
WARNHDR = """//
// ------------------- W A R N I N G: A U T O - G E N E R A T E D   C O D E !! -------------------//
// PLEASE DO NOT HAND-EDIT THIS FILE. IT HAS BEEN AUTO-GENERATED WITH THE FOLLOWING COMMAND:
"""


def get_copyright_header(path, flow, tops):
    """Return the appropriate copyright header for this file."""
    tops_str = ' '.join(tops)
    GENCMD = (f"// util/gen_ip_collection.py --flow {flow}\n"
              f"//                --tops {tops_str}\n")
    if os.path.exists(path):
        try:
            with open(path) as f:
                first_line = f.readline().strip()
            if first_line == LOWRISC_COPYRIGHT_LINE:
                return f"{COPYRIGHT_HEADER_JOINT}\n\n{WARNHDR}{GENCMD}"
        except OSError as e:
            print(f"Warning: could not read {path}: {e}")
    return f"{COPYRIGHT_HEADER_SOLO}\n\n{WARNHDR}{GENCMD}"


# =============================
#   Specific to sim_dv flow
# =============================

def collect_sim_dv(tops):
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
    # Pattern 2: hw/ip/{ip_name}/dv/uvm/{sim_cfg}
    # Pattern 3: hw/ip/prim/dv/{prim_variant}/{sim_cfg}
    # Pattern 4: hw/dv/sv/{ip_name}/dv/{sim_cfg}
    for cfg in (
        sorted(glob.glob("hw/ip/*/dv/*_sim_cfg.hjson"))
        + sorted(glob.glob("hw/ip/*/dv/uvm/*_sim_cfg.hjson"))
        + sorted(glob.glob("hw/ip/prim/dv/*/*_sim_cfg.hjson"))
        + sorted(glob.glob("hw/dv/sv/*/*/*_sim_cfg.hjson"))
    ):
        sim_name = Path(cfg).stem.replace("_sim_cfg", "")
        if skip(sim_name):
            continue
        ip_cfgs.append(cfg)

    # ---- Top-specific bucket ----
    for top in tops:
        # Pattern 5: hw/{top}/ip_autogen/{ip_name}/dv/{sim_cfg}
        # Pattern 6: hw/{top}/ip_autogen/{ip_name}/dv/{subdir}/{sim_cfg}
        # Pattern 7: hw/{top}/ip/{xbar_name}/dv/autogen/{sim_cfg}
        # Pattern 8: hw/{top}/dv/{sim_cfg} (chip-level)
        for cfg in (
            sorted(glob.glob(f"hw/{top}/ip_autogen/*/dv/*_sim_cfg.hjson"))
            + sorted(glob.glob(f"hw/{top}/ip_autogen/*/dv/*/*_sim_cfg.hjson"))
            + sorted(glob.glob(f"hw/{top}/ip/*/dv/autogen/*_sim_cfg.hjson"))
            + sorted(glob.glob(f"hw/{top}/dv/*_sim_cfg.hjson"))
        ):
            sim_name = Path(cfg).stem.replace("_sim_cfg", "")
            if skip(sim_name):
                continue
            top_cfgs[top].append(cfg)

    return ip_cfgs, top_cfgs


def format_use_cfgs(cfgs, indent=13):
    """Format a list of cfg paths as hjson use_cfgs entries."""
    pad = " " * indent
    lines = [f'{pad}"{{proj_root}}/{cfg}",' for cfg in cfgs]
    return "\n".join(lines)


def format_block(name, cfgs_sections, nested=False):
    """Format a named block with optional nesting."""
    BASE_INDENT = 13
    NESTED_INDENT = BASE_INDENT + 4
    indent = NESTED_INDENT if nested else BASE_INDENT
    prefix = " " * BASE_INDENT
    lines = []
    if nested:
        lines.append(f"{prefix}{name}: [")
    for comment, cfgs in cfgs_sections:
        if cfgs:
            lines.append(f"{' ' * indent}// {comment}")
            lines.append(format_use_cfgs(cfgs, indent))
    if nested:
        lines.append(f"{prefix}]")
    return "\n".join(lines)


def generate_hjson(ip_cfgs, top_cfgs, tops, copyright_header, top_specific=False):
    """Generate hjson for a batch sim_cfgs"""
    tl_agent_cfgs = [c for c in ip_cfgs if "hw/dv/sv/" in c]
    pure_ip_cfgs = [c for c in ip_cfgs if "hw/ip/" in c]

    sections = []

    # IP block
    ip_sections = [
        ("Unit tests for UVCs.", tl_agent_cfgs),
        ("IPs.", pure_ip_cfgs),
    ]
    sections.append(format_block("ip", ip_sections, nested=not top_specific))

    # Per-top blocks
    for top in tops:
        cfgs = top_cfgs[top]
        top_sections = [
            (f"{top} autogen IPs.", [c for c in cfgs if f"hw/{top}/ip_autogen/" in c
                                     or f"hw/{top}/ip/" in c]),
            (f"{top} chip.", [c for c in cfgs if f"hw/{top}/dv/" in c]),
        ]
        sections.append(format_block(top, top_sections, nested=not top_specific))

    use_cfgs_body = "\n\n".join(s for s in sections if s)

    if not top_specific:
        batchname_desc = "across all IPs and tops in the project"
        batchname = "all_tops"
        rel_path = "hw/dv/summary"
        open_br, close_br = "{", "}"
    else:
        batchname_desc = f"of the IPs and the full chip used in {tops[0]}"
        batchname = tops[0]
        rel_path = f"hw/{tops[0]}/dv/summary"
        open_br, close_br = "[", "]"

    return f"""{copyright_header}
{{
  // This is a cfg hjson group for DV simulations. It includes ALL individual DV simulation
  // cfgs {batchname_desc}. This enables the common regression sets to be run in one shot.
  name: {batchname}_batch

  import_cfgs: [// Project wide common cfg file
                "{{proj_root}}/hw/data/common_project_cfg.hjson"]

  flow: sim

  rel_path: "{rel_path}"

  // Need to override the default output directory
  overrides: [
    {{
        name: scratch_path
        value: "{{scratch_base_path}}/{{name}}-{{flow}}"
    }}
  ]

  use_cfgs: {open_br}
{use_cfgs_body}
  {close_br}
}}
"""


def write_file(path, content, dry_run):
    if dry_run:
        print(f"\n{'=' * 60}")
        print(f"Would write: {path}")
        print('=' * 60)
        print(content)
    else:
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(content)
            print(f"Written: {path}")
        except OSError as e:
            print("Failed to create output directory {}: \n{}."
                  .format(os.path.dirname(path), e))


def run_sim_dv(tops, dry_run, flow):
    print("Collecting sim_dv sim_cfg files...")
    ip_cfgs, top_cfgs = collect_sim_dv(tops)
    print(f"  Found {len(ip_cfgs)} shared IP cfgs")
    for top, cfgs in top_cfgs.items():
        print(f"  Found {len(cfgs)} cfgs for {top}")

    # Per-top hjson files
    for top in tops:
        out_path = f"hw/{top}/dv/{top}_sim_cfgs.hjson"
        copyright_header = get_copyright_header(out_path, flow, top_cfgs)
        content = generate_hjson(ip_cfgs, top_cfgs, [top], copyright_header, True)
        write_file(out_path, content, dry_run)

    # Global hjson file
    out_path = "hw/dv/all_sim_cfgs.hjson"
    copyright_header = get_copyright_header(out_path, flow, top_cfgs)
    content = generate_hjson(ip_cfgs, top_cfgs, tops, copyright_header)
    write_file(out_path, content, dry_run)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate repo-wide IP collection files.",
    )
    parser.add_argument(
        "--flow",
        required=True,
        choices=["sim_dv"],
        help="Flow type to collect for. Currently supported: sim_dv",
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
    try:
        os.chdir(SEARCH_ROOT)
    except OSError as e:
        print(f"Failed to change to directory {SEARCH_ROOT}: \n{e}")
    args = parse_args()
    if args.flow == "sim_dv":
        run_sim_dv(args.tops, args.dry_run, args.flow)
    else:
        print(f"Unknown flow: {args.flow}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
