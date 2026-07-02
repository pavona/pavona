#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
KBITS = 23
NQ = 0x801FFF  # 2^24 - q, the hard-coded addend.


def bitslice(vals, nwords):
    words = [0] * nwords
    for i, v in enumerate(vals):
        for j in range(nwords):
            words[j] |= ((v >> j) & 1) << i
    return words


def to_words_bytes(words):
    out = bytes()
    for w in words:
        out += int.to_bytes(w, byteorder="little", length=32)
    return out


def gen_secadd_immd_d1_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    # 256 lanes of random kbits-bit inputs.
    xv = [random.getrandbits(KBITS) for _ in range(N)]
    # z = (x + nq) mod 2^(kbits + 1).
    z = [(v + NQ) & ((1 << (KBITS + 1)) - 1) for v in xv]

    write_test_data({'xb': to_words_bytes(bitslice(xv, KBITS))}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'z': to_words_bytes(bitslice(z, KBITS + 1))}, dexp_file)


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

    gen_secadd_immd_d1_test(args.seed, args.data, args.exp, args.dexp)
