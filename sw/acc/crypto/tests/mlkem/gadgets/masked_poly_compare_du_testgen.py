#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional, List, Tuple

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
NSHARES = 2
Q = 3329


def compress_poly(coeffs: List[int], d: int) -> bytes:
    """Compress and serialize a polynomial to d bits per coefficient."""
    packed = 0
    for i in range(N):
        c = (((coeffs[i] << d) + Q // 2) // Q) & ((1 << d) - 1)
        packed |= c << (i * d)
    return int.to_bytes(packed, byteorder="little", length=32 * d)


def random_shared_poly() -> Tuple[bytes, List[int]]:
    """Return NSHARES random arithmetic shares (packed) and their sum mod Q."""
    s = [0] * N
    r = [0] * N
    shares = bytes()
    for _ in range(NSHARES):
        for coeff in range(N):
            s[coeff] = random.randint(0, Q - 1)
            r[coeff] = (r[coeff] + s[coeff]) % Q
        s_int = sum(s[coeff] << (coeff * 16) for coeff in range(N))
        shares += int.to_bytes(s_int, byteorder="little", length=512)
    return shares, r


def gen_masked_poly_compare_du_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO, invalid=False):
    if seed is not None:
        random.seed(seed)

    # One polynomial compared against its compression at du = 10 (k != 4) and
    # du = 11 (k = 4). Both match, so the recombined output is all ones.
    xu, ru = random_shared_poly()
    r = (1 << N) - 1

    # Generate the packed reference ciphertext.
    cu_du10_bytes = compress_poly(ru, 10)
    cu_du11_bytes = compress_poly(ru, 11)

    if invalid:
        # Pick a random index in the ciphertext and modify a random bytes.
        idx = random.randrange(320)
        cu_du10_bytes = cu_du10_bytes[:idx] + bytes(cu_du10_bytes[idx] ^ 1) + \
            cu_du10_bytes[idx + 1:]
        idx = random.randrange(352)
        cu_du11_bytes = cu_du11_bytes[:idx] + bytes(cu_du11_bytes[idx] ^ 1) + \
            cu_du11_bytes[idx + 1:]
        # Since the reference ciphertext is changed, the comparison does not
        # match. So the recombined output is not all ones.
        r = 0

    # Write input values.
    write_test_data({'xu': xu,
                     'cu_du10': cu_du10_bytes,
                     'cu_du11': cu_du11_bytes}, data_file)

    # Write expected register values.
    write_test_exp({'w0': int.to_bytes(r, byteorder="little",
                                       length=32)}, exp_file)

    # Write expected dmem values (none).
    write_test_dexp({}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
    parser.add_argument('-i', '--invalid',
                        action='store_true',
                        help=('Set in order to make the decapsulation input invalid.'))
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
        gen_masked_poly_compare_du_test(args.seed, args.data, args.exp,
                                        args.dexp, args.invalid)
