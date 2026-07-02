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


def gen_secfulladder_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    nshares = NSHARES
    operand_nbytes = 32 * nshares

    x = 0
    y = 0
    c = 0
    xb = 0
    yb = 0
    cb = 0
    for i in range(nshares):
        tx = random.getrandbits(N)
        ty = random.getrandbits(N)
        tc = random.getrandbits(N)
        x ^= tx
        y ^= ty
        c ^= tc
        xb |= (tx << (i * N))
        yb |= (ty << (i * N))
        cb |= (tc << (i * N))

    # Compute expected result x + y + c.
    w0 = 0
    w1 = 0
    for i in range(N):
        xi = (x >> i) & 1
        yi = (y >> i) & 1
        ci = (c >> i) & 1
        t = xi + yi + ci
        w0 |= ((t & 1) << i)
        w1 |= (((t >> 1) & 1) << i)
    w = w0 | (w1 << N)

    xb_bytes = int.to_bytes(xb, byteorder='little', length=operand_nbytes)
    yb_bytes = int.to_bytes(yb, byteorder='little', length=operand_nbytes)
    cb_bytes = int.to_bytes(cb, byteorder='little', length=operand_nbytes)
    r_bytes = int.to_bytes(w, byteorder='little', length=64)
    rb_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)
    coutb_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)

    # Write input values.
    inputs = {
        'xb': xb_bytes, 'yb': yb_bytes, 'cb': cb_bytes,
        'rb': rb_bytes, 'coutb': coutb_bytes
    }
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

    gen_secfulladder_test(args.seed, args.data, args.exp, args.dexp)
