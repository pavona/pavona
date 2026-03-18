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


def gen_secb2amodq_spog19_test(
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
        # k = random.randint(12, BITSIZE)
        k = BITSIZE
    else:
        N_WDR = 32
        BITSIZE = 32
        Q = 8380417
        k = random.randint(23, BITSIZE)

    operand_nbytes = 32 * N_WDR * n

    x = 0
    xb_bytes = bytes()
    m = (1 << k) - 1
    for _ in range(n):
        t = [random.randint(0, m) for _ in range(N)]
        t = sum(t[j] << (j * BITSIZE) for j in range(N))
        x ^= t
        t_bytes = int.to_bytes(t, byteorder="little", length=32 * N_WDR)
        xb_bytes += t_bytes

    x = [((x >> (i * BITSIZE)) & ((1 << BITSIZE) - 1)) % Q for i in range(N)]
    x = sum(x[i] << (i * BITSIZE) for i in range(N))
    exp_bytes = int.to_bytes(x, byteorder='little', length=32 * N_WDR)
    ra_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)

    # Write input values.
    inputs = {'xb': xb_bytes, 'ra': ra_bytes}
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

    gen_secb2amodq_spog19_test(args.seed, args.scheme, args.nshares, args.data, args.exp, args.dexp)
