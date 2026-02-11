#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
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

MIN_MSG_LEN = 0
MAX_MSG_LEN = 3072

MIN_CTX_LEN = 0
MAX_CTX_LEN = 255


def gen_verify_test(mldsa, data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate a random key pair.
    pk, sk = mldsa.keygen()

    # Generate a random message and context.
    msglen = random.randrange(MIN_MSG_LEN, MAX_MSG_LEN + 1)
    ctxlen = random.randrange(MIN_CTX_LEN, MAX_CTX_LEN + 1)
    msg = random.randbytes(msglen)
    ctx = random.randbytes(ctxlen)

    # Sign the message.
    sig = mldsa.sign(sk, msg, ctx=ctx)

    # Accomodate alignment hack for ML-DSA-65.
    if mldsa == ML_DSA_65:
        sig = bytes([0] * 16) + sig

    # Ensure ctx and message end up 32-byte aligned
    if ctxlen <= 4:
        ctx += bytes([0] * (5 - ctxlen))
    if msglen <= 4:
        msg += bytes([0] * (5 - msglen))

    # Write input values.
    data = {
        'ctxlen': int.to_bytes(ctxlen, length=4, byteorder='little'),
        'msglen': int.to_bytes(msglen, length=4, byteorder='little'),
        'ctx': ctx,
        'msg': msg,
        'sig': sig,
        'pk': pk,
    }
    write_test_data(data, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'result': bytes([0] * 32)}, dexp_file)


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
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
    if args.params not in INSTANCE_FOR_PARAMS:
        raise ValueError(f'Invalid parameters: {args.params}. Expected one of '
                         f'{", ".join(INSTANCE_FOR_PARAMS.keys())}')
    mldsa = INSTANCE_FOR_PARAMS[args.params]
    gen_verify_test(mldsa, args.data, args.exp, args.dexp)
