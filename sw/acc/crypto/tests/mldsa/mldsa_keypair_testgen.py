#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO
from Crypto.PublicKey import MLDSA

from shared.testgen import write_testcase

INSTANCE_FOR_PARAMS = {
    'mldsa44': MLDSA.ML_DSA_44,
    'mldsa65': MLDSA.ML_DSA_65,
    'mldsa87': MLDSA.ML_DSA_87,
}


def gen_keypair_test(param_set, mode_symbol: str, tc_file: TextIO):
    # Generate a random seed and expected keys.
    zeta = random.randbytes(32)
    key = MLDSA.construct(param_set=param_set, seed=zeta)
    pk, sk = key.pk, key.sk

    # Run the run_mldsa app binary: preload mode + seed into its own DMEM
    # buffers, check the (deterministic) public and secret keys.
    write_testcase(tc_file,
                   inputs={'mode': mode_symbol, 'zeta': zeta},
                   outputs={'pk': pk, 'sk': sk})


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--seed',
                        type=int,
                        required=False,
                        help=('Seed value for pseudorandomness.'))
    parser.add_argument('params',
                        type=str,
                        help=('Parameters to use. Options: '
                              f'{", ".join(INSTANCE_FOR_PARAMS.keys())}'))
    parser.add_argument('testcase',
                        metavar='FILE',
                        type=argparse.FileType('w'),
                        help=('Output file for the accsim testcase (hjson).'))
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
    if args.params not in INSTANCE_FOR_PARAMS:
        raise ValueError(f'Invalid parameters: {args.params}. Expected one of '
                         f'{", ".join(INSTANCE_FOR_PARAMS.keys())}')
    param_set = INSTANCE_FOR_PARAMS[args.params]
    # run_mldsa dispatches on this mode symbol (e.g. mldsa44 -> MODE_KEYGEN_44).
    mode_symbol = 'MODE_KEYGEN_' + args.params.removeprefix('mldsa')
    with args.testcase:
        gen_keypair_test(param_set, mode_symbol, args.testcase)
