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

# (k, c) pairs secadd_immd_d2 is invoked with in the ML-DSA code.
CONFIGS = [(24, 0x800000), (8, 212), (5, 27), (5, 22)]


def to_words_bytes(words):
    out = bytes()
    for w in words:
        out += int.to_bytes(w, byteorder="little", length=32)
    return out


def gen_one(k, c):
    # Boolean shares of x (each share is k bitsliced words).
    s0 = [random.getrandbits(N) for _ in range(k)]
    s1 = [random.getrandbits(N) for _ in range(k)]
    xb = to_words_bytes(s0) + to_words_bytes(s1)

    # z = (x + c) mod 2^k, per lane.
    v = [s0[j] ^ s1[j] for j in range(k)]
    z = [0] * k
    for i in range(N):
        vi = 0
        for j in range(k):
            vi |= ((v[j] >> i) & 1) << j
        zi = (vi + c) & ((1 << k) - 1)
        for j in range(k):
            z[j] |= ((zi >> j) & 1) << i

    zb_zero = int.to_bytes(0, byteorder="little", length=NSHARES * k * 32)
    return xb, zb_zero, to_words_bytes(z)


def gen_secadd_immd_d2_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    inputs = {}
    dexp = {}
    for idx, (k, c) in enumerate(CONFIGS):
        xb, zb, z = gen_one(k, c)
        inputs['xb{}'.format(idx)] = xb
        inputs['zb{}'.format(idx)] = zb
        dexp['z{}'.format(idx)] = z

    write_test_data(inputs, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp(dexp, dexp_file)


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

    gen_secadd_immd_d2_test(args.seed, args.data, args.exp, args.dexp)
