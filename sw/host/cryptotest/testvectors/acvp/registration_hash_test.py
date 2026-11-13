#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Checks that each vector set in the test vector bucket belongs to the
registration it is pinned for.

The path `genval vectors` writes a vector set to contains the SHA-256 of its
registration file.
"""

import hashlib
import sys


def main():
    failed = False
    for arg in sys.argv[1:]:
        path, expected = arg.split("=")
        with open(path, "rb") as f:
            actual = hashlib.sha256(f.read()).hexdigest()
        if actual != expected:
            print(f"{path}: the vector set is for registration {expected}, "
                  f"but the registration hashes to {actual}. "
                  "Generate a new vector set with `genval vectors`.")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
