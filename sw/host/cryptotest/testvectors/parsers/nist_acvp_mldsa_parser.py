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

Within the external interface, pure ML-DSA and HashML-DSA are supported
for the hash functions the cryptolib implements (SHA2-256/384/512,
SHA3-224/256/384/512, SHAKE-128/256); other HashML-DSA groups are
skipped.

The internal signature interface is only supported with externalMu=true
(a precomputed mu); externalMu=false groups are skipped, since this
cryptolib has no path to derive mu from a raw message internally.
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


def compute_hash(data):
    """Compute SHA3-256 hash."""
    return list(hashlib.sha3_256(data).digest())


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
    Deterministic and randomized; pure ML-DSA, HashML-DSA, and the internal
    signature interface with externalMu=true. Output hash:
    SHA3-256(signature)."""
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
            sig = bytes.fromhex(test["signature"])
            rnd = bytes(32) if deterministic else bytes.fromhex(test["rnd"])
            test_vectors.append({
                "vendor": "acvp",
                "test_case_id": test["tcId"],
                "operation": "siggen",
                "parameter_set": param_set,
                "sign_mode": sign_mode,
                "sk": list(sk),
                "message": list(message),
                "context": list(context),
                "rnd": list(rnd),
                "expected_hash": compute_hash(sig),
                "result": True,
            })
    if skipped_hash_alg:
        print(f"parse_siggen: skipped {skipped_hash_alg} test(s) with an "
              "unsupported hash algorithm", file=sys.stderr)
    if skipped_interface:
        print(f"parse_siggen: skipped {skipped_interface} test(s) using the "
              "internal signature interface without a precomputed mu "
              "(this cryptolib has no on-device path to compute mu from a "
              "raw message)", file=sys.stderr)
    return test_vectors


def parse_sigver(data):
    """Parse ML-DSA-sigVer internalProjection.
    Pure ML-DSA, HashML-DSA, and the internal signature interface with
    externalMu=true."""
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
                "vendor": "acvp",
                "test_case_id": test["tcId"],
                "operation": "sigver",
                "parameter_set": param_set,
                "sign_mode": sign_mode,
                "pk": list(pk),
                "message": list(message),
                "context": list(context),
                "signature": list(sig),
                "result": test["testPassed"],
            })
    if skipped_hash_alg:
        print(f"parse_sigver: skipped {skipped_hash_alg} test(s) with an "
              "unsupported hash algorithm", file=sys.stderr)
    if skipped_interface:
        print(f"parse_sigver: skipped {skipped_interface} test(s) using the "
              "internal signature interface without a precomputed mu "
              "(this cryptolib has no on-device path to compute mu from a "
              "raw message)", file=sys.stderr)
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
