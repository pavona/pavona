#!/usr/bin/env python3
# Copyright zeroRISC Inc.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Parser for converting ACVP ML-DSA prompts to JSON.

Reads a `prompt.json` vector set: the inputs an ACVP session hands the
implementation under test. The harness assembles the response.
Supports:
  - ML-DSA-keyGen-FIPS204 (keygen)
  - ML-DSA-sigGen-FIPS204 (siggen)
  - ML-DSA-sigVer-FIPS204 (sigver)

Each test carries the `tg_id` and `vs_id` it came from, so the harness can
rebuild the test group structure the response requires.

Within the external interface, pure ML-DSA and HashML-DSA are supported
for the hash functions the cryptolib implements (SHA2-256/384/512,
SHA3-224/256/384/512, SHAKE-128/256); other HashML-DSA groups are
skipped.

The internal signature interface is only supported with externalMu=true
(a precomputed mu); externalMu=false groups are skipped, since this
cryptolib has no path to derive mu from a raw message internally.
"""

import argparse
import json
import sys

import jsonschema

from acvp_util import (acvp_common, apply_expected, load_vector_set,
                       report_skipped)

PARAMETER_SETS = {
    "ML-DSA-44": 44,
    "ML-DSA-65": 65,
    "ML-DSA-87": 87,
}

# Maps ACVP's `hashAlg` test field to our `sign_mode` test-vector field.
# SHA2-224, SHA2-512/224, and SHA2-512/256 are intentionally omitted: the
# cryptolib doesn't implement those hash functions.
HASH_ALGS = {
    "SHA2-256": "hash_mldsa_sha2_256",
    "SHA2-384": "hash_mldsa_sha2_384",
    "SHA2-512": "hash_mldsa_sha2_512",
    "SHA3-224": "hash_mldsa_sha3_224",
    "SHA3-256": "hash_mldsa_sha3_256",
    "SHA3-384": "hash_mldsa_sha3_384",
    "SHA3-512": "hash_mldsa_sha3_512",
    "SHAKE-128": "hash_mldsa_shake128",
    "SHAKE-256": "hash_mldsa_shake256",
}


def sign_mode_for_test(group, test):
    """Returns the `sign_mode` value for a test, or None if unsupported."""
    if group["preHash"] == "pure":
        return "pure"
    return HASH_ALGS.get(test["hashAlg"])


def message_and_sign_mode(group, test):
    """Returns the `(message, sign_mode, context)` to send for a test, or
    `(None, None, None)` if unsupported.

    Only the externalMu=true flavor of the internal signature interface is
    supported (the caller filters out externalMu=false groups before
    reaching here); `message` is then the mu supplied directly by the test
    vector, matching the cryptolib's external-mu mode exactly."""
    if group.get("signatureInterface") == "internal":
        return bytes.fromhex(test["mu"]), "external_mu", b""
    sign_mode = sign_mode_for_test(group, test)
    if sign_mode is None:
        return None, None, None
    message = bytes.fromhex(test["message"])
    context = bytes.fromhex(test.get("context", ""))
    return message, sign_mode, context


def parse_keygen(data):
    """Parse an ML-DSA-keyGen prompt. Response: pk and sk."""
    test_vectors = []
    for group in data["testGroups"]:
        param_set = PARAMETER_SETS[group["parameterSet"]]
        for test in group["tests"]:
            seed = bytes.fromhex(test["seed"])
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "keygen",
                "parameter_set": param_set,
                "seed": list(seed),
                "result": True,
            })
    return test_vectors


def parse_siggen(data, skip_unsupported):
    """Parse an ML-DSA-sigGen prompt. Response: the signature."""
    test_vectors = []
    skipped_hash_alg = 0
    skipped_interface = 0
    for group in data["testGroups"]:
        interface = group.get("signatureInterface")
        if interface not in ("external", "internal"):
            continue
        if interface == "external" and group.get("externalMu", False):
            continue
        if interface == "internal" and not group.get("externalMu", False):
            skipped_interface += len(group["tests"])
            continue

        deterministic = group.get("deterministic", False)
        param_set = PARAMETER_SETS[group["parameterSet"]]
        for test in group["tests"]:
            message, sign_mode, context = message_and_sign_mode(group, test)
            if sign_mode is None:
                skipped_hash_alg += 1
                continue

            sk = bytes.fromhex(test["sk"])
            rnd = bytes(32) if deterministic else bytes.fromhex(test["rnd"])
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "siggen",
                "parameter_set": param_set,
                "sign_mode": sign_mode,
                "sk": list(sk),
                "message": list(message),
                "context": list(context),
                "rnd": list(rnd),
                "result": True,
            })
    report_skipped("parse_siggen", {
        "the hash algorithm is not implemented": skipped_hash_alg,
        "the internal signature interface needs a precomputed mu":
            skipped_interface,
    }, skip_unsupported)
    return test_vectors


def parse_sigver(data, skip_unsupported):
    """Parse an ML-DSA-sigVer prompt. Response: testPassed."""
    test_vectors = []
    skipped_hash_alg = 0
    skipped_interface = 0
    for group in data["testGroups"]:
        interface = group.get("signatureInterface")
        if interface not in ("external", "internal"):
            continue
        if interface == "external" and group.get("externalMu", False):
            continue
        if interface == "internal" and not group.get("externalMu", False):
            skipped_interface += len(group["tests"])
            continue

        param_set = PARAMETER_SETS[group["parameterSet"]]
        for test in group["tests"]:
            message, sign_mode, context = message_and_sign_mode(group, test)
            if sign_mode is None:
                skipped_hash_alg += 1
                continue

            pk = bytes.fromhex(test["pk"])
            sig = bytes.fromhex(test["signature"])
            test_vectors.append({
                **acvp_common(data, group),
                "test_case_id": test["tcId"],
                "operation": "sigver",
                "parameter_set": param_set,
                "sign_mode": sign_mode,
                "pk": list(pk),
                "message": list(message),
                "context": list(context),
                "signature": list(sig),
            })
    report_skipped("parse_sigver", {
        "the hash algorithm is not implemented": skipped_hash_alg,
        "the internal signature interface needs a precomputed mu":
            skipped_interface,
    }, skip_unsupported)
    return test_vectors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Parsing utility for ACVP ML-DSA prompts.")
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

    if args.test_type == "keygen":
        test_vectors = parse_keygen(raw_data)
    elif args.test_type == "siggen":
        test_vectors = parse_siggen(raw_data, args.skip_unsupported)
    elif args.test_type == "sigver":
        test_vectors = parse_sigver(raw_data, args.skip_unsupported)

    apply_expected(test_vectors, args.expected)

    with open(args.schema) as schema_file:
        schema = json.load(schema_file)
    jsonschema.validate(test_vectors, schema)

    with open(args.dst, "w") as dst:
        json.dump(test_vectors, dst, indent=4)

    return 0


if __name__ == "__main__":
    sys.exit(main())
