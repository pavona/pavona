#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
'''Check clobbered-register annotations of global ACC functions.'''

import argparse
import functools
import os
import re
import sys
from concurrent.futures import ProcessPoolExecutor
from typing import Dict, List, Optional, Set, Tuple

from shared.control_flow import subroutine_control_graph
from shared.decode import ACCProgram, decode_elf
from shared.docstring import docstring_above
from shared.information_flow_analysis import get_subroutine_iflow

LABEL_RE = re.compile(r'^\s*([A-Za-z_.$][A-Za-z0-9_.$]*)\s*:')
GLOBL_RE = re.compile(r'^\s*\.globl\s+([A-Za-z_.$][A-Za-z0-9_.$]*)')
REGS_RE = re.compile(r'^clobbered registers:(.*(?:\n[^:\n]+$)*)',
                     re.MULTILINE | re.IGNORECASE)
FLAGS_RE = re.compile(r'^clobbered flag groups:(.*)',
                      re.MULTILINE | re.IGNORECASE)
RANGE_RE = re.compile(r'^([xw])(\d+)(?:\s+to\s+\1(\d+))?$')
SPECIAL_REGS = {'acc', 'acch', 'mod', 'rnd', 'urnd'}

Location = Tuple[str, int]


class Annotation:
    def __init__(self, path: str, lineno: int, symbol: str, text: str):
        self.path = path
        self.lineno = lineno
        self.symbol = symbol
        regs_m = REGS_RE.search(text)
        flags_m = FLAGS_RE.search(text)
        assert regs_m is not None
        self.regs_text = regs_m.group(1).replace('\n', ',')
        self.flags_text = flags_m.group(1) if flags_m else None


def _find_annotations(path: str) -> Dict[str, Annotation]:
    '''Map each documented global label in a file to its docstring.'''
    with open(path) as f:
        lines = f.read().splitlines()

    globl = {m.group(1) for m in map(GLOBL_RE.match, lines) if m}
    out = {}
    for idx, line in enumerate(lines):
        m = LABEL_RE.match(line)
        if m is None or m.group(1) not in globl:
            continue
        doc = docstring_above(lines, idx)
        if doc is not None and REGS_RE.search(doc[1]):
            out[m.group(1)] = Annotation(path, doc[0] + 1, m.group(1), doc[1])
    return out


def _parse_regs(text: str) -> Optional[Set[str]]:
    regs: Set[str] = set()
    for item in text.split(','):
        item = item.strip()
        if item == '' or item.lower() == 'none':
            continue
        if item.lower() in SPECIAL_REGS:
            regs.add(item.lower())
            continue
        m = RANGE_RE.match(item)
        if m is None:
            return None
        prefix, start, end = m.group(1), int(m.group(2)), m.group(3)
        for i in range(start, int(end) + 1 if end else start + 1):
            regs.add(f'{prefix}{i}')
    regs.discard('x1')
    return regs


def _parse_flags(text: str) -> Optional[Set[str]]:
    flags: Set[str] = set()
    for item in text.split(','):
        item = item.strip().upper()
        if item in ('', 'NONE'):
            continue
        if item not in ('FG0', 'FG1'):
            return None
        flags.add(item)
    return flags


@functools.lru_cache(maxsize=None)
def _decode(elf: str) -> ACCProgram:
    return decode_elf(elf)


def _analyze(elf: str, symbol: str) -> Tuple[Set[str], Set[str]]:
    program = _decode(elf)
    graph = subroutine_control_graph(program, symbol)
    ret_iflow, end_iflow, _ = get_subroutine_iflow(program, graph, symbol, {},
                                                   True)
    iflow = ret_iflow if ret_iflow.exists else end_iflow
    regs = set()
    flags = set()
    for sink in iflow.flow:
        name = sink.name
        if name == 'x1' or name.startswith(('dmem', 'kmac')):
            continue
        if name.startswith('fg0'):
            flags.add('FG0')
        elif name.startswith('fg1'):
            flags.add('FG1')
        else:
            regs.add(name)
    return regs, flags


def _format_regs(regs: Set[str]) -> str:
    parts: List[str] = []
    for prefix in 'xw':
        nums = sorted(int(r[1:]) for r in regs
                      if r[0] == prefix and r[1:].isdigit())
        i = 0
        while i < len(nums):
            j = i
            while j + 1 < len(nums) and nums[j + 1] == nums[j] + 1:
                j += 1
            if i == j:
                parts.append(f'{prefix}{nums[i]}')
            else:
                parts.append(f'{prefix}{nums[i]} to {prefix}{nums[j]}')
            i = j + 1
    parts += sorted(r for r in regs if not re.match(r'^[xw]\d+$', r))
    return ', '.join(parts)


def _format_flags(flags: Set[str]) -> str:
    return ', '.join(sorted(flags)) if flags else 'none'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('programs', nargs='+', metavar='ELF=SRC[,SRC...]',
                        help='An ELF file and the sources linked into it.')
    parser.add_argument('--jobs', '-j', type=int, default=os.cpu_count(),
                        help='Number of subroutines to analyze in parallel.')
    parser.add_argument('--skip', nargs='*', default=[], metavar='SYMBOL',
                        help='Subroutines not to check.')
    args = parser.parse_args()

    errors: List[Tuple[Location, str]] = []
    actual: Dict[Location, Tuple[Set[str], Set[str]]] = {}
    annotations: Dict[Location, Annotation] = {}

    skipped = set()
    jobs = []
    for spec in args.programs:
        elf, srcs = spec.split('=', 1)
        program = _decode(elf)
        for src in srcs.split(','):
            for symbol, ann in _find_annotations(src).items():
                if program.symbol_sections.get(symbol) != '.text':
                    continue
                if symbol in args.skip:
                    skipped.add(symbol)
                    continue
                loc = (ann.path, ann.lineno)
                annotations[loc] = ann
                jobs.append((elf, symbol, loc))

    for symbol in sorted(set(args.skip) - skipped):
        errors.append((('<args>', 0), f'{symbol}: skipped but not found'))

    with ProcessPoolExecutor(max_workers=args.jobs) as pool:
        futures = [(elf, symbol, loc, pool.submit(_analyze, elf, symbol))
                   for elf, symbol, loc in jobs]
        for elf, symbol, loc, future in futures:
            try:
                regs, flags = future.result()
            except Exception as e:
                errors.append((loc, f'{symbol}: cannot analyze in {elf}: {e}'))
                continue
            prev_regs, prev_flags = actual.get(loc, (set(), set()))
            actual[loc] = (prev_regs | regs, prev_flags | flags)

    for loc, (regs, flags) in sorted(actual.items()):
        ann = annotations[loc]
        declared_regs = _parse_regs(ann.regs_text)
        if declared_regs != regs:
            errors.append((loc, f'{ann.symbol}: clobbered registers should be: '
                           f'{_format_regs(regs)}'))
        if ann.flags_text is None:
            errors.append((loc, f'{ann.symbol}: missing clobbered flag groups'))
            continue
        declared_flags = _parse_flags(ann.flags_text)
        if declared_flags != flags:
            errors.append((loc, f'{ann.symbol}: clobbered flag groups should '
                           f'be: {_format_flags(flags)}'))

    for (path, lineno), msg in errors:
        print(f'{path}:{lineno}: {msg}')
    print(f'Checked {len(actual)} subroutines, {len(errors)} errors.')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
