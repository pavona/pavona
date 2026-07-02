#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_LANES = 256
SHARE_BYTES = 32
KBITS = 23
Q = 8380417
NSHARES = 2

# (lambda_0, lambda_1) bounds secboundcheck is invoked with in the ML-DSA code.
LAMBDAS = [(524091, 524091), (261691, 261691)]


def arith_share(vals):
    """NSHARES dense polys of 256 int32 lane values, arith-summing mod Q."""
    shares = [[0] * N_LANES for _ in range(NSHARES)]
    for lane in range(N_LANES):
        acc = vals[lane] % Q
        for s in range(NSHARES - 1):
            r = random.randrange(Q)
            shares[s][lane] = r
            acc = (acc - r) % Q
        shares[NSHARES - 1][lane] = acc
    return shares


def pack_arith_shares(share_vals):
    """NSHARES * 1024 B, share-major (each share is a 256-coef poly)."""
    buf = bytearray()
    for s in range(NSHARES):
        for v in share_vals[s]:
            buf += int(v).to_bytes(4, 'little')
    return bytes(buf)


def pack_c_wdr(C):
    """32-byte WDR-image with C in lane 0 (low 4 bytes); other lanes = 0."""
    return C.to_bytes(4, 'little') + b'\x00' * 28


def gen_secboundcheck_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    inputs = {}
    dexp = {}
    for idx, (lambda0, lambda1) in enumerate(LAMBDAS):
        psi = lambda0 + lambda1
        assert psi < (1 << KBITS) - 1, "psi too large; SecLeq trivially true"

        # Mix lanes that pass and lanes that fail.
        x_vals = []
        for _ in range(N_LANES):
            if random.random() < 0.5:
                v = random.randint(-lambda0, lambda1)
            else:
                r = random.randint(lambda1 + 1, Q - lambda0 - 1)
                v = (r - lambda0) % Q
            x_vals.append(v % Q)

        xb = pack_arith_shares(arith_share(x_vals))
        cb = pack_c_wdr((1 << (KBITS + 1)) - psi - 1)
        # lambda_0 broadcast: 8 int32 lanes packed into one 32-byte WDR.
        lam_bytes = (lambda0 % Q).to_bytes(4, 'little') * 8

        # Expected per-lane mask: bit set iff -lambda_0 <= x <= lambda_1 mod q.
        out_word = 0
        for lane, v in enumerate(x_vals):
            c = v if v <= (Q - 1) // 2 else v - Q
            if -lambda0 <= c <= lambda1:
                out_word |= 1 << lane

        inputs['x_arith{}'.format(idx)] = xb
        inputs['c_wdr{}'.format(idx)] = cb
        inputs['lambda0_vec{}'.format(idx)] = lam_bytes
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
    gen_secboundcheck_test(args.seed, args.data, args.exp, args.dexp)
