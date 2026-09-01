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


def gen_seconebitb2amodq_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    # Generate inputs.
    x = [0] * N
    r = [0] * N
    x_bytes = bytes()
    for _ in range(NSHARES):
        for coeff in range(N):
            x[coeff] = random.randint(0, 1)
            r[coeff] ^= x[coeff]
        x_int = sum(x[coeff] << (coeff * 16) for coeff in range(N))
        x_bytes += int.to_bytes(x_int, byteorder="little", length=512)

    # Generate expected result.
    r_int = sum(r[coeff] << (coeff * 16) for coeff in range(N))
    r_bytes = int.to_bytes(r_int, byteorder='little', length=512)

    # Write input values.
    inputs = {
        'xb': x_bytes,
        'ra': int.to_bytes(0, byteorder='little', length=512 * NSHARES)
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

    with args.data, args.exp, args.dexp:
        gen_seconebitb2amodq_test(args.seed, args.data, args.exp, args.dexp)
