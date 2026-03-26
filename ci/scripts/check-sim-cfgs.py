#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
import sys
from pathlib import Path
from collections import defaultdict
import hjson
import pathspec

SEARCH_ROOT = Path(__file__).resolve().parents[2]


def find_sim_cfg_files() -> dict[str, list[tuple[str, dict]]]:
    """
    This function searches for *_sim_cfg.hjson or *_sim_cfgs.hjson
    files and groups them in lists based on which directory they exist
    within.
    For e.g. for a ipname with {name}_base_sim_cfg.hjson, and
    {name}_variant_sim_cfg.hjson, they would both be grouped in:

    grouped["/hw/ip/{ipname}"] = [{name} sim cfgs]
    """
    gitignore = SEARCH_ROOT / ".gitignore"
    spec = pathspec.PathSpec.from_lines("gitwildmatch", gitignore.read_text().splitlines()) \
        if gitignore.exists() else None

    all_scs = (
        list(SEARCH_ROOT.rglob("*_sim_cfg.hjson")) +
        list(SEARCH_ROOT.rglob("*_sim_cfgs.hjson"))
    )
    if spec:
        all_scs = [p for p in all_scs if not spec.match_file(p.relative_to(SEARCH_ROOT))]

    grouped = defaultdict(list)
    for p in all_scs:
        grouped[str(p.parent)].append((p.name, get_fields_from_hjson(p)))

    return dict(grouped)


def check_sim_cfg_files(grouped: dict) -> bool:
    mismatches: list[str] = []

    for directory, files in grouped.items():
        sim_cfg_files = [(f, d) for f, d in files if f.endswith("_sim_cfg.hjson")]
        sim_cfgs_files = [(f, d) for f, d in files if f.endswith("_sim_cfgs.hjson")]

        # CASE 1: There is only one file in the directory
        if len(sim_cfg_files) == 1:
            file, fields = sim_cfg_files[0]
            if 'name' not in fields:
                pass  # ignore
            else:
                if 'variant' in fields:
                    mismatches.append(f"Filename {directory}/{file}"
                                      f" - should not contain 'variant' field")
                elif file.endswith("_base_sim_cfg.hjson"):
                    expected = f"{fields['name']}_base_sim_cfg.hjson"
                    if file != expected:
                        mismatches.append(f"Filename {directory}/{file}"
                                          f" - should be named {expected}")
                else:
                    expected = f"{fields['name']}_sim_cfg.hjson"
                    if file != expected:
                        mismatches.append(f"Filename {directory}/{file}"
                                          f" - should be named {expected}")

        # CASE 2: There are multiple sim_cfg files in the directory
        else:
            has_variant = any("variant" in fields for _, fields in sim_cfg_files)

            if has_variant:
                # Pattern 1: base + variant mode
                # The base file is the one with 'name' field
                base_files = [(f, d) for f, d in sim_cfg_files if "name" in d]

                if len(base_files) == 0:
                    for file, fields in sim_cfg_files:
                        mismatches.append(
                            f"Filename {directory}/{file}"
                            f" - exactly one file with 'name' field "
                            f"expected in base+variant directory. There is none, currently."
                        )
                elif len(base_files) > 1:
                    for file, _ in base_files:
                        mismatches.append(
                            f"Filename {directory}/{file}"
                            f" - exactly one file with 'name' field "
                            f"expected in base+variant directory"
                        )
                else:
                    base_file, base_fields = base_files[0]

                    # Base file must not also contain 'variant'
                    if "variant" in base_fields:
                        mismatches.append(f"Filename {directory}/{base_file}"
                                          f" - base file must not contain 'variant' field")
                    else:
                        base_name = base_fields["name"]
                        expected = f"{base_name}_base_sim_cfg.hjson"
                        if base_file != expected:
                            mismatches.append(f"Filename {directory}/{base_file}"
                                              f" should be named {expected}")

                    # Check variant files
                    for file, fields in sim_cfg_files:
                        if "variant" in fields:
                            expected = f"{base_name}_{fields['variant']}_sim_cfg.hjson"
                            if file != expected:
                                mismatches.append(f"Filename {directory}/{file}"
                                                  f" should be named {expected}")

            else:
                # Pattern 2: all independent, each with their own 'name'
                for file, fields in sim_cfg_files:
                    if "name" in fields:
                        name = fields['name']
                        valid = [f"{name}_sim_cfg.hjson", f"{name}_base_sim_cfg.hjson"]
                        if file not in valid:
                            mismatches.append(
                                f"Filename {directory}/{file}"
                                f" should be named {valid[0]} or {valid[1]}"
                            )

        # CASE 3: sim_cfgs files
        for file, fields in sim_cfgs_files:
            dir_path = Path(directory)
            if dir_path == SEARCH_ROOT / "hw" / "dv":
                expected = "all_sim_cfgs.hjson"
                if file != expected:
                    mismatches.append(f"Filename {directory}/{file}"
                                      f" should be named {expected}")
                elif 'name' not in fields:
                    mismatches.append(f"Filename {directory}/{file}"
                                      f" should contain field 'name'")
            elif (dir_path.resolve() in SEARCH_ROOT.glob("hw/top_*/dv")):
                topname = dir_path.parent.name
                expected = f"{topname}_sim_cfgs.hjson"
                if file != expected:
                    mismatches.append(f"Filename {directory}/{file}"
                                      f" should be named {expected}")
                elif 'name' not in fields:
                    mismatches.append(f"Filename {directory}/{file}"
                                      f" should contain field 'name'")
            else:
                mismatches.append(
                    f"Filename {file} is in the wrong directory ({directory}). "
                    f"Directory should be of the form hw/dv/ or hw/{{topname}}/dv/"
                )

    for message in mismatches:
        print(f"[MISMATCH] {message}")

    if len(mismatches) == 0:
        print("All filenames named appropriately!")

    return len(mismatches) == 0


def get_fields_from_hjson(filename: str) -> dict[str, str]:
    """
    This function retrieves the 'name' and 'variant'
    fields, if they exist.
    """
    with open(filename) as f:
        data = hjson.load(f)
        return {k: data[k] for k in ("name", "variant") if k in data}


if __name__ == "__main__":
    grouped = find_sim_cfg_files()
    if not check_sim_cfg_files(grouped):
        sys.exit(1)
