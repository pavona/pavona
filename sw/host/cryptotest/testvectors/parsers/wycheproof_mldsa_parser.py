#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting Wycheproof ML-DSA testvectors to JSON.

Supports:
  - mldsa_XX_verify_test.json (sigver)
  - mldsa_XX_sign_seed_test.json (keygen + siggen from seed)
  - mldsa_XX_sign_noseed_test.json (siggen from full secret key)

Tests with the "Internal" flag are skipped (require internal API).
Tests with "InvalidPrivateKey" are skipped (FIPS 204 does not mandate
private key validation during signing).

For siggen, the parser pre-computes a SHA3-256 hash of the expected
signature, avoiding expensive transfer of large outputs.
"""

import argparse
import hashlib
import json
import sys

import jsonschema

PARAMETER_SETS = {
    "44": 44,
    "65": 65,
    "87": 87,
}


def compute_hash(data):
    """Compute SHA3-256 hash."""
    return list(hashlib.sha3_256(data).digest())


def parse_verify(data, param_set):
    """Parse mldsa_XX_verify_test.json."""
    test_vectors = []
    for group in data["testGroups"]:
        pk = bytes.fromhex(group["publicKey"])
        for test in group["tests"]:
            msg = bytes.fromhex(test["msg"])
            sig = bytes.fromhex(test["sig"])
            ctx = bytes.fromhex(test.get("ctx", ""))
            test_vectors.append({
                "vendor": "wycheproof",
                "test_case_id": test["tcId"],
                "operation": "sigver",
                "parameter_set": param_set,
                "pk": list(pk),
                "message": list(msg),
                "context": list(ctx),
                "signature": list(sig),
                "result": test["result"] == "valid",
            })
    return test_vectors


def parse_sign_seed(data, param_set):
    """Parse mldsa_XX_sign_seed_test.json.

    Each group has a privateSeed; we emit a keygen + siggen per test.
    Skip tests with Internal flag (require internal API).
    Output hash: SHA3-256(pk || signature).
    """
    test_vectors = []
    for group in data["testGroups"]:
        seed = bytes.fromhex(group["privateSeed"])
        for test in group["tests"]:
            flags = test.get("flags", [])
            if "Internal" in flags:
                continue

            msg = bytes.fromhex(test.get("msg", ""))
            ctx = bytes.fromhex(test.get("ctx", ""))
            is_valid = test["result"] == "valid"

            # Keygen from seed then sign with deterministic rnd (all zeros).
            rnd = bytes(32)
            entry = {
                "vendor": "wycheproof",
                "test_case_id": test["tcId"],
                "operation": "keygen_sign",
                "parameter_set": param_set,
                "seed": list(seed),
                "message": list(msg),
                "context": list(ctx),
                "rnd": list(rnd),
                "result": is_valid,
            }
            if is_valid:
                pk = bytes.fromhex(group["publicKey"])
                sig = bytes.fromhex(test["sig"])
                entry["expected_hash"] = compute_hash(pk + sig)
            test_vectors.append(entry)
    return test_vectors


def parse_sign_noseed(data, param_set):
    """Parse mldsa_XX_sign_noseed_test.json.

    Each group has a full privateKey; we emit siggen per test.
    Skip tests with Internal or InvalidPrivateKey flags.
    FIPS 204 does not mandate private key validation during signing.
    Output hash for siggen: SHA3-256(signature).
    """
    test_vectors = []
    for group in data["testGroups"]:
        sk = bytes.fromhex(group["privateKey"])
        for test in group["tests"]:
            flags = test.get("flags", [])
            if "Internal" in flags or "InvalidPrivateKey" in flags:
                continue

            msg = bytes.fromhex(test.get("msg", ""))
            ctx = bytes.fromhex(test.get("ctx", ""))
            is_valid = test["result"] == "valid"

            rnd = bytes(32)
            entry = {
                "vendor": "wycheproof",
                "test_case_id": test["tcId"],
                "operation": "siggen",
                "parameter_set": param_set,
                "sk": list(sk),
                "message": list(msg),
                "context": list(ctx),
                "rnd": list(rnd),
                "result": is_valid,
            }
            if is_valid:
                sig = bytes.fromhex(test["sig"])
                entry["expected_hash"] = compute_hash(sig)
            test_vectors.append(entry)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for Wycheproof ML-DSA testvectors.")
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
        choices=["verify", "sign_seed", "sign_noseed"],
        required=True,
        help="Type of test vectors to parse.",
    )
    parser.add_argument(
        "--param-set",
        choices=["44", "65", "87"],
        required=True,
        help="ML-DSA parameter set.",
    )
    args = parser.parse_args()

    raw_data = json.load(args.src)
    param_set = PARAMETER_SETS[args.param_set]

    if args.test_type == "verify":
        test_vectors = parse_verify(raw_data, param_set)
    elif args.test_type == "sign_seed":
        test_vectors = parse_sign_seed(raw_data, param_set)
    elif args.test_type == "sign_noseed":
        test_vectors = parse_sign_noseed(raw_data, param_set)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    json.dump(test_vectors, args.dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
