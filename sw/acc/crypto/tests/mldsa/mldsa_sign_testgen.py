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
from Crypto.PublicKey import MLDSA
from Crypto.Signature import mldsa

from shared.testgen import write_testcase

INSTANCE_FOR_PARAMS = {
    'mldsa44': MLDSA.ML_DSA_44,
    'mldsa65': MLDSA.ML_DSA_65,
    'mldsa87': MLDSA.ML_DSA_87,
}

MIN_MSG_LEN = 0
MAX_MSG_LEN = 3072

MIN_CTX_LEN = 0
MAX_CTX_LEN = 255


def gen_sign_test(param_set, mode_symbol: str, tc_file: TextIO, vector=None):
    if vector is not None:
        # Curated bench vector (empty context, as produced by mldsa-sign-bench).
        sk = bytes.fromhex(vector['sk'])
        rnd = bytes.fromhex(vector['rnd'])
        msg = bytes.fromhex(vector['msg'])
        ctx = b''
        sig = bytes.fromhex(vector['sig'])
    else:
        # Generate a random key pair.
        key = MLDSA.generate(param_set=param_set, randfunc=random.randbytes)
        sk = key.sk

        # Generate a random message and context.
        msglen = random.randrange(MIN_MSG_LEN, MAX_MSG_LEN + 1)
        ctxlen = random.randrange(MIN_CTX_LEN, MAX_CTX_LEN + 1)
        msg = random.randbytes(msglen)
        ctx = random.randbytes(ctxlen)

        # Sign the message using deterministic signing.
        rnd = bytes([0] * 32)
        sig = mldsa.new(key, ctx, deterministic=True).sign(msg)

    # External mu: tr = sk[64:128]; the kernel signs from this mu.
    tr = sk[64:128]
    mu = hashlib.shake_256(tr + bytes([0, len(ctx)]) + ctx + msg).digest(64)

    inputs = {'mode': mode_symbol, 'sk': sk, 'rnd': rnd, 'mu': mu}
    outputs = {'sig': sig + bytes((-len(sig)) % 4)}
    write_testcase(tc_file, inputs, outputs)


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
    parser.add_argument('--from-vector',
                        dest='from_vector',
                        help=('Load sk/rnd/msg/sig from a mldsa-sign-bench '
                              'testset JSON instead of generating randomly.'))
    parser.add_argument('--index',
                        type=int,
                        default=0,
                        help=('Index of the vector within the testset.'))
    parser.add_argument('testcase',
                        metavar='FILE',
                        type=argparse.FileType('w'),
                        help=('Output file for the accsim testcase (hjson).'))
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
    if args.params not in INSTANCE_FOR_PARAMS:
        raise ValueError(f'Invalid parameters: {args.params}. Expected one of '
                         f'{", ".join(INSTANCE_FOR_PARAMS.keys())}')
    param_set = INSTANCE_FOR_PARAMS[args.params]
    vector = None
    if args.from_vector is not None:
        vector = json.load(open(args.from_vector))[args.index]
    # run_mldsa dispatches on this mode symbol (e.g. mldsa44 -> MODE_SIGN_44).
    mode_symbol = 'MODE_SIGN_' + args.params.removeprefix('mldsa')
    with args.testcase:
        gen_sign_test(param_set, mode_symbol, args.testcase, vector=vector)
