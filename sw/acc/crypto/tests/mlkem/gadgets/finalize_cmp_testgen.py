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


def gen_finalize_cmp_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    # Even seeds all-match (-> 1), odd seeds random (-> 0).
    if seed is not None and seed % 2 == 0:
        v = (1 << N) - 1
    else:
        v = random.getrandbits(N)
    expected = 1 if v == (1 << N) - 1 else 0

    # Boolean shares of v.
    share0 = random.getrandbits(N)
    x = (int.to_bytes(share0, byteorder="little", length=32)
         + int.to_bytes(v ^ share0, byteorder="little", length=32))

    # Write input values.
    write_test_data({'x': x}, data_file)

    # Write expected register values.
    write_test_exp({'w0': int.to_bytes(expected, byteorder="little",
                                       length=32)}, exp_file)

    # Write expected dmem values (none).
    write_test_dexp({}, dexp_file)


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
        gen_finalize_cmp_test(args.seed, args.data, args.exp, args.dexp)
