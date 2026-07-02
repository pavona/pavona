#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO, Optional

from shared.testgen import write_test_data, write_test_exp, write_test_dexp

N_LANES = 256
Q = 8380417
KBITS = 23
WDR_BYTES = 32
BLOCK_BYTES = KBITS * WDR_BYTES


def bitslice(vals):
    out = bytearray()
    for b in range(KBITS):
        w = sum(((v >> b) & 1) << lane for lane, v in enumerate(vals))
        out += w.to_bytes(WDR_BYTES, 'little')
    return bytes(out)


def rejecting_block(rng):
    vals = [rng.randrange(1 << KBITS) for _ in range(N_LANES)]
    bad_lane = rng.randrange(N_LANES)
    vals[bad_lane] = Q + rng.randrange((1 << KBITS) - Q)
    return bitslice(vals)


def accepting_block(rng):
    vals = [rng.randrange(Q) for _ in range(N_LANES)]
    return bitslice(vals)


def gen_poly_rej_samp_bitsliced_test(
        seed: Optional[int],
        data_file: TextIO, exp_file: TextIO, dexp_file: TextIO):
    # seed is 0,1,2,3,4 -- use that as the number of rejecting blocks
    n_rejects = seed if seed is not None else 0
    rng = random.Random(seed)

    rand_bytes = b''.join(rejecting_block(rng) for _ in range(n_rejects))
    expected = accepting_block(rng)
    rand_bytes += expected

    write_test_data({'rand': rand_bytes, 'r': b'\x00' * BLOCK_BYTES},
                    data_file)
    write_test_exp({}, exp_file)
    write_test_dexp({'r': expected}, dexp_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed', type=int, required=False)
    parser.add_argument('data', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('exp', metavar='FILE', type=argparse.FileType('w'))
    parser.add_argument('dexp', metavar='FILE', type=argparse.FileType('w'))
    args = parser.parse_args()
    gen_poly_rej_samp_bitsliced_test(args.seed, args.data, args.exp, args.dexp)
