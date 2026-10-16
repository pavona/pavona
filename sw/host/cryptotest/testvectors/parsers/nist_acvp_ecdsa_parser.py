#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP ECDSA prompts to JSON.

Reads a `prompt.json`, or alternatively a `internalProjection.json` (siggen
only, for local testing) vector set. The harness assembles the response. See
VALID_CURVE_HASH_PAIRS for the supported pairs of curves and hash algorithms.
Supports:
  - ACVP-ECDSA-sigGen-FIPS186-5 (siggen)
  - ACVP-ECDSA-sigVer-FIPS186-5 (sigver)
"""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, apply_expected, load_vector_set
from cryptotest_util import str_to_byte_array
from Crypto.PublicKey import ECC

# Accepted ECC curves and corresponding scalar sizes in bytes.
CURVES = {
    "P-256": ("p256", 32),
    "P-384": ("p384", 48),
}

HASH_ALGS = {
    "SHA2-256": "sha-256",
    "SHA2-384": "sha-384",
    "SHA2-512": "sha-512",
    "SHA3-256": "sha3-256",
    "SHA3-384": "sha3-384",
    "SHA3-512": "sha3-512",
}

VALID_CURVE_HASH_PAIRS = [
    ("p256", "sha-256"),
    ("p256", "sha-384"),
    ("p256", "sha-512"),
    ("p384", "sha-384"),
    ("p384", "sha-512"),
]


def parse_siggen(data):
    """Parse an ECDSA-sigGen prompt or internalProjection."""
    test_vectors = []
    skipped_hash_alg = 0
    skipped_curve = 0
    skipped_curve_hash_pair = 0
    for group in data["testGroups"]:
        if group["curve"] not in CURVES:
            skipped_curve += len(group["tests"])
            continue
        if group["hashAlg"] not in HASH_ALGS:
            skipped_hash_alg += len(group["tests"])
            continue
        curve, scalar_bytes = CURVES[group["curve"]]
        hash_alg = HASH_ALGS[group["hashAlg"]]
        if "d" in group:
            qx = group["qx"]
            qy = group["qy"]
            d = group["d"]
        else:
            key = ECC.generate(curve=curve)
            qx = key.pointQ.x.to_bytes(scalar_bytes, "big").hex().upper()
            qy = key.pointQ.y.to_bytes(scalar_bytes, "big").hex().upper()
            d = key.d.to_bytes(scalar_bytes, "big").hex().upper()
        if (curve, hash_alg) not in VALID_CURVE_HASH_PAIRS:
            skipped_curve_hash_pair += len(group["tests"])
            continue
        for test in group["tests"]:
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "siggen",
                "curve": curve,
                "hash_alg": hash_alg,
                "message": list(bytes.fromhex(test["message"])),
                "qx": qx,
                "qy": qy,
                "d": d,
                "result": True,
            })
    return test_vectors


def parse_sigver(data):
    """Parse an ECDSA-sigVer prompt."""
    test_vectors = []
    skipped_hash_alg = 0
    skipped_curve = 0
    skipped_curve_hash_pair = 0
    for group in data["testGroups"]:
        if group["curve"] not in CURVES:
            skipped_curve += len(group["tests"])
            continue
        if group["hashAlg"] not in HASH_ALGS:
            skipped_hash_alg += len(group["tests"])
            continue
        curve, _ = CURVES[group["curve"]]
        hash_alg = HASH_ALGS[group["hashAlg"]]
        if (curve, hash_alg) not in VALID_CURVE_HASH_PAIRS:
            skipped_curve_hash_pair += len(group["tests"])
            continue
        for test in group["tests"]:
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "sigver",
                "curve": curve,
                "hash_alg": hash_alg,
                "message": list(bytes.fromhex(test["message"])),
                "qx": test["qx"],
                "qy": test["qy"],
                "r": test["r"],
                "s": test["s"],
            })
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP ECDSA prompts.")
    parser.add_argument(
        "--src",
        type=str,
        help="Source ACVP test vector file.",
    )
    parser.add_argument(
        "--dst",
        type=str,
        help="Destination output JSON file.",
    )
    parser.add_argument(
        "--expected",
        type=str,
        help="ACVP expectedResults.json holding the answers to the prompt. "
        "Without it the test vectors carry no expected outputs and the "
        "harness only records what the device returns.",
    )
    parser.add_argument(
        "--schema",
        type=str,
        help="JSON schema file for validation.",
    )
    parser.add_argument(
        "--test-type",
        choices=["siggen", "sigver"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = load_vector_set(args.src)

    if args.test_type == "siggen":
        test_vectors = parse_siggen(raw_data)
    elif args.test_type == "sigver":
        test_vectors = parse_sigver(raw_data)
        apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
