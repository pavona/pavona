#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Test vectors for seccompress (ML-DSA-44 L2 SecCompress, d = 2): from a 2-share
# arithmetic sharing of x mod q, the expected output is w1 = HighBits(x), packed
# as ceil(log2(delta)) = 6 bit-stripes.  The harness XOR-collapses the gadget's
# Boolean output and compares stripe-by-stripe.

import argparse
import random
from typing import TextIO, Optional

from dilithium_py.ml_dsa import ML_DSA_44
from dilithium_py.utilities.utils import high_bits

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_LANES = 256
Q = 8380417
NSHARES = 2
DELTA = 44


PINNED_SHARE0 = {
    8285185: 5779889,  # least rounding slack; only correct with the +1 bias
    8330000: 8350000,  # share 0 > x, so V' reaches 88 and both csubs run
}


def edge_coeffs(gamma2):
    """Every bucket boundary: low part 0, +gamma2 and -gamma2+1."""
    alpha = 2 * gamma2
    vals = {0, 1, Q - 1, Q - 2}
    for k in range(Q // alpha + 1):
        vals.update(v for v in (k * alpha, k * alpha + gamma2,
                                k * alpha + gamma2 + 1) if v < Q)
    return sorted(vals)


def arith_share_modq(vals, nshares, pinned=None):
    shares = [[0] * N_LANES for _ in range(nshares)]
    for lane in range(N_LANES):
        acc = vals[lane]
        for s in range(nshares - 1):
            r = random.randrange(Q)
            if pinned is not None:
                r = pinned.get(vals[lane], r)
            shares[s][lane] = r
            acc = (acc - r) % Q
        shares[nshares - 1][lane] = acc % Q
    return shares


def pack_dense_shares(share_vals, nshares):
    """nshares * 1024 B, share-major (each share is a 256-coef poly)."""
    buf = bytearray()
    for s in range(nshares):
        for v in share_vals[s]:
            buf += int(v).to_bytes(4, 'little')
    return bytes(buf)


def pack_stripes(vals, nbits):
    """Bit b of each lane packed into a 256-bit word, for b in [0, nbits)."""
    buf = bytearray()
    for bit in range(nbits):
        word = 0
        for i, v in enumerate(vals):
            word |= ((v >> bit) & 1) << i
        buf += word.to_bytes(32, 'little')
    return bytes(buf)


def gen_seccompress_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    x_vals = [random.randrange(Q) for _ in range(N_LANES)]
    fixed = edge_coeffs(ML_DSA_44.gamma_2)
    fixed += [v for v in PINNED_SHARE0 if v not in fixed]
    assert len(fixed) <= N_LANES
    x_vals[:len(fixed)] = fixed
    share_vals = arith_share_modq(x_vals, NSHARES, PINNED_SHARE0)

    alpha = 2 * ML_DSA_44.gamma_2
    w1 = [high_bits(x, alpha, Q) for x in x_vals]
    c_out = (DELTA - 1).bit_length()             # ceil(log2(delta)) = 6

    write_test_data({
        'xa': pack_dense_shares(share_vals, NSHARES),
        'zb': b'\x00' * (32 * NSHARES * 32),
    }, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'r': pack_stripes(w1, c_out)}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    with args.data, args.exp, args.dexp:
        gen_seccompress_test(args.seed, args.data, args.exp, args.dexp)
