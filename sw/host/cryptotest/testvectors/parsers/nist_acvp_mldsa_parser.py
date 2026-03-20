#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP ML-DSA testvectors to JSON.

Uses the internalProjection files from the NIST ACVP-Server repo.
Supports:
  - ML-DSA-keyGen-FIPS204 (keygen)
  - ML-DSA-sigGen-FIPS204 (siggen)
  - ML-DSA-sigVer-FIPS204 (sigver)

For keygen and siggen, the parser pre-computes a SHA3-256 hash of the
expected outputs. The firmware computes the same hash and returns only
the 32-byte digest, avoiding expensive transfer of large outputs.

Only pure ML-DSA (external interface, no preHash, no externalMu) is
supported for now.
"""

import argparse
import hashlib
import json
import sys

import jsonschema

PARAMETER_SETS = {
    "ML-DSA-44": 44,
    "ML-DSA-65": 65,
    "ML-DSA-87": 87,
}


def compute_hash(data):
    """Compute SHA3-256 hash."""
    return list(hashlib.sha3_256(data).digest())


def parse_keygen(data):
    """Parse ML-DSA-keyGen internalProjection.
    Output hash: SHA3-256(pk || sk)."""
    test_vectors = []
    for group in data["testGroups"]:
        param_set = PARAMETER_SETS[group["parameterSet"]]
        for test in group["tests"]:
            seed = bytes.fromhex(test["seed"])
            pk = bytes.fromhex(test["pk"])
            sk = bytes.fromhex(test["sk"])
            test_vectors.append({
                "vendor": "acvp",
                "test_case_id": test["tcId"],
                "operation": "keygen",
                "parameter_set": param_set,
                "seed": list(seed),
                "expected_hash": compute_hash(pk + sk),
                "result": True,
            })
    return test_vectors


def parse_siggen(data):
    """Parse ML-DSA-sigGen internalProjection.
    Only deterministic, pure ML-DSA (external, no preHash, no externalMu).
    Output hash: SHA3-256(signature)."""
    test_vectors = []
    for group in data["testGroups"]:
        # Only support pure ML-DSA (external, no preHash, no externalMu).
        if group.get("signatureInterface") != "external":
            continue
        if group.get("preHash") != "pure":
            continue
        if group.get("externalMu", False):
            continue

        deterministic = group.get("deterministic", False)
        param_set = PARAMETER_SETS[group["parameterSet"]]
        for test in group["tests"]:
            sk = bytes.fromhex(test["sk"])
            message = bytes.fromhex(test["message"])
            context = bytes.fromhex(test.get("context", ""))
            sig = bytes.fromhex(test["signature"])
            rnd = bytes(32) if deterministic else bytes.fromhex(test["rnd"])
            test_vectors.append({
                "vendor": "acvp",
                "test_case_id": test["tcId"],
                "operation": "siggen",
                "parameter_set": param_set,
                "sk": list(sk),
                "message": list(message),
                "context": list(context),
                "rnd": list(rnd),
                "expected_hash": compute_hash(sig),
                "result": True,
            })
    return test_vectors


def parse_sigver(data):
    """Parse ML-DSA-sigVer internalProjection.
    Only pure ML-DSA (external, no preHash, no externalMu)."""
    test_vectors = []
    for group in data["testGroups"]:
        # Only support pure ML-DSA for now.
        if group.get("signatureInterface") != "external":
            continue
        if group.get("preHash") != "pure":
            continue
        if group.get("externalMu", False):
            continue

        param_set = PARAMETER_SETS[group["parameterSet"]]
        for test in group["tests"]:
            pk = bytes.fromhex(test["pk"])
            message = bytes.fromhex(test["message"])
            context = bytes.fromhex(test.get("context", ""))
            sig = bytes.fromhex(test["signature"])
            test_vectors.append({
                "vendor": "acvp",
                "test_case_id": test["tcId"],
                "operation": "sigver",
                "parameter_set": param_set,
                "pk": list(pk),
                "message": list(message),
                "context": list(context),
                "signature": list(sig),
                "result": test["testPassed"],
            })
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP ML-DSA testvectors.")
    parser.add_argument(
        "--src",
        type=argparse.FileType("r"),
        help="Source ACVP internalProjection JSON file.",
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
        choices=["keygen", "siggen", "sigver"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = json.load(args.src)

    if args.test_type == "keygen":
        test_vectors = parse_keygen(raw_data)
    elif args.test_type == "siggen":
        test_vectors = parse_siggen(raw_data)
    elif args.test_type == "sigver":
        test_vectors = parse_sigver(raw_data)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    json.dump(test_vectors, args.dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
