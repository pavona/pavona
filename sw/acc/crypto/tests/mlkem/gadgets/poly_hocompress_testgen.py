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


def compress(x: int, d: int) -> int:
    """Kyber coefficient compression to d bits."""
    return (((x << d) + Q // 2) // Q) & ((1 << d) - 1)


def bitslice(coeffs: list, d: int) -> bytes:
    """Bitslice N d-bit coefficients into d planes of 32 bytes."""
    m = (1 << N) - 1
    one = sum(1 << (i * 16) for i in range(16)) & m
    rt = [sum(coeffs[j + i] << (i * 16) for i in range(16))
          for j in range(0, N, 16)]
    out = bytes()
    for _ in range(d):
        t = 0
        for j in range(16):
            t = (t << 1) | (rt[j] & one)
            rt[j] >>= 1
        out += int.to_bytes(t, byteorder="little", length=32)
    return out


def gen_poly_hocompress_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    # Random arithmetic shares of x; r is their unmasked sum mod q.
    r = [0] * N
    x_bytes = bytes()
    for _ in range(NSHARES):
        xi = [random.randint(0, Q - 1) for _ in range(N)]
        r = [(r[j] + xi[j]) % Q for j in range(N)]
        x_bytes += int.to_bytes(sum(xi[j] << (j * 16) for j in range(N)),
                                byteorder="little", length=512)

    # Reference compressions for both dv values (dv = 4 for k != 4, dv = 5 for
    # k == 4); the gadget is exercised at both.
    rv4 = bitslice([compress(r[i], 4) for i in range(N)], 4)
    rv5 = bitslice([compress(r[i], 5) for i in range(N)], 5)

    # Output buffer, reused for both calls and sized for the larger dv = 5 case.
    rbv = int.to_bytes(0, byteorder='little', length=32 * 5 * NSHARES)

    write_test_data({'xa': x_bytes, 'rbv': rbv}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'rv4': rv4, 'rv5': rv5}, dexp_file)


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
        gen_poly_hocompress_test(args.seed, args.data, args.exp, args.dexp)
