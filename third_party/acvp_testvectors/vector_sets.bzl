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
    "sha2-256": {
        "algorithm": "SHA2-256-1.0",
        "registration_sha256": "19374e648264f1bd4912dc4f5a2523d75bb17dbe330062e31d4e1ec0269a1764",
        "files": {
            "expectedResults.json": "caea7fe934e0bcd042bb609204500fbb2e29f0aab26aec5f6f07a8504f71a72a",
            "prompt.json": "8f893496e035568f9f055bc4ba3e97026b290fa6ef9c99403023f6f11f9417ed",
        },
    },
    "sha2-384": {
        "algorithm": "SHA2-384-1.0",
        "registration_sha256": "f35cdd65d5d45c9614c93ad8da02920039bae523ded1f6863f987814020a04e6",
        "files": {
            "expectedResults.json": "3035e1ceab5a5777e6f292b5ae0d46ec37435db5398798b6b556ec2308d015c4",
            "prompt.json": "3ef2e94dba6f363ff60a7889810b8c2ae8a73e5cde788d3420aea1b229e13e83",
        },
    },
    "sha2-512": {
        "algorithm": "SHA2-512-1.0",
        "registration_sha256": "8b1dbdcddd61898c093093082f7bce36f789a6b83abff8a3ea789b14526997de",
        "files": {
            "expectedResults.json": "3e0ab60efa0a77181b3a2c648cb9a3e5535ebb3e9c07cecc2c3e971a0a756b69",
            "prompt.json": "2d4b2d9057d6d6c5d7387b7a84f55d3a36edc9a11681234c5bf1d835ec9cf7ff",
        },
    },
}
