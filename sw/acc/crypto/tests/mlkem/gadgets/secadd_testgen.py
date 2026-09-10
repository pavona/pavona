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
K = 16


def gen_secadd_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    x = [0] * K
    y = [0] * K
    x_bytes = bytes()
    y_bytes = bytes()
    for _ in range(NSHARES):
        for bit in range(K):
            t = random.getrandbits(N)
            x[bit] ^= t
            x_bytes += int.to_bytes(t, byteorder="little", length=32)
            t = random.getrandbits(N)
            y[bit] ^= t
            y_bytes += int.to_bytes(t, byteorder="little", length=32)

    # Generate expected result.
    m = (1 << K) - 1
    r = [0] * K
    for coeff in range(N):
        x_coeff = 0
        y_coeff = 0
        for bit in range(K):
            x_coeff |= (((x[bit] >> coeff) & 1) << bit)
            y_coeff |= (((y[bit] >> coeff) & 1) << bit)
        r_coeff = (x_coeff + y_coeff) & m
        for bit in range(K):
            r[bit] |= (((r_coeff >> bit) & 1) << coeff)

    r_bytes = bytes()
    for bit in range(K):
        r_bytes += int.to_bytes(r[bit], byteorder="little", length=32)

    # Write input values.
    inputs = {
        'xb': x_bytes,
        'yb': y_bytes,
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
        gen_secadd_test(args.seed, args.data, args.exp, args.dexp)
