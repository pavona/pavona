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


def arith_share(vals, nshares):
    """Arithmetic-share mod Q across nshares shares, per lane."""
    shares = [[0] * N_LANES for _ in range(nshares)]
    for lane in range(N_LANES):
        acc = vals[lane]
        for s in range(nshares - 1):
            r = random.randrange(Q)
            shares[s][lane] = r
            acc = (acc - r) % Q
        shares[nshares - 1][lane] = acc % Q
    return shares


def pack_arith_shares(share_vals, kbits, nshares):
    """Produce (kbits+1) * nshares * 32 bytes, share-major bit-inner.
    Top bit (kbits) is zero per share."""
    buf = bytearray()
    for s in range(nshares):
        for bit in range(kbits):
            w = bitslice(share_vals[s], bit)
            buf += w.to_bytes(32, 'little')
        buf += b'\x00' * 32
    return bytes(buf)


def gen_seca2bmodq_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    x_vals = [random.randrange(Q) for _ in range(N_LANES)]
    share_vals = arith_share(x_vals, NSHARES)

    xa = pack_arith_shares(share_vals, KBITS, NSHARES)
    zb_init = b'\x00' * ((KBITS + 1) * NSHARES * 32)

    r_bytes = bytearray()
    for bit in range(KBITS):
        r_bytes += bitslice(x_vals, bit).to_bytes(32, 'little')

    write_test_data({'xa': xa, 'zb': zb_init}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'r': bytes(r_bytes)}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen_seca2bmodq_test(args.seed, args.data, args.exp, args.dexp)
