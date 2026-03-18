#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO
from kyber_py.ml_kem import ML_KEM_512, ML_KEM_768, ML_KEM_1024

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

DEBUG = 1
INSTANCE_FOR_PARAMS = {
    'mlkem512': ML_KEM_512,
    'mlkem768': ML_KEM_768,
    'mlkem1024': ML_KEM_1024,
}


def gen_keypair_test(mlkem, nshares: int, data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if DEBUG:
        d = random.randbytes(32)
        z = random.randbytes(32)
        ek, dk = mlkem._keygen_internal(d, z)
        coins = d + z
    else:
        # Generate a random seed and expected keys.
        coins = random.randbytes(64)
        ek, dk = mlkem.key_derive(coins)

    if nshares is None:
        nshares = 2

    if nshares == 2:
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

    # Write input values.
    write_test_data({'coins': coins}, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'ek': ek, 'dk': dk}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
    parser.add_argument('-n', '--nshares',
                        type=int,
                        required=False,
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
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
    if args.params not in INSTANCE_FOR_PARAMS:
        raise ValueError(f'Invalid parameters: {args.params}. Expected one of '
                         f'{", ".join(INSTANCE_FOR_PARAMS.keys())}')
    mlkem = INSTANCE_FOR_PARAMS[args.params]
    gen_keypair_test(mlkem, args.nshares, args.data, args.exp, args.dexp)
