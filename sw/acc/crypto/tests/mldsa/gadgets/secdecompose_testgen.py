#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from dilithium_py.ml_dsa import ML_DSA_44, ML_DSA_65, ML_DSA_87
from dilithium_py.utilities.utils import decompose

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_COEFS = 256
Q = 8380417

# Per scheme: parameter set, whether to check U = gamma2 - w0 (L3/L5) vs w0 (L2),
# and Alg.36 special-case coeffs to pin (folded bucket + adjacent unfolded one).
SCHEMES = {
    2: {'mldsa': ML_DSA_44, 'emit_u': False,
        'special': [Q - 1, Q - 2, 8285185, 8285184, 8330000]},
    3: {'mldsa': ML_DSA_65, 'emit_u': True,
        'special': [Q - 1, Q - 2, 8118529, 8118528, 8249473]},
    5: {'mldsa': ML_DSA_87, 'emit_u': True,
        'special': [Q - 1, Q - 2, 8118529, 8118528, 8249473]},
}


def arith_share(vals, nshares):
    shares = [[0] * N_COEFS for _ in range(nshares)]
    for lane in range(N_COEFS):
        acc = vals[lane]
        for s in range(nshares - 1):
            r = random.randrange(Q)
            shares[s][lane] = r
            acc = (acc - r) % Q
        shares[nshares - 1][lane] = acc % Q
    return shares


def pack_arith_shares(share_vals, nshares):
    """NSHARES * 1024 B, share-major (each share is a 256-coef poly)."""
    buf = bytearray()
    for s in range(nshares):
        for v in share_vals[s]:
            buf += int(v).to_bytes(4, 'little')
    return bytes(buf)


def pack_canonical(vals):
    buf = bytearray()
    for v in vals:
        buf += (int(v) % Q).to_bytes(4, 'little')
    return bytes(buf)


def gen(seed: Optional[int], nshares: int, scheme: int,
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)
    cfg = SCHEMES[scheme]
    gamma2 = cfg['mldsa'].gamma_2
    alpha = 2 * gamma2

    w_vals = [random.randrange(Q) for _ in range(N_COEFS)]
    # Pin some special cases
    w_vals[:len(cfg['special'])] = cfg['special']
    share_vals = arith_share(w_vals, nshares)

    w1_ref, w0_ref = [], []
    for v in w_vals:
        r1, r0 = decompose(v, alpha, Q)
        w1_ref.append(r1)
        w0_ref.append(r0)

    write_test_data({
        'w_in': pack_arith_shares(share_vals, nshares),
        'w1_out': b'\x00' * (N_COEFS * 4),
    }, data_file)
    write_test_exp({}, exp_file)
    dexp = {'w1_out': pack_canonical(w1_ref)}
    if cfg['emit_u']:
        # L3/L5 expose U = gamma2 - w0; L2 exposes arithmetic w0 directly.
        dexp['u_unmasked'] = pack_canonical([gamma2 - a0 for a0 in w0_ref])
    else:
        dexp['w0_unmasked'] = pack_canonical(w0_ref)
    write_test_dexp(dexp, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('-n', '--nshares', type=int, required=False, default=2)
    parser.add_argument('--scheme', type=int, required=False, default=2)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen(args.seed, args.nshares, args.scheme, args.data, args.exp, args.dexp)
