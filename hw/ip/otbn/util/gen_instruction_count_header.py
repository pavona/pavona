#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import pathlib
import sys

import hjson
from mako.template import Template

from shared.decode import decode_elf
from shared.instruction_count_range import program_insn_count_range
'''
Compute the range of instruction counts for each OTBN program mode, and
generate a header file with these ranges.
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=(
        'Get the range of possible instruction counts for a top-level '
        'OTBN program for various provided modes, storing the results in an '
        'auto-generated header. At runtime, one can read the instruction '
        'count register and make sure the values fall within the correct '
        'range to protect against certain fault injection attacks.'))
    parser.add_argument('--elf',
                        '-e',
                        metavar='FILE',
                        required=True,
                        type=str,
                        help='Read this file to determine instruction counts.')
    parser.add_argument('--hjsonfile',
                        '-j',
                        metavar='FILE',
                        required=True,
                        type=argparse.FileType('r'),
                        help='Read HJSON mode descriptions from this file')
    parser.add_argument('--template',
                        '-t',
                        metavar='FILE',
                        required=True,
                        type=argparse.FileType('r'),
                        help='Read header template from this file.')
    parser.add_argument('--headerfile',
                        '-o',
                        metavar='FILE',
                        required=True,
                        type=argparse.FileType('w'),
                        help='Write output to this file.')

    args = parser.parse_args()

    # Read mode descriptions in.
    modes = hjson.load(args.hjsonfile)
    args.hjsonfile.close()

    # Decode the program.
    program = decode_elf(args.elf)

    # Compute instruction count range.
    insn_counts = []
    for mode in modes:
        min_count, max_count = program_insn_count_range(
            program, mode["symbol"])
        insn_counts.append((mode, min_count, max_count))

    # Write out the resulting filled header template.
    args.headerfile.write(
        Template(args.template.read()).render(counts=insn_counts))
    args.headerfile.close()
    args.template.close()

    return 0


if __name__ == '__main__':
    sys.exit(main())
