#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import json
import sys

import mdbook.utils as md_utils


EXTENSION_TO_SYNTAX = {"hjson": "hjson",
                       "md": "markdown",
                       "py": "python",
                       "sv": "systemverilog",
                       "v": "verilog",
                       "c": "c",
                       "h": "c",
                       "json": "json",
                       "rs": "rust",
                       "bzl": "starlark",
                       "bazel": "starlark",
                       "core": "yaml",
                       "yaml": "yaml"}

if __name__ == "__main__":
    md_utils.supports_html_only()

    context, book = json.load(sys.stdin)

    # format templates as code
    for chapter in md_utils.chapters(book["sections"]):
        src_path = chapter["source_path"]
        if not src_path or ".tpl" not in src_path or ".tpldesc" in src_path:
            continue

        real_extension = src_path.split(".tpl")[0].split(".")[-1]
        syntax = EXTENSION_TO_SYNTAX.get(real_extension) or ""
        chapter["content"] = f"~~~{syntax}\n" + chapter["content"] + "\n~~~"

    # Dump the book into stdout.
    print(json.dumps(book))
