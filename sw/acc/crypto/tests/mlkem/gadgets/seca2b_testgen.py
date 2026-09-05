#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional, List

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
NSHARES = 2
K = 16


def bitslice(x: List[int], k: int) -> bytes:
    r = bytes()
    for bit in range(k):
        t = 0
        for coeff in range(N):
            t |= (((x[coeff] >> bit) & 1) << coeff)
        r += int.to_bytes(t, byteorder="little", length=32)
    return r


def gen_seca2b_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    # Generate input.
    m = (1 << K) - 1
    x = [0] * N
    r = [0] * N
    x_bytes = bytes()
    for _ in range(NSHARES):
        for coeff in range(N):
            x[coeff] = random.randint(0, m)
            r[coeff] = (r[coeff] + x[coeff]) & m
        x_bytes += bitslice(x, K)

    # Generate expected result.
    r_bytes = bitslice(r, K)

    # Write input values.
    inputs = {
        'xa': x_bytes,
        'rb': int.to_bytes(0, byteorder='little', length=512 * NSHARES)
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
        gen_seca2b_test(args.seed, args.data, args.exp, args.dexp)
