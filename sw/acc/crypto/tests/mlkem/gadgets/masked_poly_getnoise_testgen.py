#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional, List

from Crypto.Hash import SHAKE256

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N = 256
NSHARES = 2
K = 16
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


def getnoise(seed: bytes, nonce: int, eta: int) -> int:
    """Sample a polynomial from a seed and a nonce, close to a centered
    binomial distribution with the given parameter eta, packed into a WDR
    array."""
    shake = SHAKE256.new(seed + bytes([nonce]))
    buf = shake.read(eta * N // 4)
    r = _cbd3(buf) if eta == 3 else _cbd2(buf)
    return sum(r[i] << (i * K) for i in range(N))


def gen_masked_poly_getnoise_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    # Random Boolean shares of the seed; their XOR is the unmasked seed.
    coins0 = random.getrandbits(N)
    coins1 = random.getrandbits(N)
    coins = int.to_bytes(coins0 ^ coins1, byteorder="little", length=32)
    seed_bytes = (int.to_bytes(coins0, byteorder="little", length=32)
                  + int.to_bytes(coins1, byteorder="little", length=32))
    nonce = random.randint(0, 10)
    nonce_byte = int.to_bytes(nonce, byteorder="little", length=32)

    # eta_1 is exercised at both ETA1 values (2 and 3); eta_2 uses eta = 2.
    def pack(v):
        return int.to_bytes(v, byteorder="little", length=512)
    reta1_e2 = pack(getnoise(coins, nonce, 2))
    reta1_e3 = pack(getnoise(coins, nonce, 3))
    reta2 = pack(getnoise(coins, nonce, 2))

    # Write input values.
    inputs = {
        'seed': seed_bytes,
        'nonce': nonce_byte,
        'ra': int.to_bytes(0, byteorder='little', length=512 * NSHARES)
    }
    write_test_data(inputs, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'reta_1_e2': reta1_e2, 'reta_1_e3': reta1_e3,
                     'reta_2': reta2}, dexp_file)


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
        gen_masked_poly_getnoise_test(args.seed, args.data, args.exp,
                                      args.dexp)
