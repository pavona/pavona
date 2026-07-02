#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import hashlib
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_COEFS = 256
Q = 8380417
CRHBYTES = 64


def expand_mask(seed: bytes, nonce: int, polyz_bits: int, gamma1: int):
    """Reference poly_uniform_gamma_1: y[i] = gamma1 - u[i], u uniform in
    [0, 2^polyz_bits) drawn little-endian from SHAKE-256(seed || nonce)."""
    n_bytes = N_COEFS * polyz_bits // 8
    shake = hashlib.shake_256()
    shake.update(seed)
    shake.update(nonce.to_bytes(2, 'little'))
    buf = shake.digest(n_bytes)
    out = []
    for i in range(N_COEFS):
        bit = i * polyz_bits
        b = buf[bit // 8:bit // 8 + 3]
        v = int.from_bytes(b, 'little')
        v = (v >> (bit % 8)) & ((1 << polyz_bits) - 1)
        out.append((gamma1 - v) % Q)
    return out


def pack_canonical(vals):
    buf = bytearray()
    for v in vals:
        buf += v.to_bytes(4, 'little')
    return bytes(buf)


def pack_share_major(seed_shares):
    """Concatenate NSHARES x CRHBYTES seed shares share-major."""
    buf = bytearray()
    for s in seed_shares:
        buf += s
    return bytes(buf)


def gen_masked_poly_uniform_gamma1_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    inputs = {}
    dexp = {}
    for mode, polyz_bits, gamma1 in ((2, 18, 1 << 17), (3, 20, 1 << 19)):
        nonce = random.randrange(1 << 16)
        rho = random.randbytes(CRHBYTES)
        mask = random.randbytes(CRHBYTES)
        rho_share0 = bytes(a ^ b for a, b in zip(rho, mask))

        y = expand_mask(rho, nonce, polyz_bits, gamma1)

        suf = 'm{}'.format(mode)
        inputs['rho_{}'.format(suf)] = pack_share_major([rho_share0, mask])
        inputs['nonce_{}'.format(suf)] = nonce.to_bytes(4, 'little')
        inputs['y_{}'.format(suf)] = b'\x00' * (2 * N_COEFS * 4)
        inputs['r_{}'.format(suf)] = b'\x00' * (N_COEFS * 4)
        dexp['r_{}'.format(suf)] = pack_canonical(y)

    write_test_data(inputs, data_file)
    write_test_exp({}, exp_file)
    write_test_dexp(dexp, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen_masked_poly_uniform_gamma1_test(args.seed, args.data, args.exp, args.dexp)
