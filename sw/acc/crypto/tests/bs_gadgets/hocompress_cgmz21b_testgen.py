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


def compress(x: int, d: int, q: int) -> int:
    """Compression and subsequent serialization of a polynomial."""
    r = ((x << d) + q // 2) // q
    r &= ((1 << d) - 1)
    return r


def gen_hocompress_cgmz21b_test(
        seed: Optional[int], scheme: Optional[int], nshares: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # Generate random operands.
    if seed is not None:
        random.seed(seed)

    if nshares is None:
        nshares = NSHARES

    q = 3329
    if scheme == 4:
        kv = 20
        ku = 26
        dv = 5
        du = 11
    else:
        kv = 19
        ku = 25
        dv = 4
        du = 10

    # For testing before A2B conversion.
    # m = (1 << N) - 1
    # r = [0] * nshares
    # x = [0] * nshares
    # x[0] = [random.randint(0, q - 1) for _ in range(N)]
    # t = [0] * N
    # for j in range(N):
    #     t[j] = compress(x[0][j], dv + alpha, q)
    #     t[j] += (1 << (alpha - 1))
    #     t[j] &= (1 << (dv + alpha)) - 1
    # r[0] = t
    # tmp = sum(x[0][j] << (j * 16) for j in range(N))
    # tmp = int.to_bytes(tmp, byteorder="little", length=512)
    # x_bytes = tmp
    # for i in range(1, nshares):
    #     x[i] = [random.randint(0, q - 1) for _ in range(N)]
    #     t = [0] * N
    #     for j in range(N):
    #         t[j] = compress(x[i][j], dv + alpha, q)
    #     r[i] = t
    #     tmp = sum(x[i][j] << (j * 16) for j in range(N))
    #     tmp = int.to_bytes(tmp, byteorder="little", length=512)
    #     x_bytes += tmp

    # # Bitslicing r.
    # r_bytes = bytes()
    # one = sum(1 << (i * 32) for i in range(8)) & m
    # rt = [0] * 32
    # for s in range(nshares):
    #     cnt = 0
    #     for j in range(0, N, 16):
    #         t = [r[s][i] for i in range(j, j + 16, 2)]
    #         rt[cnt] = sum(t[i] << (i * 32) for i in range(8))
    #         t = [r[s][i] for i in range(j + 1, j + 16, 2)]
    #         rt[cnt + 1] = sum(t[i] << (i * 32) for i in range(8))
    #         cnt += 2
    #     t = [0] * k
    #     for i in range(k):
    #         for j in range(0, 32, 2):
    #             t[i] = (t[i] << 1) | (rt[j] & one)
    #             t[i] = (t[i] << 1) | (rt[j + 1] & one)
    #             rt[j] >>= 1
    #             rt[j + 1] >>= 1
    #         r_bytes += int.to_bytes(t[i], byteorder="little", length=32)

    # For testing masked compression.
    m = (1 << N) - 1
    r = [0] * N
    x = [0] * nshares
    x_bytes = bytes()
    for i in range(nshares):
        x[i] = [random.randint(0, q - 1) for _ in range(N)]
        r = [(r[j] + x[i][j]) % q for j in range(N)]
        tmp = sum(x[i][j] << (j * 16) for j in range(N))
        tmp = int.to_bytes(tmp, byteorder="little", length=512)
        x_bytes += tmp

    # Compress rv and ru.
    rv = [0] * N
    ru = [0] * N
    for i in range(N):
        rv[i] = compress(r[i], dv, q)
        ru[i] = compress(r[i], du, q)

    rtv = [0] * 16
    rtu = [0] * 16
    rv_bytes = bytes()
    ru_bytes = bytes()
    one = sum(1 << (i * 16) for i in range(16)) & m
    cnt = 0
    # Bitslicing rv and ru.
    for j in range(0, N, 16):
        t = [rv[i] for i in range(j, j + 16)]
        rtv[cnt] = sum(t[i] << (i * 16) for i in range(16))
        t = [ru[i] for i in range(j, j + 16)]
        rtu[cnt] = sum(t[i] << (i * 16) for i in range(16))
        cnt += 1

    t = [0] * dv
    for i in range(dv):
        for j in range(16):
            t[i] = (t[i] << 1) | (rtv[j] & one)
            rtv[j] >>= 1
        rv_bytes += int.to_bytes(t[i], byteorder="little", length=32)

    t = [0] * du
    for i in range(du):
        for j in range(16):
            t[i] = (t[i] << 1) | (rtu[j] & one)
            rtu[j] >>= 1
        ru_bytes += int.to_bytes(t[i], byteorder="little", length=32)

    rbv_bytes = int.to_bytes(0, byteorder='little', length=32 * kv * nshares)
    rbu_bytes = int.to_bytes(0, byteorder='little', length=32 * ku * nshares)

    # Write input values.
    inputs = {'xa': x_bytes, 'rbu': rbu_bytes, 'rbv': rbv_bytes}
    write_test_data(inputs, data_file)

    # Write expected register values (none).
    write_test_exp({}, exp_file)

    # Write expected dmem values.
    write_test_dexp({'rv': rv_bytes, 'ru': ru_bytes}, dexp_file)


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

    gen_hocompress_cgmz21b_test(
        args.seed, args.scheme, args.nshares, args.data, args.exp, args.dexp)
