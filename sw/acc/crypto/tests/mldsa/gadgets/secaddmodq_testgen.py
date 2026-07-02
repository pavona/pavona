#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_LANES = 256  # bitslice width = one ACC WDR
Q = 8380417
KBITS = 23
NSHARES = 2


def bitslice(vals, bit):
    """Pack bit `bit` of each of 256 values into one 256-bit word."""
    word = 0
    for i, v in enumerate(vals):
        word |= ((v >> bit) & 1) << i
    return word


def share(word, nshares):
    """Boolean-share a 256-bit word into nshares 256-bit shares."""
    shares = []
    acc = word
    for _ in range(nshares - 1):
        s = random.getrandbits(N_LANES)
        shares.append(s)
        acc ^= s
    shares.append(acc)
    return shares


def pack_shared_bits(vals, kbits, nshares):
    """Produce (kbits+1) * nshares * 32 bytes, share-major bit-inner.
    Top bit (kbits) is zero per share."""
    shares_bits = [[0] * kbits for _ in range(nshares)]
    for bit in range(kbits):
        w = bitslice(vals, bit)
        ss = share(w, nshares)
        for s in range(nshares):
            shares_bits[s][bit] = ss[s]
    buf = bytearray()
    for s in range(nshares):
        for bit in range(kbits):
            buf += shares_bits[s][bit].to_bytes(32, 'little')
        # bit kbits = 0
        buf += b'\x00' * 32
    return bytes(buf)


def gen_secaddmodq_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    x_vals = [random.randrange(Q) for _ in range(N_LANES)]
    y_vals = [random.randrange(Q) for _ in range(N_LANES)]
    z_vals = [(x + y) % Q for x, y in zip(x_vals, y_vals)]

    xb = pack_shared_bits(x_vals, KBITS, NSHARES)
    yb = pack_shared_bits(y_vals, KBITS, NSHARES)
    zb_init = b'\x00' * ((KBITS + 1) * NSHARES * 32)

    r_bytes = bytearray()
    for bit in range(KBITS):
        r_bytes += bitslice(z_vals, bit).to_bytes(32, 'little')

    write_test_data({'xb': xb, 'yb': yb, 'zb': zb_init}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'r': bytes(r_bytes)}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen_secaddmodq_test(args.seed, args.data, args.exp, args.dexp)
