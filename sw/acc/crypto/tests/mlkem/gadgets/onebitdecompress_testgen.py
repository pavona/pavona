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


def frommsg(a: int, q: int) -> List[int]:
    """Convert 32-byte message to polynomial."""
    r = [0] * N
    for i in range(N):
        r[i] = (-((a >> i) & 1) & ((1 << 16) - 1)) & ((q + 1) // 2)
    return r


def gen_onebitdecompress_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    operand_nbytes = 512 * NSHARES

    # Random Boolean shares of the message; r is their unmasked XOR.
    r = 0
    x_bytes = bytes()
    for _ in range(NSHARES):
        t = random.getrandbits(N)
        r ^= t
        x_bytes += int.to_bytes(t, byteorder="little", length=32)

    # Reference: undo the bitslice layout, then Decompress_q(m, 1).
    exp = 0
    one = sum(1 << (i * 16) for i in range(16))
    one = (one << 15) & ((1 << N) - 1)
    for i in range(16):
        t = r & one
        r <<= 1
        t >>= 15
        for j in range(i * 16, (i + 1) * 16):
            exp |= ((t & 1) << j)
            t >>= 16
    exp = frommsg(exp, 3329)
    exp = sum(exp[i] << (i * 16) for i in range(N))
    r_bytes = int.to_bytes(exp, byteorder='little', length=512)

    ra_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)

    write_test_data({'xb': x_bytes, 'ra': ra_bytes}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'r': r_bytes}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False,
                        help='Seed value for pseudorandomness.')
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'),
                        help='Output file for input DMEM values.')
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'),
                        help='Output file for expected register values.')
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'),
                        help='Output file for expected DMEM values.')
    args = parser.parse_args()

    with args.data, args.exp, args.dexp:
        gen_onebitdecompress_test(args.seed, args.data, args.exp, args.dexp)
