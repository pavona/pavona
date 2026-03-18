#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
from math import ceil, log2
Q = 3329


def compress(x: int, d: int, q: int) -> int:
    """Compression and subsequent serialization of a polynomial."""
    r = ((x << d) + q // 2) // q
    r &= ((1 << d) - 1)
    return r


def compress_wo_div(x: int, d: int, m: int, k: int, q2: int) -> int:
    t = x << d
    print(hex(t))
    t += q2
    print(hex(t))
    t *= m
    print(hex(t))
    t >>= k
    print(hex(t))
    t &= ((1 << d) - 1)
    print(hex(t))
    return t


def find_m(d: int, q2: int, q: int) -> tuple:
    for k in range(16, 64):
        m = ((1 << k) + q // 2) // q
        success = 0
        for x in range(Q):
            r1 = compress(x, d, q)
            r2 = compress_wo_div(x, d, m, k, q2)
            if r2 != r1:
                # print(f"x = {x}")
                # print(f"r1 = {r1}")
                # print(f"r2 = {r2}")
                break
            success += 1
        if success == q:
            # print(f"FOUND k = {k} for d = {d}: m = {m}, q2 = {q2}.\n")
            return 0, k, m
    if success != q:
        # print(f"FAILED to find k for d = {d} and q2 = {q2}.")
        return 1, None, None

# # find_m(4, 1665, Q)
# # find_m(10, 1665, Q)
# # find_m(5, 1665, Q)
# # find_m(11, 1664, Q)


nshares = range(2, 9)
for n in nshares:
    for d in [4, 5, 10, 11]:
        dp = ceil(log2(Q * n)) + d
        f, k, m = find_m(dp, 1664, Q)
        if f == 0:
            print(f"FOUND k = {k}, m = {m} for d = {d} and nshares = {n} and q2 = {1664}.\n")
        f, k, m = find_m(dp, 1665, Q)
        if f == 0:
            print(f"FOUND k = {k}, m = {m} for d = {d} and nshares = {n} and q2 = {1665}.\n")
