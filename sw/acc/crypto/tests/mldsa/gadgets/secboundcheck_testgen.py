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


def arith_share(vals, nshares):
    """nshares dense polys of 256 int32 lane values, XOR-summing... no,
    arithmetic-summing mod Q to vals."""
    shares = [[0] * N_LANES for _ in range(nshares)]
    for lane in range(N_LANES):
        acc = vals[lane] % Q
        for s in range(nshares - 1):
            r = random.randrange(Q)
            shares[s][lane] = r
            acc = (acc - r) % Q
        shares[nshares - 1][lane] = acc
    return shares


def pack_arith_shares(share_vals, nshares):
    """nshares * 1024 B, share-major (each share is a 256-coef poly)."""
    buf = bytearray()
    for s in range(nshares):
        for v in share_vals[s]:
            buf += int(v).to_bytes(4, 'little')
    return bytes(buf)


def pack_c_wdr(C):
    """32-byte WDR-image with C in lane 0 (low 4 bytes); other lanes = 0."""
    return C.to_bytes(4, 'little') + b'\x00' * 28


def gen(seed: Optional[int], nshares: int, lambda0: int, lambda1: int,
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    psi = lambda0 + lambda1
    assert psi < (1 << KBITS) - 1, "psi too large; SecLeq trivially true"
    assert lambda0 + lambda1 < Q, "lambda_0 + lambda_1 must be < q"

    # Mix lanes that pass and lanes that fail.
    x_vals = []
    for _ in range(N_LANES):
        if random.random() < 0.5:
            v = random.randint(-lambda0, lambda1)
        else:
            r = random.randint(lambda1 + 1, Q - lambda0 - 1)
            v = r - lambda0
            v = v % Q
        x_vals.append(v % Q)

    share_vals = arith_share(x_vals, nshares)
    xb = pack_arith_shares(share_vals, nshares)

    C = (1 << (KBITS + 1)) - psi - 1
    cb = pack_c_wdr(C)

    # lambda_0 broadcast vector: 8 lanes (8 int32) packed into one 32-byte WDR.
    lam_bytes = (lambda0 % Q).to_bytes(4, 'little') * 8
    assert len(lam_bytes) == SHARE_BYTES

    # Expected per-lane mask: bit set iff -lambda_0 <= x <= lambda_1 mod q.
    out_word = 0
    for lane, v in enumerate(x_vals):
        # v in [0, Q).  Centered: c = v if v <= Q/2 else v - Q.
        c = v if v <= (Q - 1) // 2 else v - Q
        if -lambda0 <= c <= lambda1:
            out_word |= 1 << lane
    out_bytes = out_word.to_bytes(SHARE_BYTES, 'little')

    write_test_data({
        'x_arith': xb,
        'c_wdr': cb,
        'lambda0_vec': lam_bytes,
    }, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'y_out': out_bytes}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('-n', '--nshares', type=int, required=False, default=2)
    parser.add_argument('--lambda0', type=int, required=True)
    parser.add_argument('--lambda1', type=int, required=True)
    parser.add_argument('--scheme', type=int, required=False, default=1)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen(args.seed, args.nshares, args.lambda0, args.lambda1,
        args.data, args.exp, args.dexp)
