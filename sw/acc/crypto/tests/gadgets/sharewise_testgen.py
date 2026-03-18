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


def gen_sharewise_test(
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
        MSB_SHIFT = 11
    else:
        N_WDR = 32
        BITSIZE = 32
        MSB_SHIFT = 22

    operand_nbytes = 32 * N_WDR * n

    res = {}

    # Test sharewise_xor.
    x = 0
    y = 0
    xb = 0
    yb = 0
    for i in range(n):
        tx = random.getrandbits(N * N_WDR)
        ty = random.getrandbits(N * N_WDR)
        x ^= tx
        y ^= ty
        xb |= (tx << (i * N * N_WDR))
        yb |= (ty << (i * N * N_WDR))
    xy = x ^ y
    xb_bytes = int.to_bytes(xb, byteorder='little', length=operand_nbytes)
    yb_bytes = int.to_bytes(yb, byteorder='little', length=operand_nbytes)
    xy_bytes = int.to_bytes(xy, byteorder='little', length=32 * N_WDR)
    rb_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)
    res['r_xor'] = xy_bytes

    # Write input values.
    inputs = {'xb': xb_bytes, 'yb': yb_bytes, 'rb': rb_bytes}
    write_test_data(inputs, data_file)

    m = (1 << BITSIZE) - 1
    # Test sharewise_lsl
    xcp = x
    xlsl = 0
    for i in range(N):
        xi = (xcp << 5) & m
        xlsl |= (xi << (i * BITSIZE))
        xcp >>= BITSIZE
    xlsl_bytes = int.to_bytes(xlsl, byteorder="little", length=32 * N_WDR)
    res['r_lsl'] = xlsl_bytes

    # Test sharewise_lsr
    xcp = x
    xlsr = 0
    for i in range(N):
        xi = xcp & m
        xi = (xi >> 9) & m
        xlsr |= (xi << (i * BITSIZE))
        xcp >>= BITSIZE
    xlsr_bytes = int.to_bytes(xlsr, byteorder="little", length=32 * N_WDR)
    res['r_lsr'] = xlsr_bytes

    # Test sharewise_msb
    xcp = x
    xmsb = 0
    for i in range(N):
        xi = ((xcp >> MSB_SHIFT) & 1) & m
        xmsb |= (xi << (i * BITSIZE))
        xcp >>= BITSIZE
    xmsb_bytes = int.to_bytes(xmsb, byteorder="little", length=32 * N_WDR)
    res['r_msb'] = xmsb_bytes

    # Test sharewise_bitext
    xcp = x
    xbitext = 0
    for i in range(N):
        xi = (xcp & 1) & m
        xi *= m
        xbitext |= (xi << (i * BITSIZE))
        xcp >>= BITSIZE
    xbitext_bytes = int.to_bytes(xbitext, byteorder="little", length=32 * N_WDR)
    res['r_bitext'] = xbitext_bytes

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp(res, dexp_file)


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

    gen_sharewise_test(args.seed, args.scheme, args.nshares, args.data, args.exp, args.dexp)
