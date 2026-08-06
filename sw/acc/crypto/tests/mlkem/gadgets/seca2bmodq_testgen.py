#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional, List

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
NSHARES = 2


def bitslice(x: List[int], k: int) -> List[int]:
    r = [0] * k
    for i in range(N):
        for j in range(k):
            bit = (x[i] >> j) & 1
            r[j] |= (bit << i)
    return r


def gen_seca2bmodq_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    nshares = NSHARES
    q = 3329
    k = 12
    operand_nbytes = 32 * nshares * k

    t = [0] * nshares
    x = [random.randint(0, q - 1) for _ in range(N)]
    rx = x.copy()
    x_bytes = bytes()
    for i in range(nshares - 1):
        t[i] = [random.randint(0, q - 1) for _ in range(N)]
        rx = [(rx[j] - t[i][j]) % q for j in range(N)]
        tmp = bitslice(t[i], k)
        for j in range(k):
            x_bytes += int.to_bytes(tmp[j], byteorder="little", length=32)
    tmp = bitslice(rx, k)
    for j in range(k):
        x_bytes += int.to_bytes(tmp[j], byteorder="little", length=32)

    # Generate expected result.
    r = bitslice(x, k)
    r_bytes = bytes()
    for i in range(k):
        r_bytes += int.to_bytes(r[i], byteorder="little", length=32)

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
        gen_seca2bmodq_test(args.seed, args.data, args.exp, args.dexp)
