#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP ECDSA prompts to JSON.

Uses the internalProjection files from the NIST ACVP-Server repo. See
VALID_CURVE_HASH_PAIRS for the supported pairs of curves and hash algorithms.
Supports:
  - ACVP-ECDSA-sigGen-FIPS186-5 (siggen)
  - ACVP-ECDSA-sigVer-FIPS186-5 (sigver)
"""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, load_vector_set, report_skipped

CURVES = {
    "P-256": "p256",
    "P-384": "p384",
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
    ("p256", "sha3-384"),
    ("p256", "sha3-512"),
    ("p384", "sha3-384"),
    ("p384", "sha3-512"),
]


def parse_siggen(data, skip_unsupported):
    """Parse an ECDSA-sigGen internalProjection. Response: the signature."""
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
        curve = CURVES[group["curve"]]
        hash_alg = HASH_ALGS[group["hashAlg"]]
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
                "qx": group["qx"],
                "qy": group["qy"],
                "d": group["d"],
                "result": True,
            })
    report_skipped("parse_siggen", {
        "the hash algorithm is not implemented": skipped_hash_alg,
        "the curve is not implemented": skipped_curve,
        "the hash algorithm cannnot be used for the specified curve": skipped_curve_hash_pair,
    }, skip_unsupported)
    return test_vectors


def parse_sigver(data, skip_unsupported):
    """Parse an ECDSA-sigVer internalProjection. Response: testPassed."""
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
        curve = CURVES[group["curve"]]
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
                "result": test["testPassed"],
            })
    report_skipped("parse_siggen", {
        "the hash algorithm is not implemented": skipped_hash_alg,
        "the curve is not implemented": skipped_curve,
        "the hash algorithm cannnot be used for the specified curve": skipped_curve_hash_pair,
    }, skip_unsupported)
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
        "--skip-unsupported",
        action="store_true",
        help="Skip test cases this cryptolib cannot answer. Without it any "
        "such test case is an error. NIST's published "
        "sample sets declare every capability an algorithm has, so parsing "
        "one of those needs this.",
    )
    parser.add_argument(
        "--test-type",
        choices=["keygen", "siggen", "sigver"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = load_vector_set(args.src)

    if args.test_type == "siggen":
        test_vectors = parse_siggen(raw_data, args.skip_unsupported)
    elif args.test_type == "sigver":
        test_vectors = parse_sigver(raw_data, args.skip_unsupported)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
