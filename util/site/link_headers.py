#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
import re
import argparse
from pathlib import Path


REPO_TOP = Path(__file__).parents[2].resolve()
CHAPTER_HEADER_RE = (r'<li class="part-title">(?P<header>.*?)</li>'
                     r'<li class="chapter-item "><a href="(?P<link>[^"]*)">')
REPLACEMENT = (r'<li class="part-title"><a href="\g<link>">\g<header></a></li>'
               r'<li class="chapter-item "><a href="\g<link>">')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--toc-js",
                        type=Path,
                        default=REPO_TOP / "build-site" / "book" / "toc.js",
                        help="Path to the toc.js file for the mdbook")
    args = parser.parse_args()

    assert args.toc_js.exists()
    original_text = args.toc_js.read_text()
    new_text = re.sub(CHAPTER_HEADER_RE, REPLACEMENT, original_text)
    args.toc_js.write_text(new_text)


if __name__ == "__main__":
    main()
