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

Q = 3329
N = 256


def gen_decaps_test(mlkem, nshares: int, data_file: TextIO, exp_file: TextIO,
                    dexp_file: TextIO, invalid=False):
    if DEBUG:
        d = random.randbytes(32)
        z = random.randbytes(32)
        m = random.randbytes(32)
        # Generate a random key pair.
        ek, dk = mlkem._keygen_internal(d, z)
        # Encapsulate a shared secret.
        ss, ct = mlkem._encaps_internal(ek, m)
    else:
        # Generate a random key pair.
        ek, dk = mlkem.keygen()
        # Encapsulate a shared secret.
        ss, ct = mlkem.encaps(ek)

    if invalid:
        # Pick a random index in the ciphertext and modify a random byte.
        idx = random.randrange(len(ct))
        ct = ct[:idx] + bytes([ct[idx] ^ 1]) + ct[idx + 1:]

    # Decapsulate (if invalid, output is garbage as specified by FIPS 203).
    ss = mlkem.decaps(dk, ct)

    # Generate arithmetic shares for dk.
    if nshares is None:
        nshares = 2

    if nshares == 1:
        # Write input values.
        write_test_data({'ct': ct, 'dk': dk}, data_file)
    else:
        skpv = []
        dk_int = int.from_bytes(dk[0:384 * mlkem.k], byteorder="little")
        for k in range(mlkem.k):
            tv = []
            for i in range(N):
                t = dk_int & 0xFFF
                dk_int >>= 12
                tv.append(t)
            skpv.append(tv)

        dk_bytes = 0
        for k in range(mlkem.k):
            sk = skpv[k].copy()
            sk_bytes = 0
            for i in range(nshares - 1):
                t = [random.randint(0, Q - 1) for _ in range(N)]
                sk = [(sk[j] - t[j]) % Q for j in range(N)]
                t = sum(t[j] << (j * 12) for j in range(N))
                sk_bytes |= (t << (i * N * 12))
            sk_int = sum(sk[j] << (j * 12) for j in range(N))
            sk_bytes |= (sk_int << ((nshares - 1) * N * 12))
            dk_bytes |= (sk_bytes << (k * N * 12 * nshares))

        dk_bytes = int.to_bytes(dk_bytes, byteorder='little', length=384 * nshares * mlkem.k)

        if nshares == 2:
            dk_bytes += dk[mlkem.k * 384:-32]
            # Mask z.
            z_int = int.from_bytes(dk[-32:], byteorder='little')
            r1 = random.getrandbits(256)
            r2 = r1 ^ z_int
            tz = int.to_bytes(r1, byteorder='little', length=32)
            tz += int.to_bytes(r2, byteorder='little', length=32)
            dk_bytes += tz
            # Write input values.
            write_test_data({'ct': ct, 'dk': dk_bytes}, data_file)
        else:
            dk_bytes += dk[mlkem.k * 384:]

            # Write input values.
            write_test_data({'ct': ct, 'dk': dk_bytes}, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'ss': ss}, dexp_file)


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
    parser.add_argument('-i', '--invalid',
                        action='store_true',
                        help=('Set in order to make the decapsulation input invalid.'))
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
    gen_decaps_test(mlkem, args.nshares, args.data, args.exp, args.dexp, args.invalid)
