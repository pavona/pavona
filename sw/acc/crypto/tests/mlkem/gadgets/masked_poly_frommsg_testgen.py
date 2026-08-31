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
Q = 3329


def frommsg(a: int, q: int) -> List[int]:
    """Convert 32-byte message to polynomial."""
    r = [0] * N
    for i in range(N):
        r[i] = (-((a >> i) & 1) & ((1 << 16) - 1)) & ((q + 1) // 2)
    return r


def gen_masked_poly_frommsg_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    # Random Boolean shares of the message; r is their unmasked XOR.
    rt = 0
    x_bytes = bytes()
    for _ in range(NSHARES):
        x = random.getrandbits(N)
        rt ^= x
        x_bytes += int.to_bytes(x, byteorder="little", length=32)

    # Reference: undo the bitslice layout, then Decompress_q(m, 1).
    r_int = 0
    t = 1 << 15
    v2_15 = sum(t << (lane * 16) for lane in range(16))
    v2_15 &= (1 << N) - 1
    for lane in range(16):
        t = rt & v2_15
        rt <<= 1
        t >>= 15
        for i in range(lane * 16, (lane + 1) * 16):
            r_int |= ((t & 1) << i)
            t >>= 16
    r = frommsg(r_int, Q)
    r_int = sum(r[coeff] << (coeff * 16) for coeff in range(N))
    r_bytes = int.to_bytes(r_int, byteorder='little', length=512)

    # Write input values.
    inputs = {
        'xb': x_bytes,
        'ra': int.to_bytes(0, byteorder='little', length=512 * NSHARES)
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
        gen_masked_poly_frommsg_test(args.seed, args.data, args.exp, args.dexp)
