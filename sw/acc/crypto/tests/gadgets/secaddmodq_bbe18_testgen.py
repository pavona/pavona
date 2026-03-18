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


def gen_secaddmodq_bbe18_test(
        seed: Optional[int], scheme: Optional[int], nshares: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    if nshares is not None:
        n = nshares
    else:
        n = NSHARES

    if scheme == 0:
        N_WDR = 16
        BITSIZE = 16
        Q = 3329
    else:
        N_WDR = 32
        BITSIZE = 32
        Q = 8380417

    operand_nbytes = 32 * N_WDR * n

    x = 0
    y = 0
    exp = 0
    for i in range(N):
        tx = random.randint(0, Q - 1)
        ty = random.randint(0, Q - 1)
        x |= (tx << (i * BITSIZE))
        y |= (ty << (i * BITSIZE))
        t = tx + ty
        if t >= Q:
            t -= Q
        exp |= (t << (i * BITSIZE))

    x_last = x
    y_last = y
    xb = 0
    yb = 0
    for i in range(n - 1):
        tx = random.getrandbits(N * N_WDR)
        ty = random.getrandbits(N * N_WDR)
        xb |= (tx << (i * N * N_WDR))
        yb |= (ty << (i * N * N_WDR))
        x_last ^= tx
        y_last ^= ty
    xb |= (x_last << ((n - 1) * N * N_WDR))
    yb |= (y_last << ((n - 1) * N * N_WDR))

    xb_bytes = int.to_bytes(xb, byteorder='little', length=operand_nbytes)
    yb_bytes = int.to_bytes(yb, byteorder='little', length=operand_nbytes)
    exp_bytes = int.to_bytes(exp, byteorder='little', length=32 * N_WDR)
    rb_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)

    # Write input values.
    inputs = {'xb': xb_bytes, 'yb': yb_bytes, 'rb': rb_bytes}
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

    gen_secaddmodq_bbe18_test(args.seed, args.scheme, args.nshares, args.data, args.exp, args.dexp)
