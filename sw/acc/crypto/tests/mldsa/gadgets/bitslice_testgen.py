#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_COEFS = 256

# bitslice emits kbits = 23 stripes; bitslice_k32 emits 32.
KS = [23, 32]


def pack_canonical(vals):
    """256 x 32-bit coefs -> 32 WDRs (1024 bytes)."""
    buf = bytearray()
    for v in vals:
        buf += v.to_bytes(4, 'little')
    return bytes(buf)


def pack_bitsliced(vals, kbits):
    """256 coefs -> kbits WDRs bitsliced (lane i of WDR j = bit j of coef i)."""
    out = bytearray()
    for b in range(kbits):
        w = sum(((v >> b) & 1) << i for i, v in enumerate(vals))
        out += w.to_bytes(32, 'little')
    return bytes(out)


def gen_bitslice_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)
    inputs = {}
    dexp = {}
    for k in KS:
        vals = [random.randrange(1 << k) for _ in range(N_COEFS)]
        inputs['in{}'.format(k)] = pack_canonical(vals)
        inputs['r{}'.format(k)] = b'\x00' * (k * 32)
        dexp['r{}'.format(k)] = pack_bitsliced(vals, k)
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
    gen_bitslice_test(args.seed, args.data, args.exp, args.dexp)
