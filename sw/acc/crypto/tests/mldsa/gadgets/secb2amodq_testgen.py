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
KBITS = 23
NSHARES = 2


def bitslice(vals, bit):
    word = 0
    for i, v in enumerate(vals):
        word |= ((v >> bit) & 1) << i
    return word


def pack_bool_shares(shares, kbits):
    """Share-major bit-inner: (kbits+1) * nshares * 32 bytes, top bit zero."""
    nshares = len(shares)
    buf = bytearray()
    for s in range(nshares):
        for bit in range(kbits):
            buf += bitslice(shares[s], bit).to_bytes(32, 'little')
        buf += b'\x00' * 32
    return bytes(buf)


def gen_secb2amodq_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    x_vals = [random.randrange(Q) for _ in range(N_LANES)]
    x_share0 = [random.randrange(1 << KBITS) for _ in range(N_LANES)]
    x_share1 = [x_vals[i] ^ x_share0[i] for i in range(N_LANES)]

    xb = pack_bool_shares([x_share0, x_share1], KBITS)
    za_init = b'\x00' * ((KBITS + 1) * NSHARES * 32)
    zb2_init = b'\x00' * ((KBITS + 1) * NSHARES * 32)

    r_bytes = bytearray()
    for bit in range(KBITS):
        r_bytes += bitslice(x_vals, bit).to_bytes(32, 'little')

    write_test_data({'xb': xb, 'za': za_init, 'zb2': zb2_init}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'r': bytes(r_bytes)}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen_secb2amodq_test(args.seed, args.data, args.exp, args.dexp)
