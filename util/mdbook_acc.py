#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""mdbook preprocessor that generates ISA tables for the ACC.

The preprocessor also handles `{{#acc-insn-ref ... }}` links to the ISA Table.
"""

import json
import sys
import re
from pathlib import Path
import tempfile
import subprocess

from mdbook import utils as md_utils

REPO_TOP = Path(__file__).resolve().parents[1]

# We are looking to match on the following example strings
# {{#acc-isa base }}
ACC_ISA_BASE_PATTERN = re.compile(r'\{\{#acc-isa\s+base\s*\}\}')
ACC_ISA_BIGNUM_PATTERN = re.compile(r'\{\{#acc-isa\s+bignum\s*\}\}')

# {{#acc-insn-ref insn }}
ACC_INSNREF_PATTERN = re.compile(r'\{\{#acc-insn-ref\s+?(.+?)\s*?\}\}')

ACC_SCRIPT = REPO_TOP / 'hw/ip/acc/util/yaml_to_doc.py'
ACC_CFG = REPO_TOP / 'hw/ip/acc/data/insns.yml'
ACC_IMPL = REPO_TOP / 'hw/ip/acc/dv/accsim/sim/insn.py'


def main() -> None:
    md_utils.supports_html_only()

    (base_content, bignum_content) = get_listings()

    # load both the context and the book from stdin
    _context, book = json.load(sys.stdin)

    isa_book_path = None
    for chapter in md_utils.chapters(book["sections"]):
        if chapter["source_path"] is None:
            continue

        if ACC_ISA_BASE_PATTERN.search(chapter["content"]) \
                and ACC_ISA_BIGNUM_PATTERN.search(chapter["content"]):

            chapter["content"] = ACC_ISA_BASE_PATTERN.sub(base_content, chapter["content"])
            chapter["content"] = ACC_ISA_BIGNUM_PATTERN.sub(bignum_content, chapter["content"])

            isa_book_path = chapter["source_path"]
            break

    if isa_book_path is None:
        sys.exit("No file was found with both {{#acc-isa base}} and {{#acc-isa bignum}}")

    def ref_to_link(m: re.Match):
        instr = m.group(1)
        ref = instr.replace(".", "").lower()
        return '<a href="/{}#{}"><code>{}</code></a>)'.format(isa_book_path, ref, instr)

    for chapter in md_utils.chapters(book["sections"]):
        chapter["content"] = \
            ACC_INSNREF_PATTERN.sub(
                ref_to_link,
                chapter["content"],
        )

    # dump the book into stdout
    print(json.dumps(book))


def get_listings() -> (str, str):
    """Use the acc utility scripts to generate the ISA listings."""
    with tempfile.TemporaryDirectory() as tmpdir:
        subprocess.run(
            [str(ACC_SCRIPT), str(ACC_CFG), str(ACC_IMPL), tmpdir],
            check=True,
        )
        tmpdir = Path(tmpdir)
        with open(tmpdir / "base.md") as f:
            base_content = f.read()

        with open(tmpdir / "bignum.md") as f:
            bignum_content = f.read()

    return (base_content, bignum_content)


if __name__ == "__main__":
    main()
