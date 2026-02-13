#! /usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import re

HEADING_START = "Function cycle counts"
HEADING_LINES = 4

FUNC_PAT = re.compile(r'([a-z0-9_]+) +\[([0-9]+), ([0-9]+)\]')


def parse_function_stats(statsfile):
    heading_index = None
    counts = {}
    for line in statsfile.readlines():
        line = line.strip()
        if heading_index is None:
            if line == HEADING_START:
                heading_index = 1
            continue
        if heading_index < HEADING_LINES:
            assert re.match(FUNC_PAT, line) is None
            heading_index += 1
            continue
        # if we get here we're past the heading, get the stats
        m = re.match(FUNC_PAT, line)
        if m is None:
            if line != "":
                raise ValueError(f'Malformatted line: {line}')
            # if the line is empty, we finished the stats, break from loop
            break
        name = m.group(1)
        instr = m.group(2)
        stall = m.group(3)
        counts[name] = [int(instr), int(stall)]
    if heading_index is None:
        raise ValueError(f'Heading line does not appear in input: {HEADING_START}')
    return counts


def pretty_print_profile(stats):
    cycles_per_function = {k: sum(v) for k, v in stats.items()}
    total_cycles = sum(cycles_per_function.values())
    for name, cycles in cycles_per_function.items():
        pct = cycles * 100 / total_cycles
        print(f'{pct:.02f}%\t{cycles}\t{name}')
    print('Total cycles:', total_cycles)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'stats', type=argparse.FileType('r'),
        help=('Statistics as dumped by the ACC simulator.'))
    args = parser.parse_args()

    stats = parse_function_stats(args.stats)
    pretty_print_profile(stats)
