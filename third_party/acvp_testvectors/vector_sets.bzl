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
    "aes-kwp": {
        "algorithm": "ACVP-AES-KWP-1.0",
        "registration_sha256": "e8673141cae36a83cb6217e8096ca5caaf26ba9dfd287189f50fba28ed781ec8",
        "files": {
            "expectedResults.json": "f1b08882c6f8aa5ba97fc255ff6940d04474c5ce6696f7ff615b6a79fc57c8b4",
            "prompt.json": "bdee616131c0ec9cb18c214335fbd2277ccaea7baf9822e21bbfbc4db7eed922",
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
    "ctr-drbg": {
        "algorithm": "ctrDRBG-SP800-90Ar1",
        "registration_sha256": "052af7b9ae9019d55f0ce793e69fc09cc29a51f5c417316f23fbc53998b77ed9",
        "files": {
            "expectedResults.json": "feaee0d9e2387fa88e6e9502336ac9d60a16d785ce3dd53fd97978deb871b433",
            "prompt.json": "7d760e84600e8eb4befbfd12cd09fda7313b07f2d1f48c5104a9a9866a4501d9",
        },
    },
    "hmac-sha2-256": {
        "algorithm": "HMAC-SHA2-256-2.0",
        "registration_sha256": "ea6d25291b3a9712e8979cb4f681c68af7e324750ac72c6e65f101b797d03480",
        "files": {
            "expectedResults.json": "d77003caa674d75b81ccd72942670c3bc299826d3de7878608617260851b0ef2",
            "prompt.json": "a8dc3febfad5d495fd812976bf003276f75101352807660f372618414d514774",
        },
    },
    "hmac-sha2-384": {
        "algorithm": "HMAC-SHA2-384-2.0",
        "registration_sha256": "d66b8fd4441054ce6aade4fed5dd7a7996e71a9771a1098037021a35863fdfe4",
        "files": {
            "expectedResults.json": "949100bd4129322804dbb99f06c0e71bc78572fd27b72164ce9410bf4d1976b6",
            "prompt.json": "4bebb0f2a6297341298ef790f26d88630a5ae419a7c143032c66a24ee98a7f2e",
        },
    },
    "hmac-sha2-512": {
        "algorithm": "HMAC-SHA2-512-2.0",
        "registration_sha256": "42f73dea49d584582607b942bba1411e9a115ed7e9791ff8acb71f786da26a63",
        "files": {
            "expectedResults.json": "aab3df894f1640d19a686b02281050207e73c53ba93e89fe0630821e3f103e62",
            "prompt.json": "7998001e5cc2cde9d4a2005b99dfd652138891ef19c15098b140027d4c389489",
        },
    },
    "kda-hkdf": {
        "algorithm": "KDA-HKDF-Sp800-56Cr2",
        "registration_sha256": "83aadaae85b31dc7adcf9d3a5c00d9464cd6f0d180597f553d2842b5c98b9dc4",
        "files": {
            "expectedResults.json": "9d065b15b01d9f832910ce445c002c0941635031a9ff11e2109fda72a60f6010",
            "prompt.json": "49d6db5fed29e7682923d9bcee9d4020e21ae99aab75613d1a7e933083e28440",
        },
    },
    "kdf": {
        "algorithm": "KDF-1.0",
        "registration_sha256": "d888d027e474a182cf3d2488093e3f7b7106938c1c624434a129e62a2a714198",
        "files": {
            "internalProjection.json": "c48bd2bb845a40347a5e3e0454326a1399be029f0a743082341c4807ef3c937c",
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
    "ml-dsa-keygen": {
        "algorithm": "ML-DSA-keyGen-FIPS204",
        "registration_sha256": "00d8321144c9eba8e39473d149d6e7ff9d23da4c781d2305b2d7c640e036b7de",
        "files": {
            "expectedResults.json": "fefc9c3e514eabb29cc2b5740fe8d1c8bb6a0b28fa4cebaa6c32d580c1527629",
            "prompt.json": "8fece61529c64730184cfa7fde0317222d2b62ed5412b7ae84784dd4ab9e5be7",
        },
    },
    "ml-dsa-siggen": {
        "algorithm": "ML-DSA-sigGen-FIPS204",
        "registration_sha256": "499b684c3484e6948bf1c0eb7d0a1633695790f88494bab999db590203f6da19",
        "files": {
            "expectedResults.json": "c1570df3082dfdeeedc0dab42b8928321ed9cc802de4e2a0dc854dbd7e60abd3",
            "prompt.json": "078c88baa2dcfdced81ecbfe98d1470d79266e31c54f6aa9b3f59ad4e137e4e6",
        },
    },
    "ml-dsa-sigver": {
        "algorithm": "ML-DSA-sigVer-FIPS204",
        "registration_sha256": "ebdff32aeb766f6d450f5cdead8281994941771f72bff4934661e05de0f71f4b",
        "files": {
            "expectedResults.json": "360d6772081e66b9c23eb22a93e90bf453392fbba56d51f8759b4574d379c6bf",
            "prompt.json": "3d6f446f25ba6cdf4d80f824919d3c06cf016535d2a21eeb9648c008e3fbe7d9",
        },
    },
    "ml-kem-encapdecap": {
        "algorithm": "ML-KEM-encapDecap-FIPS203",
        "registration_sha256": "93d38af12150ce3460e18dbc8a152e62a91af1d2b27da84aa79a093bddcf7086",
        "files": {
            "expectedResults.json": "8bd572cb4738139f17199c0a142efb8f5a53141a1b0aba6da9797392230a6ccf",
            "prompt.json": "8c52326976bf473b2f474be4276ebf4992dc36feeede64960b4cd940d162b291",
        },
    },
    "ml-kem-keygen": {
        "algorithm": "ML-KEM-keyGen-FIPS203",
        "registration_sha256": "449a585000ee3c31bed0cdc0192ac2c44d5756aea1f2a9989f45cd7429a58d85",
        "files": {
            "expectedResults.json": "d2a2e5b59d758db5812c6bbcf6d09c900ed2c91a5cfedcf2018388c2e764a1a1",
            "prompt.json": "dd2c988a2a129e4a98e1556a58e858b9a542b39cd6456af8b52b0b6cad29ae28",
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
    "sha3-224": {
        "algorithm": "SHA3-224-2.0",
        "registration_sha256": "c1221f69fa3515d7dc9f3af85f92125b31ea06f48fcad17c120761a4492612e6",
        "files": {
            "expectedResults.json": "f84b56722c276949c4c3f3a9079e9ad7297e30db2cc6e644cfedecaab558bc2b",
            "prompt.json": "d5a1410b2e5649e882f773e77486d4b8fa5bc899c5b3b03fc010cfaed35b4469",
        },
    },
    "sha3-256": {
        "algorithm": "SHA3-256-2.0",
        "registration_sha256": "48c811e21e343abc9891a0e6dd7a01b3b9752ab8f3f196df01d7441a454c1329",
        "files": {
            "expectedResults.json": "66930a96c37277ca1c419cf2b0c06949633fae499f378569bb570ab5c9853176",
            "prompt.json": "1a788db6f3fd3e6c6a50695547553a22ae2309b1aa4fead49221d469017d2d13",
        },
    },
    "sha3-384": {
        "algorithm": "SHA3-384-2.0",
        "registration_sha256": "aa5a2183bd16a19e9b142d56146c4290cb9dc592d028d7aac7d7e8e6442cd655",
        "files": {
            "expectedResults.json": "b7dcc485f54b446c9925ddd767c2c390915d14fe72bf274a01d52f60dbd3628e",
            "prompt.json": "7158eeff0e310ced70a680fa9857a44ae5c6622f84a8e06359b96c17c1a8786a",
        },
    },
    "sha3-512": {
        "algorithm": "SHA3-512-2.0",
        "registration_sha256": "db17c0731231a06a92019f30ee83cc56c7227011e1c187176ac5822b7c086597",
        "files": {
            "expectedResults.json": "23a516b68d83ddea818017949678f09c0872e57696442d0ae891d0973990ec85",
            "prompt.json": "f3c6fef8c8753a90a4d4ce01323c8faaf3406f69be420d83b185204e78c2015b",
        },
    },
    "shake-128": {
        "algorithm": "SHAKE-128-FIPS202",
        "registration_sha256": "f83c2785a6758f4f2888b02fc9fde710e29673e848149f7b19a8f959c667efaf",
        "files": {
            "expectedResults.json": "40239b3cbad784940f7d464b0b278304ed63bf462c2cc6acf6394336d2a52fa8",
            "prompt.json": "513c991c7f48c0ba4f4839a94fd544d51a47fc536561d6f35623bf9aa06019b5",
        },
    },
    "shake-256": {
        "algorithm": "SHAKE-256-FIPS202",
        "registration_sha256": "c575fea84d5bd362daa3d50fb752e7dfbb7d05ec958e5f390a330643b600416c",
        "files": {
            "expectedResults.json": "b5d6f73c4812c04b63edebfea4f5dc125c48d682d669204abe4df65e26def709",
            "prompt.json": "f0d5918aa0a165634693303418653fc877c55c579ea37279e66931d9fdd369e0",
        },
    },
}
