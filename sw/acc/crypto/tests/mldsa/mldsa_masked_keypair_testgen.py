#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO
from dilithium_py.ml_dsa import ML_DSA_44, ML_DSA_65, ML_DSA_87

from shared.testgen import write_testcase

INSTANCE_FOR_PARAMS = {
    'mldsa44': ML_DSA_44,
    'mldsa65': ML_DSA_65,
    'mldsa87': ML_DSA_87,
}

# (k, l, eta) per parameter set.
KLE_FOR_PARAMS = {
    'mldsa44': (4, 4, 2),
    'mldsa65': (6, 5, 4),
    'mldsa87': (8, 7, 2),
}


def boolean_shares(secret: bytes, nshares: int) -> bytes:
    shares = []
    acc = secret
    for _ in range(nshares - 1):
        s = random.randbytes(len(secret))
        acc = bytes(a ^ b for a, b in zip(acc, s))
        shares.append(s)
    shares.append(acc)
    return b''.join(shares)


def bitslice(coeffs: list, kbits: int) -> bytes:
    '''Lay 256 small values out as the ACC bitslice gadget does: output stripe
    j (32 B) bit i = bit j of coeff i.'''
    out = bytearray(kbits * 32)
    for j in range(kbits):
        for b in range(32):
            byte = 0
            for p in range(8):
                byte |= ((coeffs[b * 8 + p] >> j) & 1) << p
            out[j * 32 + b] = byte
    return bytes(out)


def gen_masked_keypair_test(mldsa, k, ell, eta, nshares, tc_file: TextIO):
    zeta = random.randbytes(32)
    pk, sk = mldsa._keygen_internal(zeta)
    K = sk[32:64]
    tr = sk[64:128]

    polyeta_packed_bytes = 96 if eta == 2 else 128
    kbits = 3 if eta == 2 else 4
    mask = (1 << kbits) - 1
    s1s2_start = 128
    t0_start = s1s2_start + (ell + k) * polyeta_packed_bytes
    t0_bytes = k * 416

    # The ACC secret key holds rho/tr/t0 (no s1/s2; sk[32:64] stays zero); s1/s2
    # are stored separately in s1s2_shares, Boolean-masked and bitsliced.
    sk_blob = bytearray(128 + t0_bytes)
    sk_blob[0:32] = sk[0:32]
    sk_blob[64:128] = tr
    sk_blob[128:128 + t0_bytes] = sk[t0_start:t0_start + t0_bytes]

    # Expected unmasked s1||s2: each reference polyeta chunk already packs
    # t = eta - s; unpack it and re-lay-out as bitslice stripes, matching what
    # the test harness reconstructs by XORing the two stored shares.
    s1s2_unmasked = bytearray()
    for poly in range(ell + k):
        chunk = sk[s1s2_start + poly * polyeta_packed_bytes:
                   s1s2_start + (poly + 1) * polyeta_packed_bytes]
        bits = int.from_bytes(chunk, 'little')
        t = [(bits >> (kbits * i)) & mask for i in range(256)]
        s1s2_unmasked += bitslice(t, kbits)

    # The wrapper preloads zeta_shares, runs keygen, and XORs the random K/s1/s2
    # shares back into K_unmasked / s1s2_shares for these checks.
    write_testcase(
        tc_file,
        inputs={'zeta_shares': boolean_shares(zeta, nshares)},
        outputs={
            'pk': pk,
            'sk': bytes(sk_blob),
            'K_unmasked': K,
            's1s2_shares': bytes(s1s2_unmasked),
        })


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False,
                        help='Seed value for pseudorandomness.')
    parser.add_argument('-n', '--nshares', type=int, default=2,
                        help='Number of shares.')
    parser.add_argument('params', type=str,
                        help='Parameters: ' + ', '.join(INSTANCE_FOR_PARAMS))
    parser.add_argument('testcase', metavar='FILE', type=argparse.FileType('w'),
                        help='Output file for the accsim testcase (hjson).')
    parser.add_argument('--scheme', metavar='SCHEME', type=int,
                        help='Not used in this test.')
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
    if args.params not in INSTANCE_FOR_PARAMS:
        raise ValueError(f'Invalid parameters: {args.params}')
    mldsa = INSTANCE_FOR_PARAMS[args.params]
    k, ell, eta = KLE_FOR_PARAMS[args.params]
    with args.testcase:
        gen_masked_keypair_test(mldsa, k, ell, eta, args.nshares,
                                args.testcase)
