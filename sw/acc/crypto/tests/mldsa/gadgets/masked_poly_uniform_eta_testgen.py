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


def expand_s_poly(seed: bytes, nonce: int, eta: int):
    """Reference poly_uniform_eta (ML-DSA, FIPS 204 CoeffFromHalfByte):
    4-bit nibble; eta=2 rejects 15, coeff = 2 - (n mod 5); eta=4 rejects
    n >= 9, coeff = 4 - n.  Mirrors sw/acc/crypto/mldsa/poly.s."""
    shake = hashlib.shake_256()
    shake.update(seed)
    shake.update(nonce.to_bytes(2, 'little'))
    buf = shake.digest(1024)
    out = []
    pos = 0
    while len(out) < N_COEFS:
        b = buf[pos]
        pos += 1
        for t in (b & 0xF, b >> 4):
            if len(out) >= N_COEFS:
                break
            if eta == 2 and t < 15:
                t = t - (205 * t >> 10) * 5
                out.append((eta - t) % Q)
            elif eta == 4 and t < 9:
                out.append((eta - t) % Q)
    return out


def pack_canonical(vals):
    buf = bytearray()
    for v in vals:
        buf += v.to_bytes(4, 'little')
    return bytes(buf)


def pack_share_major(seed_shares):
    buf = bytearray()
    for s in seed_shares:
        buf += s
    return bytes(buf)


def gen_masked_poly_uniform_eta_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    if seed is not None:
        random.seed(seed)

    inputs = {}
    dexp = {}
    for eta in (2, 4):
        nonce = random.randrange(1 << 16)
        rho = random.randbytes(CRHBYTES)
        mask = random.randbytes(CRHBYTES)
        rho_share0 = bytes(a ^ b for a, b in zip(rho, mask))

        s = expand_s_poly(rho, nonce, eta)

        suf = 'e{}'.format(eta)
        inputs['rho_{}'.format(suf)] = pack_share_major([rho_share0, mask])
        inputs['nonce_{}'.format(suf)] = nonce.to_bytes(4, 'little')
        inputs['s_{}'.format(suf)] = b'\x00' * (2 * N_COEFS * 4)
        dexp['r_{}'.format(suf)] = pack_canonical(s)

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
    gen_masked_poly_uniform_eta_test(args.seed, args.data, args.exp, args.dexp)
