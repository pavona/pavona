#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
"""Lint checks for ACC assembly.

Each check is a function that takes a file's path and its lines and
yields (lineno, message) violations. Register a check in CHECKS together
with a predicate selecting the files it applies to.
"""

import re
import sys
from typing import Callable, Iterator, List, Tuple

from shared.docstring import docstring_above

Violation = Tuple[int, str]
Check = Callable[[str, List[str]], Iterator[Violation]]
Predicate = Callable[[str], bool]

LABEL_RE = re.compile(r'^\s*([A-Za-z_.$][A-Za-z0-9_.$]*)\s*:')
TYPE_RE = re.compile(r'\.type\s+([A-Za-z_.$][A-Za-z0-9_.$]*)\s*,\s*@function\b')
GLOBL_RE = re.compile(r'^\s*\.globl\s+([A-Za-z_.$][A-Za-z0-9_.$]*)')


def _iter_text_labels(lines: List[str]) -> Iterator[Tuple[int, str]]:
    """Yield (lineno, label) for labels defined in an executable section."""
    in_text = True
    in_comment = False
    for lineno, line in enumerate(lines, 1):
        if in_comment:
            if '*/' not in line:
                continue
            line = line.split('*/', 1)[1]
            in_comment = False
        line = re.sub(r'/\*.*?\*/', '', line)
        if '/*' in line:
            line = line.split('/*', 1)[0]
            in_comment = True

        stripped = line.strip()
        if stripped.startswith('.section'):
            in_text = '.text' in stripped
        elif stripped.startswith('.text'):
            in_text = True
        elif stripped.startswith(('.data', '.bss', '.rodata')):
            in_text = False

        m = LABEL_RE.match(line)
        if m and in_text:
            yield lineno, m.group(1)


def check_function_types(path: str, lines: List[str]) -> Iterator[Violation]:
    """Function labels must carry a '.type <name>, @function' directive.

    The ACC simulator's profiler attributes cycles to @function symbols, so
    every function entry point needs the annotation to appear in the
    per-function breakdown. Labels internal to a function (_ prefixed)
    are exempt by convention, as are .L* assembler-local labels.
    """
    typed = set()
    for line in lines:
        m = TYPE_RE.search(line)
        if m:
            typed.add(m.group(1))

    for lineno, name in _iter_text_labels(lines):
        if name.startswith('_') or name.startswith('.L'):
            continue
        if name not in typed:
            yield lineno, (f"function label '{name}' has no "
                           f"'.type {name}, @function' annotation")


def check_function_docstrings(path: str,
                              lines: List[str]) -> Iterator[Violation]:
    """Global functions must document their clobbered registers and flags."""
    globl = set()
    for line in lines:
        m = GLOBL_RE.match(line)
        if m:
            globl.add(m.group(1))

    for lineno, name in _iter_text_labels(lines):
        if name not in globl or name == 'start' or name.startswith('_'):
            continue
        doc = docstring_above(lines, lineno - 1)
        if doc is None:
            yield lineno, f"global function '{name}' has no docstring"
            continue
        for field in ('clobbered registers:', 'clobbered flag groups:'):
            if not re.search('^' + field, doc[1], re.MULTILINE):
                yield lineno, (f"docstring of global function '{name}' "
                               f"has no '{field}' line")


def _is_crypto_lib(path: str) -> bool:
    """Crypto library sources, excluding test programs."""
    return (path.startswith('sw/acc/crypto/') and
            not path.startswith('sw/acc/crypto/tests/'))


CHECKS: List[Tuple[str, Check, Predicate]] = [
    ('function-types', check_function_types, _is_crypto_lib),
    ('function-docstrings', check_function_docstrings, _is_crypto_lib),
]


def main() -> int:
    ret = 0
    for path in sys.argv[1:]:
        with open(path) as f:
            lines = f.read().splitlines()
        for _name, check, applies in CHECKS:
            if not applies(path):
                continue
            for lineno, msg in check(path, lines):
                print(f"::error::{path}:{lineno}: {msg}")
                ret = 1

    return ret


if __name__ == '__main__':
    sys.exit(main())
