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


def bitslice_vec(x: List[int], k: int) -> List[int]:
    r = [0] * k
    one = sum(1 << (i * 16) for i in range(16))
    mask = (1 << N) - 1
    x_int = sum(x[i] << (i * 16) for i in range(N))
    for i in range(16):
        t = x_int & mask
        x_int >>= N
        for j in range(k):
            r[j] <<= 1
            r[j] |= (t & one)
            t >>= 1
    return r


def tomsg(x: List[int], q: int) -> List[int]:
    """Convert polynomial to 32-byte message."""
    for i in range(N):
        x[i] = (((x[i] << 1) + q // 2) // q) & 1
    r = bitslice_vec(x, 1)
    return r


def gen_masked_poly_tomsg_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    q = 3329

    # Generate input.
    x = [0] * N
    x_bytes = bytes()
    for _ in range(NSHARES):
        t = [random.randint(0, q - 1) for _ in range(N)]
        x = [(x[j] + t[j]) % q for j in range(N)]
        tmp = sum(t[j] << (j * 16) for j in range(N))
        x_bytes += int.to_bytes(tmp, byteorder="little", length=512)

    # Generate expected result.
    r = tomsg(x, q)
    r_bytes = int.to_bytes(r[0], byteorder="little", length=32)

    rb_bytes = int.to_bytes(0, byteorder='little', length=32 * NSHARES)

    # Write input values.
    inputs = {'xa': x_bytes, 'rb': rb_bytes}
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
        gen_masked_poly_tomsg_test(
            args.seed, args.data, args.exp, args.dexp)
