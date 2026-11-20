#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP RSA prompts to JSON."""

import argparse
import json
import sys

import jsonschema

from acvp_util import acvp_common, apply_expected, load_vector_set

HASH_ALGS = {
    "SHA2-256": "sha-256",
    "SHA2-384": "sha-384",
    "SHA2-512": "sha-512",
    "SHA3-224": "sha3-224",
    "SHA3-256": "sha3-256",
    "SHA3-384": "sha3-384",
    "SHA3-512": "sha3-512",
}

DIGEST_BYTES = {
    "SHA2-256": 32,
    "SHA2-384": 48,
    "SHA2-512": 64,
    "SHA3-224": 28,
    "SHA3-256": 32,
    "SHA3-384": 48,
    "SHA3-512": 64,
}

PADDINGS = {
    "pkcs1v1.5": "pkcs1_1.5",
    "pss": "pss",
}


def parse_sigver(data):
    """Parse an RSA sigVer prompt. Response: testPassed."""
    if data["revision"] != "FIPS186-5":
        raise SystemExit("parse_sigver: only revision FIPS186-5 is implemented")
    test_vectors = []
    for group in data["testGroups"]:
        hash_alg = group["hashAlg"]
        if hash_alg not in HASH_ALGS:
            raise SystemExit(f"parse_sigver: {hash_alg} is not implemented")
        sig_type = group["sigType"]
        if sig_type not in PADDINGS:
            raise SystemExit(f"parse_sigver: {sig_type} is not implemented")
        if sig_type == "pss":
            if group["maskFunction"] != "mgf1":
                raise SystemExit("parse_sigver: mask functions other than MGF1 are not "
                                 "implemented")
            if group["saltLen"] != DIGEST_BYTES[hash_alg]:
                raise SystemExit("parse_sigver: salts other than the digest length are not "
                                 "implemented")
        n = bytes.fromhex(group["n"])
        e = int(group["e"], 16)
        for test in group["tests"]:
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "verify",
                "padding": PADDINGS[sig_type],
                "security_level": group["modulo"],
                "hash_alg": HASH_ALGS[hash_alg],
                "message": list(bytes.fromhex(test["message"])),
                "n": list(n),
                "e": e,
                "signature": list(bytes.fromhex(test["signature"])),
            })
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP RSA prompts.")
    parser.add_argument(
        "--src",
        type=str,
        help="Source ACVP prompt file.",
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
        choices=["sigver"],
        required=True,
        help="Type of test vectors to parse.",
    )
    args = parser.parse_args()

    test_vectors = parse_sigver(load_vector_set(args.src))
    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
