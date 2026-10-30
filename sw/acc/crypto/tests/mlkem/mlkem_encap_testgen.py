#!/usr/bin/env python3
# Copyright lowRISC contributors (OpenTitan project).
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import random
from typing import TextIO
from Crypto.PublicKey import MLKEM

from shared.testgen import write_testcase

INSTANCE_FOR_PARAMS = {
    'mlkem512': MLKEM.ML_KEM_512,
    'mlkem768': MLKEM.ML_KEM_768,
    'mlkem1024': MLKEM.ML_KEM_1024,
}


def gen_encaps_test(param_set, mode_symbol: str, tc_file: TextIO):
    # Generate a random key pair.
    key = MLKEM.generate(param_set=param_set, randfunc=random.randbytes)
    ek = key.ek

    # Generate a random seed and encapsulate based on it.
    coins = random.randbytes(32)
    ss, ct = key._encaps(coins)

    # Run the run_mlkem app binary: preload mode + inputs (encap operates on
    # public data), check the (deterministic) ciphertext and shared secret.
    write_testcase(tc_file,
                   inputs={'mode': mode_symbol, 'coins': coins, 'ek': ek},
                   outputs={'ct': ct, 'ss': ss})


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
    # run_mlkem dispatches on this mode symbol (e.g. mlkem512 -> MODE_ENCAP_512).
    mode_symbol = 'MODE_ENCAP_' + args.params.removeprefix('mlkem')
    with args.testcase:
        gen_encaps_test(param_set, mode_symbol, args.testcase)
