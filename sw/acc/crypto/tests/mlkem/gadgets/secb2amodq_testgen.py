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


def bitslice(x: List[int], k: int) -> List[int]:
    r = [0] * k
    for i in range(N):
        for j in range(k):
            bit = (x[i] >> j) & 1
            r[j] |= (bit << i)
    return r


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


def gen_secb2amodq_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    nshares = NSHARES

    q = 3329
    k = 12

    # Generate expected result.
    x = [random.randint(0, q - 1) for _ in range(N)]
    r = sum(x[i] << (i * 16) for i in range(N))
    r_bytes = int.to_bytes(r, byteorder="little", length=32 * 16)

    # Generate inputs.
    t = [0] * nshares
    rx = x.copy()
    x_bytes = bytes()
    for i in range(nshares - 1):
        t[i] = [random.randint(0, 2**k - 1) for _ in range(N)]
        rx = [(rx[j] ^ t[i][j]) for j in range(N)]
        tmp = bitslice_vec(t[i], k)
        for j in range(k):
            x_bytes += int.to_bytes(tmp[j], byteorder="little", length=32)
    tmp = bitslice_vec(rx, k)
    for j in range(k):
        x_bytes += int.to_bytes(tmp[j], byteorder="little", length=32)

    ra_bytes = int.to_bytes(0, byteorder='little', length=32 * 16 * nshares)

    # Write input values.
    inputs = {'xb': x_bytes, 'ra': ra_bytes}
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
        gen_secb2amodq_test(
            args.seed, args.data, args.exp, args.dexp)
