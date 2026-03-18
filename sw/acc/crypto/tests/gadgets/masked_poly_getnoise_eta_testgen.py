#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional, List

from Crypto.Hash import SHAKE256

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
NSHARES = 2
N_WDR = 16
BITSIZE = 16
Q = 3329


def _cbd2(buf: bytes) -> List[int]:
    """ Given an array of uniformly random bytes, compute
    polynomial with coefficients distributed according to
    a centered binomial distribution with parameter eta=2."""
    r = [0] * N
    buf_int = int.from_bytes(buf, byteorder="little")
    for i in range(N // 8):
        t = buf_int & 0xFFFFFFFF
        buf_int >>= 32
        d = t & 0x55555555
        d += (t >> 1) & 0x55555555
        for j in range(8):
            a = (d >> (4 * j)) & 0x3
            b = (d >> (4 * j + 2)) & 0x3
            r[8 * i + j] = (a - b) % Q
    return r


def _cbd3(buf: bytes) -> List[int]:
    """ Given an array of uniformly random bytes, compute
    polynomial with coefficients distributed according to
    a centered binomial distribution with parameter eta=3."""
    r = [0] * N
    buf_int = int.from_bytes(buf, byteorder="little")
    for i in range(N // 4):
        t = buf_int & 0xFFFFFF
        buf_int >>= 24
        d = t & 0x00249249
        d += (t >> 1) & 0x00249249
        d += (t >> 2) & 0x00249249
        for j in range(4):
            a = (d >> (6 * j)) & 0x7
            b = (d >> (6 * j + 3)) & 0x7
            r[4 * i + j] = (a - b) % Q
    return r


def getnoise_eta1(seed: bytes, nonce: int, ksec: int) -> List[int]:
    """Sample a polynomial deterministically from a seed and a nonce,
    with output polynomial close to centered binomial distribution
    with parameter ETA1."""
    shake = SHAKE256.new(seed + bytes([nonce]))
    if ksec == 2:
        buf = shake.read(3 * N // 4)
        r = _cbd3(buf)
    else:
        buf = shake.read(2 * N // 4)
        r = _cbd2(buf)
    return r


def getnoise_eta2(seed: bytes, nonce: int) -> List[int]:
    """Sample a polynomial deterministically from a seed and a nonce,
    with output polynomial close to centered binomial distribution
    with parameter ETA2."""
    shake = SHAKE256.new(seed + bytes([nonce]))
    buf = shake.read(2 * N // 4)
    r = _cbd2(buf)
    return r


def gen_masked_poly_getnoise_eta_test(
        seed: Optional[int], scheme: Optional[int], nshares: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    if nshares is None:
        nshares = NSHARES

    if scheme == 2:
        ksec = 2
    elif scheme == 3:
        ksec = 3
    elif scheme == 4:
        ksec = 4
    else:
        ksec = 3

    operand_nbytes = 32 * N_WDR * nshares

    if nshares == 2:
        coins0 = random.getrandbits(N)
        coins1 = random.getrandbits(N)
        coins = coins0 ^ coins1
        coins = int.to_bytes(coins, byteorder="little", length=32)
        coins0 = int.to_bytes(coins0, byteorder="little", length=32)
        coins1 = int.to_bytes(coins1, byteorder="little", length=32)
    else:
        coins = random.randbytes(32)
    nonce = random.randint(0, 10)
    reta1 = getnoise_eta1(coins, nonce, ksec)
    reta1 = sum(reta1[i] << (i * BITSIZE) for i in range(N))
    reta2 = getnoise_eta2(coins, nonce)
    reta2 = sum(reta2[i] << (i * BITSIZE) for i in range(N))

    nonce_byte = int.to_bytes(nonce, byteorder="little", length=32)
    ra_bytes = int.to_bytes(0, byteorder='little', length=operand_nbytes)
    reta1_bytes = int.to_bytes(reta1, byteorder="little", length=32 * N_WDR)
    reta2_bytes = int.to_bytes(reta2, byteorder="little", length=32 * N_WDR)

    # Write input values.
    if nshares == 2:
        inputs = {'seed': coins0 + coins1, 'nonce': nonce_byte, 'ra': ra_bytes}
    else:
        inputs = {'seed': coins, 'nonce': nonce_byte, 'ra': ra_bytes}

    write_test_data(inputs, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'reta_1': reta1_bytes, 'reta_2': reta2_bytes}, dexp_file)


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

    gen_masked_poly_getnoise_eta_test(
        args.seed, args.scheme, args.nshares, args.data, args.exp, args.dexp)
