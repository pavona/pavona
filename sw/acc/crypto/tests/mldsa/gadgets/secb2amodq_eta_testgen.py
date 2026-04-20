#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_LANES = 256
Q = 8380417


def bitslice(vals, bit):
    word = 0
    for i, v in enumerate(vals):
        word |= ((v >> bit) & 1) << i
    return word


def pack_bitsliced(vals, kbits):
    """k stripes * 32 B, contiguous."""
    buf = bytearray()
    for bit in range(kbits):
        buf += bitslice(vals, bit).to_bytes(32, 'little')
    return bytes(buf)


def gen(seed: Optional[int], nshares: int, kbits: int,
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    if nshares != 2:
        raise ValueError('secb2amodq_eta currently only supports nshares=2')

    x_vals = [random.randrange(1 << kbits) for _ in range(N_LANES)]
    x_share0 = [random.randrange(1 << kbits) for _ in range(N_LANES)]
    x_share1 = [x_vals[i] ^ x_share0[i] for i in range(N_LANES)]

    xb_share0 = pack_bitsliced(x_share0, kbits)
    xb_share1 = pack_bitsliced(x_share1, kbits)
    out_init = b'\x00' * (nshares * 1024)

    # Expected: per-coef sum of the two arith shares == x_vals mod q.
    # The test fixture sums the shares and writes the result to `r`.
    r_bytes = bytearray()
    for v in x_vals:
        r_bytes += v.to_bytes(4, 'little')

    write_test_data(
        {'xb_share0': xb_share0, 'xb_share1': xb_share1, 'out': out_init},
        data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'r': bytes(r_bytes)}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('-n', '--nshares', type=int, required=False, default=2)
    parser.add_argument('-k', '--kbits', type=int, required=False, default=3)
    parser.add_argument('--scheme', type=int, required=False, default=1)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen(args.seed, args.nshares, args.kbits, args.data, args.exp, args.dexp)
