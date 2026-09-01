#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

Q = 3329
N = 256  # number of output coefficients
# Largest multiple of Q below 2**16; a batch is rejected if any of its 16
# candidates is >= LIMIT.
LIMIT = 19 * Q


def gen_poly_rej_samp_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate the random input words consumed by the gadget under
    # MLKEM_REJ_SAMPLE_TEST, mirroring its batch rejection.
    if seed is not None:
        random.seed(seed)

    rand_in = bytes()
    coeffs = []
    while len(coeffs) < N:
        # One 256-bit word holds 16 candidate coefficients of 16 bits each.
        word = [random.getrandbits(16) for _ in range(16)]
        for c in word:
            rand_in += int.to_bytes(c, byteorder="little", length=2)
        # The gadget accepts the whole word only if every candidate < 19*q,
        # then reduces each accepted candidate mod q.
        if all(c < LIMIT for c in word):
            coeffs += [c % Q for c in word]

    r_bytes = bytes()
    for c in coeffs:
        r_bytes += int.to_bytes(c, byteorder="little", length=2)

    # Write input values (output buffer zero-initialized).
    inputs = {
        'rand_in': rand_in,
        'r': int.to_bytes(0, byteorder="little", length=2 * N)
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
        gen_poly_rej_samp_test(args.seed, args.data, args.exp, args.dexp)
