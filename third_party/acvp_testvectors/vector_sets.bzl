# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

ACVP_SERVER_VERSION = "1.1.0.43"

ACVP_VECTORS_URL = "https://storage.googleapis.com/pavona-test-vectors/acvp-vectors"

# Vector sets made with `genval vectors` and kept in the test vector bucket,
# keyed by the name of their registration file.
# Each file is fetched on its own, and a build downloads only the files it uses.
ACVP_VECTOR_SETS = {
    "aes-cbc": {
        "algorithm": "ACVP-AES-CBC-1.0",
        "registration_sha256": "477be50e083e9898a7b9b5a9b61d32125f153af9817338ae576833eaf46e5986",
        "files": {
            "expectedResults.json": "c2b519e01da33aeffae8c944e91cc23efff520e7cfd626266a380e8d7f00a4d3",
            "prompt.json": "7cbbc2cf45d191e364436707080871a2c3b99ed0c9bed0a32676f443ea8a18da",
        },
    },
    "aes-cfb128": {
        "algorithm": "ACVP-AES-CFB128-1.0",
        "registration_sha256": "bcd38c1124a1fa688db0b9d8ae5682ce5bdb5d14d93aeacd79013229bb985a75",
        "files": {
            "expectedResults.json": "0004167bd7335d90dd89ceb8ca6015db512485b83b30315695d26133df357bfa",
            "prompt.json": "01f1957c2cef59737f292a085fe80fa28944522e0a8e5e83bfc7b278121cdf0a",
        },
    },
    "aes-ecb": {
        "algorithm": "ACVP-AES-ECB-1.0",
        "registration_sha256": "b09c94a18cbdd2bc5c050686e4bbe50bc1a01fc490e009fbe2e58743a9a60500",
        "files": {
            "expectedResults.json": "38b8b828052d84b12a7a9e120ba3002c181eb431f7384146fabe2b6aaeabbf43",
            "prompt.json": "9b610aa8bde02f436850aa76fef24f9f4cc8afda8cb8935dcd82b5274c9067a6",
        },
    },
    "aes-ofb": {
        "algorithm": "ACVP-AES-OFB-1.0",
        "registration_sha256": "81f0c7b6bc03b87b77b046e415c0b31fee5b893e6ec1782d9dac72539df33d88",
        "files": {
            "expectedResults.json": "9871168fd68a84639664e33e69b36a517adaee14b327ba121fc01fec9521d546",
            "prompt.json": "ae2ad311f725fbb5ba6dc99e7aacb856aa3c1784bf4b2f0951fb8d0e6699a881",
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
