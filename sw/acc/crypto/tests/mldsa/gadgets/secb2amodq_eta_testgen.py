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
NSHARES = 2

# secb2amodq_eta is invoked with k = 3 (eta = 2) and k = 4 (eta = 4).
KS = [3, 4]


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


def gen_secb2amodq_eta_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    inputs = {}
    dexp = {}
    for k in KS:
        x_vals = [random.randrange(1 << k) for _ in range(N_LANES)]
        x_share0 = [random.randrange(1 << k) for _ in range(N_LANES)]
        x_share1 = [x_vals[i] ^ x_share0[i] for i in range(N_LANES)]

        inputs['xb0_k{}'.format(k)] = pack_bitsliced(x_share0, k)
        inputs['xb1_k{}'.format(k)] = pack_bitsliced(x_share1, k)
        inputs['out_k{}'.format(k)] = b'\x00' * (NSHARES * 1024)

        # The test fixture sums the two arith shares; expect x_vals mod q.
        r_bytes = bytearray()
        for v in x_vals:
            r_bytes += v.to_bytes(4, 'little')
        dexp['r_k{}'.format(k)] = bytes(r_bytes)

    write_test_data(inputs, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp(dexp, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen_secb2amodq_eta_test(args.seed, args.data, args.exp, args.dexp)
