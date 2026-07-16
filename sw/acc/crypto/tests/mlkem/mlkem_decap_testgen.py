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

Q = 3329
N = 256


def gen_decaps_test(mlkem, hardened: bool, mode_symbol: str, tc_file: TextIO,
                    invalid=False):
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
    if not hardened:
        dk_input = dk
    else:
        nshares = 2
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

        dk_bytes += dk[mlkem.k * 384:-32]
        # Mask z.
        z_int = int.from_bytes(dk[-32:], byteorder='little')
        r1 = random.getrandbits(256)
        r2 = r1 ^ z_int
        tz = int.to_bytes(r1, byteorder='little', length=32)
        tz += int.to_bytes(r2, byteorder='little', length=32)
        dk_bytes += tz
        dk_input = dk_bytes

    # Unprotected decap runs run_mlkem (dispatched by mode); the masked wrapper
    # calls the kernel directly and has no MODE_* symbol.
    inputs = {'ct': ct, 'dk': dk_input}
    if not hardened:
        inputs['mode'] = mode_symbol
    write_testcase(tc_file, inputs, outputs={'ss': ss})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
    parser.add_argument('--hardened',
                        action='store_true',
                        help=('Generate masked (2-share) test data.'))
    parser.add_argument('-i', '--invalid',
                        action='store_true',
                        help=('Set in order to make the decapsulation input invalid.'))
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
    # Draw the key pair and the encapsulation coins from the seeded generator so
    # the test data is deterministic.
    mlkem.random_bytes = random.randbytes
    mode_symbol = 'MODE_DECAP_' + args.params.removeprefix('mlkem')
    with args.testcase:
        gen_decaps_test(mlkem, args.hardened, mode_symbol, args.testcase, args.invalid)
