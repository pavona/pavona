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
NSHARES = 2


def arith_share(vals, nshares):
    """Split each lane into nshares additive shares mod Q."""
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


def pack_poly(vals):
    buf = bytearray()
    for v in vals:
        buf += int(v).to_bytes(4, 'little')
    return bytes(buf)


def gen_secunmask_modq_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    x_vals = [random.randrange(Q) for _ in range(N_LANES)]
    share_vals = arith_share(x_vals, NSHARES)
    xb = pack_arith_shares(share_vals, NSHARES)
    yb = pack_poly(x_vals)

    write_test_data({'x_in': xb}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'y_out': yb}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen_secunmask_modq_test(args.seed, args.data, args.exp, args.dexp)
