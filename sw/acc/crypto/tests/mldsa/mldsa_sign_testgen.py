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

MIN_MSG_LEN = 0
MAX_MSG_LEN = 3072

MIN_CTX_LEN = 0
MAX_CTX_LEN = 255


def gen_sign_test(mldsa, data_file: TextIO, exp_file: TextIO, dexp_file: TextIO, vector=None):
    if vector is not None:
        # Curated bench vector (empty context, as produced by mldsa-sign-bench).
        sk = bytes.fromhex(vector['sk'])
        rnd = bytes.fromhex(vector['rnd'])
        msg = bytes.fromhex(vector['msg'])
        ctx = b''
        ctxlen = 0
        sig = bytes.fromhex(vector['sig'])
    else:
        # Generate a random key pair.
        pk, sk = mldsa.keygen()

        # Generate a random message and context.
        msglen = random.randrange(MIN_MSG_LEN, MAX_MSG_LEN + 1)
        ctxlen = random.randrange(MIN_CTX_LEN, MAX_CTX_LEN + 1)
        msg = random.randbytes(msglen)
        ctx = random.randbytes(ctxlen)

        # Sign the message using deterministic signing.
        rnd = bytes([0] * 32)
        sig = mldsa.sign(sk, msg, ctx=ctx, deterministic=True)

    # External-mu mode: caller pre-hashes message+context.  mu = SHAKE256
    # (tr || 0x00 || byte(ctxlen) || ctx || msg, 64).
    tr = sk[64:128]
    shake = hashlib.shake_256()
    shake.update(tr)
    shake.update(bytes([0x00, ctxlen]))
    shake.update(ctx)
    shake.update(msg)
    mu = shake.digest(64)

    # Write input values.
    data = {
        'mu': mu,
        'sk': sk,
        'rnd': rnd,
    }
    write_test_data(data, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'sig': sig}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
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
    vector = None
    if args.from_vector is not None:
        vector = json.load(open(args.from_vector))[args.index]
    gen_sign_test(mldsa, args.data, args.exp, args.dexp, vector=vector)
