#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting Wycheproof ML-KEM testvectors to JSON.

Supports:
  - mlkem_*_test.json (--test-type keygen_decaps)
  - mlkem_*_keygen_seed_test.json (--test-type keygen)
  - mlkem_*_encaps_test.json (--test-type encaps)
  - mlkem_*_semi_expanded_decaps_test.json (--test-type decaps)

Instead of including the full expected outputs (ek, dk, ct, k) in the
parsed JSON, this parser pre-computes a SHA3-256 hash of the expected
outputs. The firmware computes the same hash and returns only the
32-byte digest, avoiding expensive transfer of large outputs.
"""

import argparse
import hashlib
import json
import sys

import jsonschema

PARAMETER_SETS = {
    "ML-KEM-512": 512,
    "ML-KEM-768": 768,
    "ML-KEM-1024": 1024,
}


def compute_hash(data):
    """Compute SHA3-256 hash."""
    return list(hashlib.sha3_256(data).digest())


def parse_keygen_decaps(group, param_set):
    """Parse mlkem_*_test.json: keygen + decaps.
    Output hash: SHA3-256(ek || K)."""
    test_vectors = []
    for test in group["tests"]:
        result = test["result"] == "valid"
        ek = bytes.fromhex(test.get("ek", ""))
        K = bytes.fromhex(test.get("K", ""))
        tv = {
            "vendor": "wycheproof",
            "test_case_id": test["tcId"],
            "operation": "keygen_decaps",
            "parameter_set": param_set,
            "seed": list(bytes.fromhex(test["seed"])),
            "c": list(bytes.fromhex(test.get("c", ""))),
            "result": result,
        }
        if result and ek and K:
            tv["expected_hash"] = compute_hash(ek + K)
        test_vectors.append(tv)
    return test_vectors


def parse_keygen(group, param_set):
    """Parse mlkem_*_keygen_seed_test.json: keygen only.
    Output hash: SHA3-256(ek || dk)."""
    test_vectors = []
    for test in group["tests"]:
        result = test["result"] == "valid"
        ek = bytes.fromhex(test.get("ek", ""))
        dk = bytes.fromhex(test.get("dk", ""))
        tv = {
            "vendor": "wycheproof",
            "test_case_id": test["tcId"],
            "operation": "keygen",
            "parameter_set": param_set,
            "seed": list(bytes.fromhex(test["seed"])),
            "result": result,
        }
        if result and ek and dk:
            tv["expected_hash"] = compute_hash(ek + dk)
        test_vectors.append(tv)
    return test_vectors


def parse_encaps(group, param_set):
    """Parse mlkem_*_encaps_test.json: encaps only.
    The randomness m is stored in the seed field.
    Output hash: SHA3-256(ct || K)."""
    test_vectors = []
    for test in group["tests"]:
        result = test["result"] == "valid"
        c = bytes.fromhex(test.get("c", ""))
        K = bytes.fromhex(test.get("K", ""))
        tv = {
            "vendor": "wycheproof",
            "test_case_id": test["tcId"],
            "operation": "encaps",
            "parameter_set": param_set,
            "seed": list(bytes.fromhex(test["m"])),
            "ek": list(bytes.fromhex(test.get("ek", ""))),
            "result": result,
        }
        if result and c and K:
            tv["expected_hash"] = compute_hash(c + K)
        test_vectors.append(tv)
    return test_vectors


def parse_decaps(group, param_set):
    """Parse mlkem_*_semi_expanded_decaps_test.json: decaps only.
    No expected hash — Wycheproof decaps tests do not include K,
    so only success/failure is verified."""
    test_vectors = []
    for test in group["tests"]:
        result = test["result"] == "valid"
        test_vectors.append({
            "vendor": "wycheproof",
            "test_case_id": test["tcId"],
            "operation": "decaps",
            "parameter_set": param_set,
            "dk": list(bytes.fromhex(test["dk"])),
            "c": list(bytes.fromhex(test["c"])),
            "result": result,
        })
    return test_vectors


def parse_test_vectors(raw_data, test_type):
    test_vectors = []
    for group in raw_data["testGroups"]:
        param_set = PARAMETER_SETS[group["parameterSet"]]

        if test_type == "keygen_decaps":
            test_vectors.extend(parse_keygen_decaps(group, param_set))
        elif test_type == "keygen":
            test_vectors.extend(parse_keygen(group, param_set))
        elif test_type == "encaps":
            test_vectors.extend(parse_encaps(group, param_set))
        elif test_type == "decaps":
            test_vectors.extend(parse_decaps(group, param_set))
        else:
            raise ValueError(f"Unsupported test type: {test_type}")

    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for Wycheproof ML-KEM testvectors.")
    parser.add_argument(
        "--src",
        type=argparse.FileType("r"),
        help="Source Wycheproof JSON file.",
    )
    parser.add_argument(
        "--dst",
        type=argparse.FileType("w"),
        help="Destination output JSON file.",
    )
    parser.add_argument(
        "--schema",
        type=str,
        help="JSON schema file for validation.",
    )
    parser.add_argument(
        "--test-type",
        choices=["keygen_decaps", "keygen", "encaps", "decaps"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = json.load(args.src)
    test_vectors = parse_test_vectors(raw_data, args.test_type)

    # Validate generated JSON
    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    json.dump(test_vectors, args.dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
