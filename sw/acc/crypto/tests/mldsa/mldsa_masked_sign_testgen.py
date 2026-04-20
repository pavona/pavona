#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import hashlib
import json
import random
from typing import TextIO
from dilithium_py.ml_dsa import ML_DSA_44, ML_DSA_65, ML_DSA_87

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

INSTANCE_FOR_PARAMS = {
    'mldsa44': ML_DSA_44,
    'mldsa65': ML_DSA_65,
    'mldsa87': ML_DSA_87,
}

L_K_ETA = {
    'mldsa44': (4, 4, 2),
    'mldsa65': (5, 6, 4),
    'mldsa87': (7, 8, 2),
}

MIN_MSG_LEN = 0
MAX_MSG_LEN = 3072

MIN_CTX_LEN = 0
MAX_CTX_LEN = 255


def boolean_shares(secret: bytes, nshares: int) -> bytes:
    shares = []
    acc = secret
    for _ in range(nshares - 1):
        s = random.randbytes(len(secret))
        acc = bytes(a ^ b for a, b in zip(acc, s))
        shares.append(s)
    shares.append(acc)
    return b''.join(shares)


def boolean_shares_polyeta_packed(packed_polys: bytes, polyeta_bytes: int, nshares: int) -> bytes:
    '''Boolean shares of polyeta-packed bytes, poly-major / share-inner.'''
    out = bytearray()
    for poly_i in range(len(packed_polys) // polyeta_bytes):
        poly = packed_polys[poly_i * polyeta_bytes:(poly_i + 1) * polyeta_bytes]
        out += boolean_shares(poly, nshares)
    return bytes(out)


def gen_sign_test(
        mldsa, ell, k, eta, nshares: int, data_file: TextIO,
        exp_file: TextIO, dexp_file: TextIO, vector=None):
    if vector is not None:
        # Curated bench vector (empty context, as produced by mldsa-sign-bench).
        sk = bytes.fromhex(vector['sk'])
        rnd = bytes.fromhex(vector['rnd'])
        msg = bytes.fromhex(vector['msg'])
        ctx = b''
        ctxlen = 0
        sig = bytes.fromhex(vector['sig'])
        rho_prime = mldsa._h(
            bytes.fromhex(vector['keygen_seed']) + bytes([k]) + bytes([ell]),
            128)[32:96]
    else:
        seed = random.randbytes(32)
        pk, sk = mldsa._keygen_internal(seed)
        rho_prime = mldsa._h(seed + bytes([k]) + bytes([ell]), 128)[32:96]

        msglen = random.randrange(MIN_MSG_LEN, MAX_MSG_LEN + 1)
        ctxlen = random.randrange(MIN_CTX_LEN, MAX_CTX_LEN + 1)
        msg = random.randbytes(msglen)
        ctx = random.randbytes(ctxlen)

        rnd = bytes([0] * 32)
        sig = mldsa.sign(sk, msg, ctx=ctx, deterministic=True)

    K = sk[32:64]
    tr = sk[64:128]

    # External-mu mode: caller pre-hashes message+context.  mu = SHAKE256
    # (tr || 0x00 || byte(ctxlen) || ctx || msg, 64).  Matches FIPS 204
    # Algorithm 7 (ML-DSA.Sign_internal) and the M* construction in Sign.
    shake = hashlib.shake_256()
    shake.update(tr)
    shake.update(bytes([0x00, ctxlen]))
    shake.update(ctx)
    shake.update(msg)
    mu = shake.digest(64)

    polyeta_packed_bytes = 96 if eta == 2 else 128
    s1_start = 128
    s2_start = s1_start + ell * polyeta_packed_bytes
    t0_start = s2_start + k * polyeta_packed_bytes

    # sk for masked-sign build: rho@0, tr@64, t0@128.  K slot zeroed to keep tr at 64.
    t0_bytes = k * 416
    sk_blob = bytearray(128 + t0_bytes)
    sk_blob[0:32] = sk[0:32]
    sk_blob[64:128] = sk[64:128]
    sk_blob[128:128 + t0_bytes] = sk[t0_start:t0_start + t0_bytes]

    data = {
        'mu': mu,
        'sk': bytes(sk_blob),
        'K_shares': boolean_shares(K, nshares),
        'rho_prime_shares': boolean_shares(rho_prime, nshares),
        'rnd': rnd,
    }
    write_test_data(data, data_file)

    write_test_exp({}, exp_file)

    write_test_dexp({'sig': sig}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
    parser.add_argument('-n', '--nshares',
                        type=int,
                        required=False,
                        default=2,
                        help=('Number of shares.'))
    parser.add_argument('params',
                        type=str,
                        help=('Parameters to use. Options: '
                              f'{", ".join(INSTANCE_FOR_PARAMS.keys())}'))
    parser.add_argument('data',
                        metavar='FILE',
                        type=argparse.FileType('w'),
                        help=('Output file for input DMEM values.'))
    parser.add_argument('exp',
                        metavar='FILE',
                        type=argparse.FileType('w'),
                        help=('Output file for expected register values.'))
    parser.add_argument('dexp',
                        metavar='FILE',
                        type=argparse.FileType('w'),
                        help=('Output file for expected DMEM values.'))
    parser.add_argument('--scheme',
                        metavar='SCHEME',
                        type=int,
                        help=('This is not used in this test.'))
    parser.add_argument('--from-vector',
                        dest='from_vector',
                        type=str,
                        required=False,
                        help=('Load inputs from a mldsa-sign-bench JSON testset '
                              'instead of generating them randomly.'))
    parser.add_argument('--index',
                        type=int,
                        default=0,
                        help=('Index of the vector within the testset.'))
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
    if args.params not in INSTANCE_FOR_PARAMS:
        raise ValueError(f'Invalid parameters: {args.params}. Expected one of '
                         f'{", ".join(INSTANCE_FOR_PARAMS.keys())}')
    mldsa = INSTANCE_FOR_PARAMS[args.params]
    # dilithium_py binds random_bytes to os.urandom at instance creation;
    # redirect to seeded random so sk is reproducible across testgen runs.
    if args.seed is not None:
        mldsa.random_bytes = lambda n: random.randbytes(n)
    ell, k, eta = L_K_ETA[args.params]
    vector = None
    if args.from_vector is not None:
        vector = json.load(open(args.from_vector))[args.index]
    gen_sign_test(mldsa, ell, k, eta, args.nshares, args.data, args.exp, args.dexp, vector=vector)
