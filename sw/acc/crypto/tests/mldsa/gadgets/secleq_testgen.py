#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

SHARE_BYTES = 32  # 256 bitsliced lanes per WDR
N_LANES = 256
NSHARES = 2
KBITS = 23

# psi bounds secleq is invoked with in the ML-DSA code.
PSIS = [1048182, 523382]


def bitslice(vals, bit):
    word = 0
    for i, v in enumerate(vals):
        word |= ((v >> bit) & 1) << i
    return word


def bool_share(word, nshares):
    shares = []
    acc = word
    for _ in range(nshares - 1):
        s = random.getrandbits(N_LANES)
        shares.append(s)
        acc ^= s
    shares.append(acc)
    return shares


def pack_shares_sharemajor(vals, kbits, nshares):
    """(kbits+1) * nshares * 32 bytes, share-major bit-inner with bit k = 0."""
    bit_shares = [bool_share(bitslice(vals, bit), nshares) for bit in range(kbits)]
    buf = bytearray()
    for s in range(nshares):
        for bit in range(kbits):
            buf += bit_shares[bit][s].to_bytes(SHARE_BYTES, 'little')
        buf += b'\x00' * SHARE_BYTES  # bit k pad
    return bytes(buf)


def pack_c_wdr(C):
    """32-byte WDR-image with C in lane 0 (low 4 bytes); other lanes = 0."""
    return C.to_bytes(4, 'little') + b'\x00' * 28


def gen_secleq_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    inputs = {}
    dexp = {}
    for idx, psi in enumerate(PSIS):
        # Random k-bit values per lane (x is clobbered in place, so each psi
        # case gets its own buffer).
        x_vals = [random.randrange(0, 1 << KBITS) for _ in range(N_LANES)]
        C = (1 << (KBITS + 1)) - psi - 1

        # Expected per-lane bit: 1 iff x[lane] <= psi.
        out_word = 0
        for lane, v in enumerate(x_vals):
            if v <= psi:
                out_word |= 1 << lane

        inputs['x_in{}'.format(idx)] = pack_shares_sharemajor(
            x_vals, KBITS, NSHARES)
        inputs['c_wdr{}'.format(idx)] = pack_c_wdr(C)
        dexp['y_out{}'.format(idx)] = out_word.to_bytes(SHARE_BYTES, 'little')

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
    gen_secleq_test(args.seed, args.data, args.exp, args.dexp)
