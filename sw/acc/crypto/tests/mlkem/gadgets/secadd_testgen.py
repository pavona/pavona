#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
NSHARES = 2


def gen_secadd_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    k = 16
    nshares = NSHARES

    operand_nbytes = 32 * nshares * k

    x = [0] * k
    y = [0] * k
    xb = bytes()
    yb = bytes()
    for _ in range(nshares):
        for i in range(k):
            tx = random.getrandbits(N)
            ty = random.getrandbits(N)
            x[i] ^= tx
            y[i] ^= ty
            tx = int.to_bytes(tx, byteorder="little", length=32)
            ty = int.to_bytes(ty, byteorder="little", length=32)
            xb += tx
            yb += ty

    r = [0] * k
    for i in range(N):
        xi = 0
        yi = 0
        for j in range(k):
            xi |= (((x[j] >> i) & 1) << j)
            yi |= (((y[j] >> i) & 1) << j)
        ri = (xi + yi) & ((1 << k) - 1)
        for j in range(k):
            r[j] |= (((ri >> j) & 1) << i)

    r_bytes = bytes()
    for i in range(k):
        t = int.to_bytes(r[i], byteorder="little", length=32)
        r_bytes += t

    rb_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)

    # Write input values.
    inputs = {'xb': xb, 'yb': yb, 'rb': rb_bytes}
    write_test_data(inputs, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'r': r_bytes}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
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

    with args.data, args.exp, args.dexp:
        gen_secadd_test(args.seed, args.data, args.exp, args.dexp)
