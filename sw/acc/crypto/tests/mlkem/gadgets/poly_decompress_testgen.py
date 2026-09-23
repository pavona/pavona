#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from kyber_py.polynomials.polynomials import PolynomialRingKyber
from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
R = PolynomialRingKyber()


def gen_poly_decompress_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    # Every d-bit value appears in each input, in random order.
    x4 = [i % 16 for i in range(N)]
    x5 = [i % 32 for i in range(N)]
    random.shuffle(x4)
    random.shuffle(x5)

    c4 = R(x4).encode(4)
    c5 = R(x5).encode(5)
    write_test_data({'x_dv4': c4, 'x_dv5': c5}, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'r_dv4': R.decode(c4, 4).decompress(4).encode(16),
                     'r_dv5': R.decode(c5, 5).decompress(5).encode(16)},
                    dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False,
                        help='Seed value for pseudorandomness.')
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'),
                        help='Output file for input DMEM values.')
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'),
                        help='Output file for expected register values.')
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'),
                        help='Output file for expected DMEM values.')
    args = parser.parse_args()

    with args.data, args.exp, args.dexp:
        gen_poly_decompress_test(args.seed, args.data, args.exp, args.dexp)
