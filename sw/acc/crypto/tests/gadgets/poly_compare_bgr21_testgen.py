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


def gen_poly_compare_bgr21_testgen(
        seed: Optional[int], scheme: Optional[int], nshares: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    if nshares is not None:
        n = nshares
    else:
        n = NSHARES

    N_WDR = 16
    BITSIZE = 16
    Q = 3329
    if scheme == 4:
        DV = 5
        DU = 11
        POLYCOMPRESSEDBYTES = 160
        POLYVECCOMPRESSEDBYTES = 352
    elif scheme == 3:
        DV = 4
        DU = 10
        POLYCOMPRESSEDBYTES = 128
        POLYVECCOMPRESSEDBYTES = 320
    else:
        DV = 4
        DU = 10
        POLYCOMPRESSEDBYTES = 128
        POLYVECCOMPRESSEDBYTES = 320

    operand_nbytes = 32 * N_WDR * n

    x = [random.randint(0, Q - 1) for _ in range(N)]
    xcp = x.copy()
    ca = 0
    exp = sum(x[i] << (i * BITSIZE) for i in range(N))
    for i in range(n - 1):
        t = [random.randint(0, Q - 1) for _ in range(N)]
        x = [(x[j] - t[j]) % Q for j in range(N)]
        t = sum(t[j] << (j * BITSIZE) for j in range(N))
        ca |= (t << (i * N * N_WDR))
    x = sum(x[i] << (i * BITSIZE) for i in range(N))
    ca |= (x << ((nshares - 1) * N * N_WDR))

    # Compress to v.
    cv = 0
    for i in range(N - 1, -1, -1):
        t = ((xcp[i] << DV) + Q // 2) // Q
        cv = (cv << DV) | (t & ((1 << DV) - 1))
    cv = cv.to_bytes(POLYCOMPRESSEDBYTES, byteorder="little")

    # Compress to u.
    cu = 0
    for i in range(N - 1, -1, -1):
        t = ((xcp[i] << DU) + Q // 2) // Q
        cu = (cu << DU) | (t & ((1 << DU) - 1))
    cu = cu.to_bytes(POLYVECCOMPRESSEDBYTES, byteorder="little")

    m = (1 << N) - 1
    exp = 0
    for i in range(4):
        exp |= (m << (i * N))
    ca_bytes = int.to_bytes(ca, byteorder='little', length=operand_nbytes)
    exp_bytes = int.to_bytes(exp, byteorder='little', length=128)

    # Write input values.
    inputs = {'ca': ca_bytes, 'cv': cv, 'cu': cu}
    write_test_data(inputs, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'r': exp_bytes}, dexp_file)


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

    gen_poly_compare_bgr21_testgen(
        args.seed, args.scheme, args.nshares, args.data, args.exp, args.dexp)
