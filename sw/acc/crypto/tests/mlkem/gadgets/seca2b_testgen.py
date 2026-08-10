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


def gen_seca2b_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    nshares = NSHARES
    k = 16

    operand_nbytes = 32 * nshares * k

    m = (1 << k) - 1
    v = [0] * N
    x = [0] * nshares
    for i in range(nshares):
        x[i] = [random.randint(0, m) for _ in range(N)]
        for j in range(N):
            v[j] = (v[j] + x[i][j]) & m

    # Bitslicing v.
    r = [0] * k
    for i in range(N):
        for j in range(k):
            r[j] |= (((v[i] >> j) & 1) << i)

    r_bytes = bytes()
    for i in range(k):
        t = int.to_bytes(r[i], byteorder="little", length=32)
        r_bytes += t

    # Bitslicing x.
    x_bytes = bytes()
    for s in range(nshares):
        t = [0] * k
        for i in range(N):
            for j in range(k):
                t[j] |= (((x[s][i] >> j) & 1) << i)
        for i in range(k):
            ti = int.to_bytes(t[i], byteorder="little", length=32)
            x_bytes += ti

    rb_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)

    # Write input values.
    inputs = {'xa': x_bytes, 'rb': rb_bytes}
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
        gen_seca2b_test(args.seed, args.data, args.exp, args.dexp)
