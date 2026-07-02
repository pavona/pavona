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
K = 23
KP1 = K + 1
Q = 0x7FE001  # ML-DSA modulus.


def to_words_bytes(words):
    out = bytes()
    for w in words:
        out += int.to_bytes(w, byteorder="little", length=32)
    return out


def gen_secadd_constant_bmsk_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    # Boolean shares of sp (each share is k+1 bitsliced words).
    s0 = [random.getrandbits(N) for _ in range(KP1)]
    s1 = [random.getrandbits(N) for _ in range(KP1)]
    spb = to_words_bytes(s0) + to_words_bytes(s1)

    # z = (sp_low_k + (sp[k] ? q : 0)) mod 2^k, with z[k] = 0, per lane.
    spv = [s0[j] ^ s1[j] for j in range(KP1)]
    z = [0] * KP1
    for i in range(N):
        sp_i = 0
        for j in range(KP1):
            sp_i |= ((spv[j] >> i) & 1) << j
        b = (sp_i >> K) & 1
        zi = ((sp_i & ((1 << K) - 1)) + (Q if b else 0)) & ((1 << K) - 1)
        for j in range(KP1):
            z[j] |= ((zi >> j) & 1) << i

    write_test_data({'spb': spb}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'z': to_words_bytes(z)}, dexp_file)


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

    gen_secadd_constant_bmsk_test(args.seed, args.data, args.exp, args.dexp)
