#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# One binary exercises both secdecompose variants (selected by the a2 argument):
# ML-DSA-44 (L2, arithmetic w0 in place) and ML-DSA-65/87 (L35, Boolean shares
# of U = gamma2 - w0, recovered here via b2a).

import argparse
import random
from typing import TextIO, Optional

from dilithium_py.ml_dsa import ML_DSA_44, ML_DSA_65
from dilithium_py.utilities.utils import decompose

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_COEFS = 256
Q = 8380417
NSHARES = 2

# Alg.36 special-case coeffs to pin (folded bucket + adjacent unfolded one).
SPECIAL_L2 = [Q - 1, Q - 2, 8285185, 8285184, 8330000]
SPECIAL_L35 = [Q - 1, Q - 2, 8118529, 8118528, 8249473]

PINNED_SHARE0_L2 = {
    8285185: 5779889,  # least SecCompress rounding slack; needs the +1 bias
    8330000: 8350000,  # share 0 > w, so V' reaches 88 and both csubs run
}


def edge_coeffs(gamma2):
    """Every bucket boundary: w0 = 0, +gamma2 and -gamma2+1."""
    alpha = 2 * gamma2
    vals = {0, 1, Q - 1, Q - 2}
    for k in range(Q // alpha + 1):
        vals.update(v for v in (k * alpha, k * alpha + gamma2,
                                k * alpha + gamma2 + 1) if v < Q)
    return sorted(vals)


def arith_share(vals, pinned=None):
    shares = [[0] * N_COEFS for _ in range(NSHARES)]
    for lane in range(N_COEFS):
        acc = vals[lane]
        for s in range(NSHARES - 1):
            r = random.randrange(Q)
            if pinned is not None:
                r = pinned.get(vals[lane], r)
            shares[s][lane] = r
            acc = (acc - r) % Q
        shares[NSHARES - 1][lane] = acc % Q
    return shares


def pack_arith_shares(share_vals):
    """NSHARES * 1024 B, share-major (each share is a 256-coef poly)."""
    buf = bytearray()
    for s in range(NSHARES):
        for v in share_vals[s]:
            buf += int(v).to_bytes(4, 'little')
    return bytes(buf)


def pack_canonical(vals):
    buf = bytearray()
    for v in vals:
        buf += (int(v) % Q).to_bytes(4, 'little')
    return bytes(buf)


def decompose_poly(mldsa, special, pinned=None):
    alpha = 2 * mldsa.gamma_2
    w_vals = [random.randrange(Q) for _ in range(N_COEFS)]
    fixed = special + [v for v in edge_coeffs(mldsa.gamma_2) if v not in special]
    fixed += [v for v in (pinned or {}) if v not in fixed]
    assert len(fixed) <= N_COEFS
    w_vals[:len(fixed)] = fixed
    w1_ref, w0_ref = [], []
    for v in w_vals:
        r1, r0 = decompose(v, alpha, Q)
        w1_ref.append(r1)
        w0_ref.append(r0)
    return arith_share(w_vals, pinned), w1_ref, w0_ref


def gen_secdecompose_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    sh2, w1_2, w0_2 = decompose_poly(ML_DSA_44, SPECIAL_L2, PINNED_SHARE0_L2)
    sh35, w1_35, w0_35 = decompose_poly(ML_DSA_65, SPECIAL_L35)
    gamma2_35 = ML_DSA_65.gamma_2

    write_test_data({
        'w_in_l2': pack_arith_shares(sh2),
        'w1_out_l2': b'\x00' * (N_COEFS * 4),
        'w_in_l35': pack_arith_shares(sh35),
        'w1_out_l35': b'\x00' * (N_COEFS * 4),
    }, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({
        'w1_out_l2': pack_canonical(w1_2),
        'w0_unmasked': pack_canonical(w0_2),
        'w1_out_l35': pack_canonical(w1_35),
        'u_unmasked': pack_canonical([gamma2_35 - a0 for a0 in w0_35]),
    }, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    with args.data, args.exp, args.dexp:
        gen_secdecompose_test(args.seed, args.data, args.exp, args.dexp)
