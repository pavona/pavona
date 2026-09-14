#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Merge UCIS XML coverage files, ignoring missing inputs."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from ucis.mem.mem_factory import MemFactory
from ucis.merge.db_merger import DbMerger
from ucis.rgy.format_rgy import FormatRgy
from ucis.xml.xml_factory import XmlFactory


def _load_ucis_xml(path: str):
    rgy = FormatRgy.inst()
    xml_desc = rgy.getDatabaseDesc("xml")
    return xml_desc.fmt_if().read(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="*")
    parser.add_argument("--out", "-o", required=True)
    args = parser.parse_args()

    existing = []
    seen = set()
    for item in args.inputs:
        path = Path(item)
        if path.exists():
            resolved = str(path.resolve())
            if resolved not in seen:
                seen.add(resolved)
                existing.append(resolved)

    if not existing:
        print("No coverage databases found to merge.", file=sys.stderr)
        return 1

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    src_dbs = [_load_ucis_xml(path) for path in existing]
    try:
        merged_db = MemFactory.create()
        DbMerger().merge(merged_db, src_dbs)
        XmlFactory.write(merged_db, str(out_path))
    finally:
        for db in src_dbs:
            db.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
