#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP ML-KEM testvectors to JSON.

Uses the internalProjection files from the NIST ACVP-Server repo.
Supports:
  - ML-KEM-keyGen-FIPS203 (keygen)
  - ML-KEM-encapDecap-FIPS203 (encaps, decaps)

Instead of including the full expected outputs (ek, dk, ct, k) in the
parsed JSON, this parser pre-computes a SHA3-256 hash of the expected
outputs. The firmware computes the same hash and returns only the
32-byte digest, avoiding expensive transfer of large outputs.

ACVP encapsulationKeyCheck and decapsulationKeyCheck tests verify that
the implementation rejects invalid keys. The cryptolib does not expose
dedicated key validation functions as of now, but encapsulate_derand
and decapsulate perform internal checks (FIPS 203 modulus check,
hash consistency) that reject invalid keys. We map these tests to
regular encaps/decaps operations with dummy randomness/ciphertext:
valid keys succeed, invalid keys cause the operation to fail.
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


def parse_keygen(data):
    """Parse ML-KEM-keyGen internalProjection.
    Output hash: SHA3-256(ek || dk)."""
    test_vectors = []
    for group in data["testGroups"]:
        param_set = PARAMETER_SETS[group["parameterSet"]]
        for test in group["tests"]:
            seed = bytes.fromhex(test["d"]) + bytes.fromhex(test["z"])
            ek = bytes.fromhex(test["ek"])
            dk = bytes.fromhex(test["dk"])
            test_vectors.append({
                "vendor": "acvp",
                "test_case_id": test["tcId"],
                "operation": "keygen",
                "parameter_set": param_set,
                "seed": list(seed),
                "expected_hash": compute_hash(ek + dk),
                "result": True,
            })
    return test_vectors


def parse_encap_decap(data):
    """Parse ML-KEM-encapDecap internalProjection."""
    test_vectors = []
    for group in data["testGroups"]:
        param_set = PARAMETER_SETS[group["parameterSet"]]
        function = group["function"]

        if function == "encapsulation":
            # Output hash: SHA3-256(ct || K).
            for test in group["tests"]:
                c = bytes.fromhex(test["c"])
                k = bytes.fromhex(test["k"])
                test_vectors.append({
                    "vendor": "acvp",
                    "test_case_id": test["tcId"],
                    "operation": "encaps",
                    "parameter_set": param_set,
                    "seed": list(bytes.fromhex(test["m"])),
                    "ek": list(bytes.fromhex(test["ek"])),
                    "expected_hash": compute_hash(c + k),
                    "result": True,
                })
        elif function == "decapsulation":
            # Output hash: SHA3-256(K).
            for test in group["tests"]:
                k = bytes.fromhex(test["k"])
                test_vectors.append({
                    "vendor": "acvp",
                    "test_case_id": test["tcId"],
                    "operation": "decaps",
                    "parameter_set": param_set,
                    "dk": list(bytes.fromhex(test["dk"])),
                    "c": list(bytes.fromhex(test["c"])),
                    "expected_hash": compute_hash(k),
                    "result": True,
                })
        elif function == "encapsulationKeyCheck":
            # No expected output — only success is checked.
            for test in group["tests"]:
                dummy_m = [0] * 32
                test_vectors.append({
                    "vendor": "acvp",
                    "test_case_id": test["tcId"],
                    "operation": "encaps",
                    "parameter_set": param_set,
                    "seed": dummy_m,
                    "ek": list(bytes.fromhex(test["ek"])),
                    "result": test["testPassed"],
                })
        elif function == "decapsulationKeyCheck":
            # No expected output — only success is checked.
            ct_sizes = {512: 768, 768: 1088, 1024: 1568}
            dummy_ct = [0] * ct_sizes[param_set]
            for test in group["tests"]:
                test_vectors.append({
                    "vendor": "acvp",
                    "test_case_id": test["tcId"],
                    "operation": "decaps",
                    "parameter_set": param_set,
                    "dk": list(bytes.fromhex(test["dk"])),
                    "c": dummy_ct,
                    "result": test["testPassed"],
                })
        else:
            raise ValueError(f"Unknown function: {function}")

    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP ML-KEM testvectors.")
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
        choices=["keygen", "encap_decap"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    raw_data = json.load(args.src)

    if args.test_type == "keygen":
        test_vectors = parse_keygen(raw_data)
    elif args.test_type == "encap_decap":
        test_vectors = parse_encap_decap(raw_data)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    json.dump(test_vectors, args.dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
