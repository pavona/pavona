#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Collect a list of top level systems in the repo based on the contents of hw/top_*.

Uses the top level config file, directory name, and either datasheet or README to generate
a table in Markdown that lists all the available tops with top name, targets, and one line
description."""

from pathlib import Path
import hjson
import re
import sys


REPO_TOP = Path(__file__).parents[1].resolve()
DEFAULT_OUTFILE = REPO_TOP / "doc" / "contributing" / "system_list.md"
TABLE_COLUMNS = ("Design", "Targets", "Description")


def top_doc_file(topdir):
    datasheet = topdir / "doc" / "datasheet.md"
    if datasheet.is_file():
        return datasheet
    readme = topdir / "README.md"
    if readme.is_file():
        return readme
    raise Exception("Could not find an appropriate top document within {topdir}.")


def get_design(topdir, outfile_path):
    outfile_path = outfile_path.resolve()

    if outfile_path.parent == REPO_TOP:
        outfile_to_repo_top = "./"
    elif outfile_path.is_relative_to(REPO_TOP):
        outfile_to_repo_top = "../" * (outfile_path.parents.index(REPO_TOP))
    else:
        outfile_to_repo_top = str(REPO_TOP) + "/"

    try:
        top_to_topdoc = top_doc_file(topdir).relative_to(REPO_TOP)
    except Exception:
        return f"`{topdir.name}`"

    return f"[`{topdir.name}`]({outfile_to_repo_top}{top_to_topdoc})"


def get_targets(topdir):
    top_cfg = topdir / "data" / f"{topdir.name}.hjson"
    topname = topdir.name.removeprefix("top_")
    verilator_file = topdir / f"chip_{topname}_verilator.core"

    sim_targets = ""
    if verilator_file.is_file():
        sim_targets = "verilator"  # only one known sim target

    hw_targets = ""
    if top_cfg.is_file():
        top_data = hjson.loads(top_cfg.read_text())
        target_names = [t["name"] for t in top_data["targets"]]
        hw_targets = ", ".join(target_names)

    return sim_targets + (", " * int(bool(sim_targets and hw_targets))) + hw_targets


def get_description(topdir):
    def first_line_of_md_text(md_text):
        for ln in md_text.splitlines():
            if re.match("[A-Za-z]", ln.lstrip()):
                return ln
    try:
        return first_line_of_md_text(top_doc_file(topdir).read_text())
    except Exception:
        return ""


def render_table(table):
    rendered = ""
    for row in table:
        for item in row:
            rendered += f"| {item} "
        rendered = rendered + "|\n"
    return rendered[:-1]  # don't need trailing newline


def make_tops_table(outfile_path=DEFAULT_OUTFILE):
    table = [TABLE_COLUMNS, ("---",) * len(TABLE_COLUMNS)]
    for topdir in sorted(REPO_TOP.glob("hw/top_*")):
        table.append((
            get_design(topdir, outfile_path),
            get_targets(topdir),
            get_description(topdir)
        ))
    return render_table(table)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        outfile_path = Path(sys.argv[1]).resolve()
    else:
        outfile_path = DEFAULT_OUTFILE

    print(make_tops_table(outfile_path))
