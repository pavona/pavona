#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
NSHARES = 2
Q = 3329
K = 12


def gen_bitcopymask_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    # Generate input.
    r = 0
    x_bytes = bytes()
    for _ in range(NSHARES):
        bit = random.getrandbits(1)
        r ^= bit
        x_bytes += int.to_bytes(bit, byteorder="little", length=32)

    # Generate expected result.
    r *= Q
    r_bytes = bytes()
    for bit in range(K):
        rbit = (r >> bit) & 1
        r_bytes += int.to_bytes(rbit, byteorder="little", length=32)

    # Write input values.
    inputs = {
        'xb': x_bytes,
        'rb': int.to_bytes(0, byteorder="little", length=32 * 12 * NSHARES)
    }
    write_test_data(inputs, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'r': r_bytes}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
    parser.add_argument('data',
                        metavar='FILE',
                        type=argparse.FileType('w'),
                        help=('Output file for input DMEM values.'))
    parser.add_argument('exp',
                        metavar='FILE',
                        type=argparse.FileType('w'),
                        help=('Output file for expected register values.'))
    parser.add_argument('dexp',
                        metavar='FILE',
                        type=argparse.FileType('w'),
                        help=('Output file for expected DMEM values.'))
    args = parser.parse_args()

    with args.data, args.exp, args.dexp:
        gen_bitcopymask_test(
            args.seed, args.data, args.exp, args.dexp)
