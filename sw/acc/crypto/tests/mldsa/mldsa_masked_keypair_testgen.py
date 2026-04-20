#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO
from dilithium_py.ml_dsa import ML_DSA_44, ML_DSA_65, ML_DSA_87

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

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


def gen_masked_keypair_test(mldsa, k, ell, eta, nshares, data_file: TextIO,
                            exp_file: TextIO, dexp_file: TextIO):
    zeta = random.randbytes(32)
    pk, sk = mldsa._keygen_internal(zeta)
    seed_bytes = mldsa._h(zeta + bytes([k]) + bytes([ell]), 128)
    rho_prime = seed_bytes[32:96]
    K = sk[32:64]
    tr = sk[64:128]

    polyeta_packed_bytes = 96 if eta == 2 else 128
    t0_start = 128 + (ell + k) * polyeta_packed_bytes
    t0_bytes = k * 416

    sk_blob = bytearray(128 + t0_bytes)
    sk_blob[0:32] = sk[0:32]
    sk_blob[64:128] = tr
    sk_blob[128:128 + t0_bytes] = sk[t0_start:t0_start + t0_bytes]

    # keygen writes rho'/K as random boolean shares (split unknown here); the
    # test harness XORs them back into rho_prime_unmasked/K_unmasked, which the
    # dexp checks against this plaintext.
    write_test_data({'zeta_shares': boolean_shares(zeta, nshares)}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({
        'pk': pk,
        'sk': bytes(sk_blob),
        'rho_prime_unmasked': rho_prime,
        'K_unmasked': K,
    }, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False,
                        help='Seed value for pseudorandomness.')
    parser.add_argument('-n', '--nshares', type=int, default=2,
                        help='Number of shares.')
    parser.add_argument('params', type=str,
                        help='Parameters: ' + ', '.join(INSTANCE_FOR_PARAMS))
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('--scheme', metavar='SCHEME', type=int,
                        help='Not used in this test.')
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
    if args.params not in INSTANCE_FOR_PARAMS:
        raise ValueError(f'Invalid parameters: {args.params}')
    mldsa = INSTANCE_FOR_PARAMS[args.params]
    k, ell, eta = KLE_FOR_PARAMS[args.params]
    gen_masked_keypair_test(mldsa, k, ell, eta, args.nshares,
                            args.data, args.exp, args.dexp)
