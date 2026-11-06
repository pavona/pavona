# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

ACVP_SERVER_VERSION = "1.1.0.43"

ACVP_VECTORS_URL = "https://storage.googleapis.com/pavona-test-vectors/acvp-vectors"

# Vector sets made with `genval vectors` and kept in the test vector bucket,
# keyed by the name of their registration file.
# Each file is fetched on its own, and a build downloads only the files it uses.
ACVP_VECTOR_SETS = {
    "ctr-drbg": {
        "algorithm": "ctrDRBG-SP800-90Ar1",
        "registration_sha256": "052af7b9ae9019d55f0ce793e69fc09cc29a51f5c417316f23fbc53998b77ed9",
        "files": {
            "expectedResults.json": "feaee0d9e2387fa88e6e9502336ac9d60a16d785ce3dd53fd97978deb871b433",
            "prompt.json": "7d760e84600e8eb4befbfd12cd09fda7313b07f2d1f48c5104a9a9866a4501d9",
        },
    },
    "kdf-kmac": {
        "algorithm": "KDF-KMAC-Sp800-108r1",
        "registration_sha256": "6a0d5d9b5d64cc28b4dff9c0b372080c5b2aa500a8869e05ddf7d85eccf761df",
        "files": {
            "expectedResults.json": "2288cfebf99593c67315337cfc2299612ce1bdfdf55f2b59f19b24624e531855",
            "prompt.json": "fc5d4eecf2281ccc011afaa2348a27dd748888b1578a32a5d41dff47854f315b",
        },
    },
}
