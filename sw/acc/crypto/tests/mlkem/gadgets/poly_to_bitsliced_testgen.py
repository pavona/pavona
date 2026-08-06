#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256


def gen_poly_to_bitsliced_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    k = 12

    # Generate input: random k-bit coefficients, one per 16-bit lane.
    x = [random.randint(0, (1 << k) - 1) for _ in range(N)]
    x_int = sum((x[j] << (j * 16)) for j in range(N))
    x_bytes = int.to_bytes(x_int, byteorder="little", length=512)

    # Generate expected result.
    mask = (1 << N) - 1
    one = sum(1 << (i * 16) for i in range(16))
    r = [0] * k
    for i in range(16):
        t = x_int & mask
        x_int >>= N
        for j in range(k):
            r[j] <<= 1
            r[j] |= (t & one)
            t >>= 1

    r_bytes = bytes()
    for i in range(k):
        r_bytes += int.to_bytes(r[i] & mask, byteorder="little", length=32)

    # Write input values.
    inputs = {'xa': x_bytes}
    write_test_data(inputs, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'rbs': r_bytes}, dexp_file)


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
        gen_poly_to_bitsliced_test(args.seed, args.data, args.exp, args.dexp)
