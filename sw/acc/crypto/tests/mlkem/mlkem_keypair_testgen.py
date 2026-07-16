#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO
from kyber_py.ml_kem import ML_KEM_512, ML_KEM_768, ML_KEM_1024

from shared.testgen import write_testcase

INSTANCE_FOR_PARAMS = {
    'mlkem512': ML_KEM_512,
    'mlkem768': ML_KEM_768,
    'mlkem1024': ML_KEM_1024,
}


def gen_keypair_test(mlkem, hardened: bool, mode_symbol: str, tc_file: TextIO):
    # Generate a random seed and expected keys.
    coins = random.randbytes(64)
    ek, dk = mlkem.key_derive(coins)

    if hardened:
        # Generate shares for d.
        d_int = int.from_bytes(coins[0:32], byteorder="little")
        r1 = random.getrandbits(256)
        r2 = r1 ^ d_int
        td = int.to_bytes(r1, byteorder="little", length=32)
        td += int.to_bytes(r2, byteorder="little", length=32)
        # Generate shares for z.
        z_int = int.from_bytes(coins[32:], byteorder="little")
        r1 = random.getrandbits(256)
        r2 = r1 ^ z_int
        tz = int.to_bytes(r1, byteorder="little", length=32)
        tz += int.to_bytes(r2, byteorder="little", length=32)
        coins = td + tz
        dk = dk[:-32] + tz

    # Unprotected keygen runs run_mlkem (dispatched by mode); the masked wrapper
    # calls the kernel directly, unmasks dk, and has no MODE_* symbol.
    inputs = {'coins': coins}
    if not hardened:
        inputs['mode'] = mode_symbol
    write_testcase(tc_file, inputs, outputs={'ek': ek, 'dk': dk})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
    parser.add_argument('--hardened',
                        action='store_true',
                        help=('Generate masked (2-share) test data.'))
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
    mlkem = INSTANCE_FOR_PARAMS[args.params]
    mode_symbol = 'MODE_KEYGEN_' + args.params.removeprefix('mlkem')
    with args.testcase:
        gen_keypair_test(mlkem, args.hardened, mode_symbol, args.testcase)
