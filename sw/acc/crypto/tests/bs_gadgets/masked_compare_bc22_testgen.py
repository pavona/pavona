#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
NSHARES = 2
N_WDR = 16


def compress(x: int, d: int, q: int) -> int:
    """Compression and subsequent serialization of a polynomial."""
    r = ((x << d) + q // 2) // q
    r &= ((1 << d) - 1)
    return r


def gen_masked_compare_bc22_testgen(
        seed: Optional[int], scheme: Optional[int], nshares: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    if nshares is None:
        nshares = NSHARES

    q = 3329
    if scheme == 4:
        ksec = 4
        du = 11
        dv = 5
        polycompressed_bytes = 160
        poly_polyveccompressed_bytes = 352
    elif scheme == 3:
        ksec = 3
        du = 10
        dv = 4
        polycompressed_bytes = 128
        poly_polyveccompressed_bytes = 320
    else:
        ksec = 2
        du = 10
        dv = 4
        polycompressed_bytes = 128
        poly_polyveccompressed_bytes = 320

    # Compress to v.
    r = [0] * N
    x = [0] * nshares
    xv_bytes = bytes()
    for i in range(nshares):
        x[i] = [random.randint(0, q - 1) for _ in range(N)]
        r = [(r[j] + x[i][j]) % q for j in range(N)]
        tmp = sum(x[i][j] << (j * 16) for j in range(N))
        tmp = int.to_bytes(tmp, byteorder="little", length=512)
        xv_bytes += tmp

    rv = [0] * N
    for i in range(N):
        rv[i] = compress(r[i], dv, q)
    rv = sum(rv[i] << (i * dv) for i in range(N))
    cv_bytes = int.to_bytes(rv, byteorder="little", length=polycompressed_bytes)

    # Compress to u.
    xu_bytes = bytes()
    cu_bytes = bytes()
    for _ in range(ksec):
        r = [0] * N
        x = [0] * nshares
        for i in range(nshares):
            x[i] = [random.randint(0, q - 1) for _ in range(N)]
            r = [(r[j] + x[i][j]) % q for j in range(N)]
            tmp = sum(x[i][j] << (j * 16) for j in range(N))
            tmp = int.to_bytes(tmp, byteorder="little", length=512)
            xu_bytes += tmp

        ru = [0] * N
        for i in range(N):
            ru[i] = compress(r[i], du, q)
        ru = sum(ru[i] << (i * du) for i in range(N))
        cu_bytes += int.to_bytes(ru, byteorder="little", length=poly_polyveccompressed_bytes)

    # Generate expected result.
    exp_bytes = int.to_bytes(1, byteorder="little", length=32)

    # Write input values.
    inputs = {
        'xv': xv_bytes, 'xu': xu_bytes, 'cv': cv_bytes, 'cu': cu_bytes
    }
    write_test_data(inputs, data_file)

    # Write expected register values.
    write_test_exp({'w0': exp_bytes}, exp_file)

    # Write expected dmem values (none).
    write_test_dexp({}, dexp_file)


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
    parser.add_argument('--scheme',
                        type=int,
                        required=False,
                        default=0,
                        help=('False: ML-KEM. True: ML-DSA.'))
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

    gen_masked_compare_bc22_testgen(
        args.seed, args.scheme, args.nshares, args.data, args.exp, args.dexp)
