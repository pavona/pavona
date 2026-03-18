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


def gen_seconebitb2a_spog19_mlkem_test(
        seed: Optional[int], scheme: Optional[int], nshares: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    if nshares is None:
        nshares = NSHARES

    operand_nbytes = 32 * N_WDR * nshares

    # Generate input.
    r = 0
    x_bytes = bytes()
    for _ in range(nshares):
        t = [random.randint(0, 1) for _ in range(N)]
        t_int = sum(t[j] << (j * 16) for j in range(N))
        r ^= t_int
        x_bytes += int.to_bytes(t_int, byteorder="little", length=512)

    # Generate expected result.
    r_bytes = int.to_bytes(r, byteorder='little', length=512)

    ra_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)

    # Write input values.
    inputs = {'xb': x_bytes, 'ra': ra_bytes}
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

    gen_seconebitb2a_spog19_mlkem_test(
        args.seed, args.scheme, args.nshares, args.data, args.exp, args.dexp)
