#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import hashlib
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


def gen_verify_test(param_set, mode_symbol: str, tc_file: TextIO):
    # Generate a random key pair.
    key = MLDSA.generate(param_set=param_set, randfunc=random.randbytes)
    pk = key.pk

    # Generate a random message and context.
    msglen = random.randrange(MIN_MSG_LEN, MAX_MSG_LEN + 1)
    ctxlen = random.randrange(MIN_CTX_LEN, MAX_CTX_LEN + 1)
    msg = random.randbytes(msglen)
    ctx = random.randbytes(ctxlen)

    # Sign the message.
    sig = mldsa.new(key, ctx, randfunc=random.randbytes).sign(msg)

    # External mu: tr = SHAKE256(pk); the kernel verifies against this mu.
    tr = hashlib.shake_256(pk).digest(64)
    mu = hashlib.shake_256(tr + bytes([0, ctxlen]) + ctx + msg).digest(64)

    # result starts at a sentinel so a skipped write is caught, and must be
    # HARDENED_BOOL_TRUE (0x739) after a valid verification.
    inputs = {
        'mode': mode_symbol,
        'result': (1).to_bytes(4, 'little'),
        'sig': sig,
        'pk': pk,
        'mu': mu,
    }
    outputs = {'result': (0x739).to_bytes(4, 'little')}
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
    # run_mldsa dispatches on this mode symbol (e.g. mldsa44 -> MODE_VERIFY_44).
    mode_symbol = 'MODE_VERIFY_' + args.params.removeprefix('mldsa')
    with args.testcase:
        gen_verify_test(param_set, mode_symbol, args.testcase)
